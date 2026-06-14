# tavern_ohos API 文档

本文按 Runtime、类型和事件名说明 `tavern_ohos` 的公开 API。示例用法见 [使用指南](usage-guide.md)。

## 一、基础约定

### 导入入口

所有公开 Runtime 和类型从模块入口导入：

```ts
import {
  EventBus,
  CharacterRuntime,
  ChatRuntime,
  MessageRuntime,
  WorldInfoRuntime,
  PromptRuntime,
  OpenAIOhosProviderStreamSource,
  ProviderRuntime,
  type RuntimeEvent,
} from 'tavern_ohos';
```

### Runtime 分类

| 分类 | Runtime |
|---|---|
| 基础 | `EventBus`、`TaskRuntime`、`LockManager` |
| 存储 | `TavernFileStore`、`SandboxTavernFileStore`、`InMemoryFileStore`、`JsonStore`、`JsonlStore` |
| 角色与聊天 | `CharacterRuntime`、`CharacterCodecRuntime`、`AvatarRuntime`、`ChatRuntime`、`MessageRuntime`、`SwipeRuntime`、`BookmarkRuntime`、`BranchRuntime` |
| Prompt | `PromptRuntime`、`WorldInfoRuntime`、`AuthorNoteRuntime`、`PromptTemplateRuntime`、`InstructRuntime`、`RegexRuntime`、`TokenizerRuntime`、`PromptCompressionRuntime` |
| 生成和 Provider | `ProviderRuntime`、`OpenAIOhosProviderStreamSource`、`StreamingRuntime`、`ReasoningRuntime`、`ConnectionProfileRuntime`、`SecretRuntime`、`NetworkService`、`NetworkPolicyRuntime` |
| 知识和检索 | `DataBankRuntime`、`EmbeddingRuntime`、`VectorRuntime`、`RagRuntime`、`SearchRuntime`、`MemoryRuntime` |
| 媒体 | `ImageGenerationRuntime`、`ImageRuntime`、`ImageMetadataRuntime`、`ImageCaptionRuntime`、`ASRRuntime`、`TTSRuntime`、`GalleryRuntime`、`ThumbnailRuntime`、`BackgroundRuntime` |
| 扩展和 UI | `PluginRuntime`、`CommandRuntime`、`QuickReplyRuntime`、`ToolCallingRuntime`、`UIBridgeRuntime`、`MacroRuntime` |
| 用户和配置 | `UserRuntime`、`PersonaRuntime`、`PresetRuntime`、`SettingsRuntime`、`SystemPromptRuntime`、`ThemeRuntime`、`TagRuntime` |
| 运维 | `BackupRuntime`、`MigrationRuntime`、`RecoveryRuntime`、`DiagnosticsRuntime`、`SecurityRuntime`、`PermissionRuntime`、`DataCleanupRuntime` |

## 二、EventBus

### RuntimeEvent

```ts
interface RuntimeEvent<T extends Object> {
  name: string;
  payload: T;
  sequence: number;
  timestamp: number;
}
```

字段说明：

- `name`：事件名。
- `payload`：事件载荷。
- `sequence`：当前 `EventBus` 内递增序号。
- `timestamp`：发布时间戳。

### EventBus.subscribe()

```ts
subscribe<T extends Object>(eventName: string, handler: RuntimeEventHandler<T>): EventSubscription
```

订阅指定事件。返回的 `EventSubscription` 必须在页面销毁或功能停用时调用 `unsubscribe()`。

### EventBus.publish()

```ts
publish<T extends Object>(eventName: string, payload: T): RuntimeEvent<T>
```

发布事件。SDK 内部 Runtime 会调用该方法；宿主也可以用于自定义运行时事件。

注意：`EventBus` 会用 JSON 序列化方式克隆 payload，因此 payload 应是可 JSON 序列化对象。

## 三、存储 API

### TavernFileStore

`TavernFileStore` 是所有文件型 Runtime 的最小存储抽象。正式应用通常不需要自己实现它，直接使用 `SandboxTavernFileStore`。

```ts
interface TavernFileStore {
  ensureDirectory(path: string): Promise<void>;
  exists(path: string): Promise<boolean>;
  readText(path: string): Promise<string>;
  writeText(path: string, content: string, createBackup: boolean): Promise<void>;
  appendText(path: string, content: string): Promise<void>;
  delete(path: string): Promise<void>;
  list(path: string): Promise<Array<string>>;
}
```

### SandboxTavernFileStore

HarmonyOS / OpenHarmony 应用沙箱默认实现：

```ts
new SandboxTavernFileStore(baseDirectory: string)
```

使用方式：

```ts
const files = new SandboxTavernFileStore(appFilesDir);
```

行为说明：

- 所有传入路径都会解析到 `baseDirectory` 下。
- `writeText()` 和 `appendText()` 会按需创建父目录。
- SDK 不再要求初始化时创建全套 Tavern 目录。
- `..` 路径会被拒绝。
- `createBackup` 为 `true` 时，覆盖前会生成同路径 `.bak`。

自定义实现要求：

- 路径建议统一用 `/`。
- 必须阻止 `..` 和绝对路径逃逸。
- `writeText()` 和 `appendText()` 应按需创建父目录。
- `list()` 返回直接子节点名称，不返回完整路径。

### InMemoryFileStore

内存实现，适合测试和示例。应用退出后数据丢失。

## 四、角色卡 API

### CharacterRuntime

构造：

```ts
new CharacterRuntime(files: TavernFileStore, events: EventBus, rootPath: string, userId: string)
```

方法：

| 方法 | 说明 | 主要事件 |
|---|---|---|
| `createCharacter(params)` | 创建本地角色，生成 `char-<nextId>` | `character.created` |
| `importCharacterJson(cardJson)` | 导入 SillyTavern V2 JSON 角色卡 | `character.imported` |
| `exportCharacterJson(characterId)` | 导出 V2 JSON；未修改导入角色时返回原始 `sourceJson` | 无 |
| `getCharacter(characterId)` | 读取完整角色记录 | 无 |
| `listCharacters()` | 读取角色索引列表 | 无 |
| `updateCharacter(characterId, params)` | 更新基础字段并清空 `sourceJson` | `character.updated` |
| `duplicateCharacter(characterId, newName)` | 复制角色 | `character.created` |
| `deleteCharacter(characterId)` | 删除角色目录并移除索引 | `character.deleted`、`character.deleted.id` |

关键类型：

- `CharacterCreateParams`：创建本地角色所需字段。
- `CharacterUpdateParams`：更新本地角色所需字段。
- `CharacterRecord`：完整角色记录。
- `CharacterIndexEntry`：列表索引记录。
- `CharacterCardV2`：SillyTavern V2 JSON 结构。

### CharacterCodecRuntime

用于格式转换，不负责保存：

| 方法 | 说明 |
|---|---|
| `parseCharacterJson(json)` | 解析 V1、V2、charx JSON |
| `parsePngCharacterCard(data)` | 从 PNG metadata 中解析角色卡 |
| `parseWebpCharacterCard(data)` | 从 WebP metadata 中解析角色卡 |
| `exportToV2(result)` | 把解析结果导出为 V2 JSON |
| `exportToPng(result, sourcePng)` | 把 V2 JSON 写入 PNG metadata |
| `exportToWebp(result, sourceWebp)` | 把 V2 JSON 写入 WebP metadata |
| `detectFormat(data)` | 判断 JSON 格式 |
| `detectBinaryFormat(data)` | 判断二进制角色卡格式 |
| `parseCharacterBook(json)` | 解析 CharacterBook |
| `exportCharacterBook(book)` | 导出 CharacterBook |

### AvatarRuntime

构造：

```ts
new AvatarRuntime(files: TavernFileStore, events: EventBus)
```

方法：

| 方法 | 说明 | 事件 |
|---|---|---|
| `uploadAvatar(targetType, targetId, fileName, mimeType, content, crop)` | 保存或覆盖头像 | `avatar.uploaded` |
| `getAvatar(targetType, targetId)` | 获取头像记录 | 无 |
| `readAvatarContent(targetType, targetId)` | 读取头像内容 | 无 |
| `listByTargetType(targetType)` | 按目标类型列出头像 | 无 |
| `deleteAvatar(targetType, targetId)` | 删除头像 | `avatar.deleted` |

## 五、聊天和消息 API

### ChatRuntime

构造：

```ts
new ChatRuntime(files: TavernFileStore, events: EventBus, rootPath: string, userId: string)
```

方法：

| 方法 | 说明 | 事件 |
|---|---|---|
| `createChat(params)` | 创建聊天 | `chat.created` |
| `listChats()` | 列出聊天索引，并刷新消息数量和预览 | 无 |
| `searchChats(query)` | 按标题和预览搜索 | 无 |
| `importChatJsonl(jsonl, title, characterId, personaId)` | 导入聊天 JSONL | `chat.imported` |
| `getChat(chatId)` | 读取聊天元数据 | 无 |
| `renameChat(chatId, title)` | 重命名 | `chat.updated` |
| `archiveChat(chatId, archived)` | 设置归档状态 | `chat.updated` |
| `duplicateChat(chatId, title)` | 复制聊天和消息 | `chat.created`、`chat.duplicated` |
| `deleteChat(chatId)` | 删除聊天目录和索引 | `chat.deleted` |
| `exportChatJsonl(chatId)` | 导出 SillyTavern JSONL | 无 |
| `messages(chatId)` | 创建该聊天的 `MessageRuntime` | 无 |

### MessageRuntime

构造：

```ts
new MessageRuntime(files: TavernFileStore, events: EventBus, rootPath: string, userId: string, chatId: string)
```

方法：

| 方法 | 说明 | 事件 |
|---|---|---|
| `addMessage(params)` | 添加消息 | `message.added` |
| `listMessages()` | 读取全部消息 | 无 |
| `getMessage(messageId)` | 读取单条消息 | 无 |
| `listMessagesPage(startIndex, limit)` | 分页读取消息 | 无 |
| `updateMessage(messageId, params)` | 更新正文和系统标记 | `message.updated` |
| `deleteMessage(messageId)` | 删除单条消息 | `message.deleted` |
| `deleteMessages(messageIds)` | 批量删除消息 | `message.deleted` |
| `moveMessage(messageId, targetIndex)` | 移动消息顺序 | `message.updated` |
| `hideMessage(messageId, hidden)` | 修改 `isSystem`，用于隐藏或系统化消息 | 无 |
| `setMessageRating(messageId, rating)` | 设置评分，写入 `extraJson` | 无 |
| `setMessageBookmark(messageId, bookmarked)` | 设置书签，写入 `extraJson` | 无 |

消息字段：

- `role`：`user`、`assistant`、`system` 等。
- `text`：正文。
- `isUser`：是否用户消息。
- `isSystem`：是否系统消息；当前 `PromptRuntime` 会跳过系统消息历史。
- `swipes`：备选回复。
- `extraJson`：评分、书签、分支等扩展数据。

## 六、世界书 API

### WorldInfoRuntime

构造：

```ts
new WorldInfoRuntime(files: TavernFileStore, events: EventBus, rootPath: string, userId: string)
```

方法：

| 方法 | 说明 | 事件 |
|---|---|---|
| `createWorldBook(name)` | 创建世界书 | `worldinfo.created` |
| `listWorldBooks()` | 列出世界书索引 | 无 |
| `getWorldBook(worldBookId)` | 读取完整世界书 | 无 |
| `deleteWorldBook(worldBookId)` | 删除世界书 | `worldinfo.deleted` |
| `createEntry(worldBookId, params)` | 新增条目 | `worldinfo.updated` |
| `updateEntry(worldBookId, entryId, params)` | 更新条目 | `worldinfo.updated` |
| `deleteEntry(worldBookId, entryId)` | 删除条目 | `worldinfo.updated` |
| `exportWorldBookJson(worldBookId)` | 导出世界书 JSON | 无 |
| `importWorldBookJson(json, name)` | 导入世界书，生成新 ID | `worldinfo.imported` |
| `activateEntries(worldBookIds, messages)` | 根据消息激活条目 | `worldinfo.activated` |
| `activateEntriesRecursive(worldBookIds, messages, maxDepth, maxTokens)` | 递归激活条目 | `worldinfo.activated` |

条目字段：

- `keys`：主关键词。
- `secondaryKeys`：二级关键词。
- `constant`：恒定启用。
- `selective`：要求主关键词和二级关键词同时命中。
- `enabled`：是否参与激活。
- `insertionOrder`：排序。
- `position`：位置标记。
- `caseSensitive`：是否区分大小写。

## 七、Prompt API

### PromptRuntime

构造：

```ts
new PromptRuntime(events: EventBus)
```

方法：

| 方法 | 说明 | 事件 |
|---|---|---|
| `buildPrompt(input)` | 组装系统段、角色段、persona、世界书、作者注释和聊天历史 | `prompt.built` |

输入 `PromptBuildInput`：

- `id`：Prompt ID。
- `systemPrompt`：系统提示。
- `personaName`、`personaDescription`：用户人格信息。
- `authorNote`：作者注释。
- `character`：完整 `CharacterRecord`。
- `messages`：`ChatMessage[]`。
- `worldInfo`：`WorldInfoActivation`。
- `maxEstimatedTokens`：粗略 token 预算。

输出 `PromptBuildResult`：

- `sections`：分段结果。
- `finalText`：最终文本。
- `debug`：调试信息。

## 八、Provider 和流式 API

### StreamingRuntime

| 方法 | 说明 | 事件 |
|---|---|---|
| `attachMessageRuntime(messageRuntime)` | 挂接消息 Runtime，普通文本 delta 自动写回消息 | 无 |
| `startStream(params)` | 创建流会话 | `stream.started` |
| `applyDelta(sessionId, delta, reasoning)` | 应用增量 | `stream.delta` |
| `completeStream(sessionId)` | 完成流 | `stream.completed` |
| `abortStream(sessionId, reason)` | 中止流 | `stream.aborted` |
| `getSession(sessionId)` | 读取流会话 | 无 |

### ProviderRuntime

| 方法 | 说明 | 事件 |
|---|---|---|
| `startOpenAICompatibleStream(params)` | 启动 OpenAI-compatible 流式任务 | `generation.started` |
| `abortProviderStream(taskId, reason)` | 中止 provider 任务 | `generation.failed` |
| `getTask(taskId)` | 读取任务 | 无 |
| `openAICompatibleCapability(model, maxContext, supportsReasoning)` | 构造能力描述 | 无 |
| `buildTextCompletionRequest(params)` | 构造文本补全请求体 | 无 |
| `acceptOpenAICompatibleChunk(taskId, parser, chunk)` | 手动喂入 SSE chunk | 可能触发 `stream.delta` |
| `finishOpenAICompatibleStream(taskId, parser)` | 手动结束流 | `generation.completed` |
| `failStream(taskId, message)` | 标记流失败 | `generation.failed` |

### ProviderStreamSource

`ProviderRuntime.startOpenAICompatibleStream()` 通过该接口取得流式内容。SDK 内置 `OpenAIOhosProviderStreamSource`；宿主也可以自定义实现。

```ts
interface ProviderStreamSource {
  start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle>;
}
```

`ProviderStreamSink`：

- `onChunk(chunk)`：传入 SSE 原文。
- `onError(message)`：报告错误。
- `onDone()`：报告完成。

### OpenAIOhosProviderStreamSource

构造：

```ts
new OpenAIOhosProviderStreamSource(options: OpenAIOhosProviderStreamSourceOptions)
```

`OpenAIOhosProviderStreamSourceOptions` 继承 `openai_ohos` 的 `OpenAIClientOptions`，常用字段：

| 字段 | 说明 |
|---|---|
| `apiKey` | OpenAI 或兼容服务 API key；会生成 `Authorization: Bearer <apiKey>` |
| `baseURL` | API 根地址；默认由 `openai_ohos` 使用 `https://api.openai.com/v1` |
| `organization` | 可选组织 ID |
| `project` | 可选项目 ID |
| `timeout` / `readTimeout` / `connectTimeout` | 超时设置 |
| `maxRetries` | 非流式请求层的重试次数；streaming 由底层 transport 管理 |
| `defaultHeaders` | 每次请求附加的默认 header |
| `transport` | 自定义 `openai_ohos` transport，常用于测试或替换网络栈 |

行为：

1. `start(request, sink)` 会把 `ProviderStreamRequest` 转成 OpenAI Chat Completions 请求体。
2. 请求路径固定为 `/chat/completions`。
3. `stream` 固定为 `true`，即使调用方传入其它值也按流式处理。
4. `messages`、`temperature`、`maxTokens` 和 `stop` 会复制到请求体，避免外部数组复用导致运行中突变。
5. `openai_ohos` 解析出的 `OpenAISSEEvent` 会重新序列化成 `ProviderStreamSink.onChunk()` 需要的 SSE 文本。
6. `ProviderStreamHandle.close()` 会关闭 `openai_ohos` 返回的底层 stream。

示例：

```ts
const source = new OpenAIOhosProviderStreamSource({
  apiKey: 'sk-...',
  baseURL: 'https://api.openai.com/v1',
});

await provider.startOpenAICompatibleStream({
  taskId: 'generation-1',
  chatId: 'chat-1',
  messageId: 'message-1',
  request: {
    provider: 'openai-compatible',
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: '你好' }],
    temperature: 0.7,
    maxTokens: 512,
    stop: [],
    stream: true,
  },
  source: source,
});
```

## 九、连接、密钥和网络 API

### ConnectionProfileRuntime

| 方法 | 说明 | 事件 |
|---|---|---|
| `loadFromStore()` | 从 `users/<userId>/connection-profiles/index.json` 恢复连接配置和激活绑定 | 无 |
| `saveToStore()` | 把当前连接配置和激活绑定写入文件存储 | 无 |
| `createProfile(params)` | 创建连接配置 | `connectionProfile.created` |
| `updateProfile(profileId, params)` | 更新连接配置 | `connectionProfile.updated` |
| `getProfile(profileId)` | 读取配置 | 无 |
| `listProfiles(apiType)` | 按类型列出配置，空字符串表示全部 | 无 |
| `deleteProfile(profileId)` | 删除配置 | `connectionProfile.deleted` |
| `setActiveProfile(scope, scopeId, profileId)` | 设置作用域激活配置 | `connectionProfile.activeChanged` |
| `resolveActiveProfile(scope, scopeId)` | 解析激活配置 | 无 |
| `toProviderRequest(profileId)` | 转成 provider 请求元数据 | 无 |

### SecretRuntime

| 方法 | 说明 | 事件 |
|---|---|---|
| `loadFromStore()` | 从 `users/<userId>/secrets/index.json` 恢复密钥记录和值 | 无 |
| `saveToStore()` | 把当前密钥记录和值写入文件存储 | 无 |
| `createSecret(params)` | 创建密钥引用和值 | `secret.created` |
| `updateSecret(secretRef, label, active)` | 更新标签和启用状态 | `secret.updated` |
| `deleteSecret(secretRef)` | 删除密钥 | `secret.deleted` |
| `rotateSecret(providerId, scope, scopeId, id, value, label)` | 轮换密钥 | `secret.created`、`secret.rotated` |
| `readSecret(secretRef, options)` | 按权限读取明文 | 无 |
| `readActiveSecret(providerId, scope, scopeId, options)` | 读取激活密钥 | 无 |
| `listSecretStates(providerId)` | 列出脱敏状态 | 无 |
| `exportIndex()` | 导出脱敏索引 | 无 |
| `maskValue(value)` | 脱敏字符串 | 无 |

### NetworkService

| 方法 | 说明 |
|---|---|
| `setOverrideHeaders(rules)` | 设置按 host 覆盖的请求头 |
| `resolveHeadersForProfile(profileId, serverUrl?)` | 解析真实请求头 |
| `previewHeadersForProfile(profileId, serverUrl?)` | 解析脱敏预览请求头 |

## 十、知识库和 RAG API

### DataBankRuntime

| 方法 | 说明 | 事件 |
|---|---|---|
| `createDocument(params)` | 创建文档 | `databank.document.created` |
| `getDocument(documentId)` | 读取文档记录 | 无 |
| `readDocumentContent(documentId)` | 读取文档内容 | 无 |
| `listDocuments(includeDisabled)` | 列出文档 | 无 |
| `listByScope(scope, includeDisabled)` | 按作用域列出 | 无 |
| `listByTag(tag, includeDisabled)` | 按标签列出 | 无 |
| `setDocumentEnabled(documentId, enabled)` | 启用或禁用 | `databank.document.enabled`、`databank.document.disabled` |
| `updateMetadata(documentId, metadataJson, tags)` | 更新元数据 | `databank.document.updated` |
| `deleteDocument(documentId)` | 删除文档 | `databank.document.deleted` |
| `exportData(includeDisabled)` | 导出文档记录 | 无 |
| `importData(data, replace)` | 导入文档记录 | 无 |

### EmbeddingRuntime

| 方法 | 说明 |
|---|---|
| `registerModel(provider, modelName, dimensions, description)` | 注册模型 |
| `getModel(modelId)` | 读取模型 |
| `listModels(provider?)` | 列出模型 |
| `removeModel(modelId)` | 移除模型 |
| `checkDimension(modelId, actualDimensions)` | 检查向量维度 |
| `buildOpenAIRequest(model, input)` | 构造 OpenAI embedding 请求 |
| `buildOllamaRequest(model, prompt)` | 构造 Ollama embedding 请求 |
| `buildCohereRequest(model, texts)` | 构造 Cohere 请求 |
| `buildGoogleRequest(model, text)` | 构造 Google 请求 |
| `saveResult(result)` | 保存 embedding 结果事件 |
| `exportData()` / `importData(data)` | 导入导出模型配置 |

### VectorRuntime

| 方法 | 说明 | 事件 |
|---|---|---|
| `createCollection(params)` | 创建集合 | 无 |
| `upsertVector(collectionId, input)` | 写入或覆盖向量 | `vector.upserted` |
| `listVectors(collectionId)` | 列出向量 | 无 |
| `query(params)` | 余弦相似度查询 | 无 |
| `deleteByDocument(collectionId, documentId)` | 按文档删除 | `vector.deleted` |
| `deleteByScope(collectionId, scope)` | 按作用域删除 | `vector.deleted` |

### RagRuntime

| 方法 | 说明 | 事件 |
|---|---|---|
| `retrieve(input)` | 检索并套用 promptTemplate | `rag.retrieved` |
| `buildQueryFromLastUserMessage(messages)` | 从最后一条用户消息构造查询 | 无 |
| `buildQueryFromRecentChatWindow(messages, windowSize)` | 从近期窗口构造查询 | 无 |

## 十一、媒体 API

### ImageGenerationRuntime

管理图片生成任务和请求体构造：

- `generateImage(params)`
- `updateProgress(taskId, progress)`
- `completeGeneration(taskId, attachmentIds, metadata)`
- `failGeneration(taskId, error)`
- `cancelGeneration(taskId)`
- `getTask(taskId)`
- `listTasks(status?)`
- `cleanupTask(taskId)`
- `savePreset(name, params)`
- `loadPreset(presetId)`
- `listPresets()`
- `deletePreset(presetId)`
- `buildSdWebUIRequest(params)`
- `buildComfyUIRequest(workflow, clientId)`
- `buildOpenAIImageRequest(prompt, model, n, size)`
- `buildWorkersAIRequest(params)`
- `exportData()` / `importData(data)`

主要事件：

- `image.generation.started`
- `image.generation.progress`
- `image.generation.completed`
- `image.generation.failed`
- `image.generation.cancelled`
- `image.generation.preset.saved`

### ASRRuntime

- `startTranscription(params)`
- `updateProgress(taskId, progress)`
- `completeTranscription(taskId, result)`
- `failTranscription(taskId, error)`
- `cancelTranscription(taskId)`
- `getTask(taskId)`
- `listTasks(status?)`
- `buildWhisperRequest(file, model, language, prompt)`
- `exportData()` / `importData(data)`

主要事件：

- `asr.transcription.started`
- `asr.transcription.progress`
- `asr.transcription.completed`
- `asr.transcription.failed`
- `asr.transcription.cancelled`

### TTSRuntime

- `synthesize(params)`
- `updateProgress(taskId, progress)`
- `completeSynthesis(taskId, result)`
- `failSynthesis(taskId, error)`
- `cancelSynthesis(taskId)`
- `getTask(taskId)`
- `listTasks(status?)`
- `saveVoiceProfile(...)`
- `getVoiceProfile(profileId)`
- `listVoiceProfiles(provider?)`
- `deleteVoiceProfile(profileId)`
- `buildOpenAITTSRequest(text, voice, model, speed, format)`
- `buildEdgeTTSRequest(text, voice, rate, pitch)`
- `exportData()` / `importData(data)`

主要事件：

- `tts.synthesis.started`
- `tts.synthesis.progress`
- `tts.synthesis.completed`
- `tts.synthesis.failed`
- `tts.synthesis.cancelled`
- `tts.voice.profile.saved`

## 十二、Persona、Preset、Quick Reply

### PersonaRuntime

| 方法 | 说明 |
|---|---|
| `loadFromStore()` | 从 `users/<userId>/personas/index.json` 恢复用户人格、选中人格和作用域绑定 |
| `saveToStore()` | 把当前用户人格、选中人格和作用域绑定写入文件存储 |
| `createPersona(params)` | 创建用户人格 |
| `updatePersona(personaId, params)` | 更新 |
| `getPersona(personaId)` | 读取 |
| `listPersonas()` | 列表 |
| `deletePersona(personaId)` | 删除 |
| `selectPersona(personaId)` | 设置当前人格 |
| `getSelectedPersona()` | 读取当前人格 |
| `bindPersona(scope, scopeId, personaId)` | 绑定作用域 |
| `getBoundPersona(scope, scopeId)` | 读取绑定人格 |
| `buildPromptData(personaId)` | 生成 Prompt 数据 |
| `buildPromptDataForScope(scope, scopeId)` | 按作用域生成 Prompt 数据 |
| `exportPersona(personaId)` / `importPersona(data, newId)` | 单项导入导出 |

事件：

- `persona.created`
- `persona.updated`
- `persona.deleted`
- `persona.changed`
- `persona.imported`

### PresetRuntime

| 方法 | 说明 |
|---|---|
| `loadFromStore()` | 从 `users/<userId>/presets/index.json` 恢复预设和绑定关系 |
| `saveToStore()` | 把当前预设和绑定关系写入文件存储 |
| `createPreset(params)` | 创建预设 |
| `updatePreset(presetId, params)` | 更新 |
| `getPreset(presetId)` | 读取 |
| `listPresets(kind)` | 列表 |
| `deletePreset(presetId)` | 删除 |
| `bindPreset(ownerType, ownerId, presetKind, presetId)` | 绑定 |
| `getBinding(ownerType, ownerId, presetKind)` | 读取绑定 |
| `listBindings(ownerType, ownerId)` | 列出绑定 |
| `exportPreset(presetId)` / `importPreset(data, newId)` | 单项导入导出 |
| `migratePreset(presetId, targetVersion, fields)` | 迁移 |

事件：

- `preset.created`
- `preset.updated`
- `preset.deleted`
- `preset.bound`
- `preset.imported`
- `preset.migrated`

### QuickReplyRuntime

| 方法 | 说明 |
|---|---|
| `loadFromStore()` | 从 `users/<userId>/quick-replies/sets/index.json` 恢复快捷回复集合 |
| `saveToStore()` | 把当前快捷回复集合写入文件存储 |
| `createSet(params)` | 创建快捷回复集合 |
| `getSet(setId)` | 读取集合 |
| `listSets()` | 列出集合 |
| `deleteSet(setId)` | 删除集合 |
| `addItem(setId, params)` | 添加或覆盖按钮 |
| `setItemVisible(setId, itemId, visible)` | 设置按钮可见性 |
| `removeItem(setId, itemId)` | 删除按钮 |
| `listButtons(scope, scopeId)` | 列出当前作用域可运行按钮 |
| `executeItem(setId, itemId, options)` | 执行按钮命令 |
| `executeAutoTrigger(trigger, scope, scopeId, options)` | 执行自动触发按钮 |
| `exportSet(setId)` / `importSet(data, newId)` | 单项导入导出 |

事件：

- `quickReply.setUpdated`
- `quickReply.executed`

## 十三、UIBridgeRuntime

| 方法 | 说明 |
|---|---|
| `requestPopup(title, message)` | 请求弹窗 |
| `requestInput(title, message, defaultValue)` | 请求输入 |
| `requestConfirm(title, message)` | 请求确认 |
| `requestSelect(title, options, multiple)` | 请求选择 |
| `requestFilePicker(title, extensions, multiple)` | 请求文件选择 |
| `requestToast(message, severity)` | 请求 toast |
| `requestLoader(title, visible)` | 请求加载状态 |
| `requestProgress(title, current, total)` | 请求进度 |
| `requestMediaPreview(title, mediaType, mediaUri)` | 请求媒体预览 |
| `requestAudioPlayback(title, mediaUri, autoPlay)` | 请求音频播放 |
| `requestClipboard(title, value)` | 请求剪贴板 |
| `requestNavigation(title, target)` | 请求导航 |
| `requestPermission(title, message)` | 请求权限 |
| `respond(requestId, response)` | 响应 UI 请求 |
| `getRequest(requestId)` | 读取请求 |
| `listRequests()` | 列出全部请求 |
| `getPendingRequests()` | 列出未响应请求 |
| `clearResolved()` | 清理已响应请求 |

事件：

- `ui.requested`
- `ui.resolved`

## 十四、资源、文件、表情图、主题、设置

### AssetRuntime

- `importAsset(params)`
- `readAssetContent(assetId)`
- `listAssets()`
- `listByType(type)`
- `renameAsset(assetId, newFileName)`
- `deleteAsset(assetId)`

事件：

- `asset.imported`
- `asset.renamed`
- `asset.deleted`

### FileRuntime

- `sanitizeFileName(fileName)`
- `uploadFile(params)`
- `readFileContent(fileId)`
- `verifyFiles(paths)`
- `deleteFile(fileId)`
- `listFiles()`

事件：

- `file.uploaded`
- `file.deleted`

### SpriteRuntime

- `uploadSprite(params)`
- `importRisuSprites(characterName, sprites)`
- `listSprites(characterName, subfolderName)`
- `setExpression(characterName, subfolderName, expression, spriteName)`
- `getExpression(characterName, subfolderName)`
- `deleteSprite(characterName, subfolderName, spriteName)`

事件：

- `sprite.uploaded`
- `sprite.expression.changed`
- `sprite.deleted`

### ThemeRuntime

- `saveTheme(params)`
- `listThemes()`
- `activateTheme(name)`
- `getActiveThemeName()`
- `setActiveBackground(background)`
- `getActiveBackground()`
- `deleteTheme(name)`
- `exportThemes()`
- `importThemes(data, replace)`

事件：

- `theme.saved`
- `theme.activated`
- `theme.background.changed`
- `theme.deleted`

### SettingsRuntime

- `loadFromStore()`
- `saveToStore()`
- `registerSchema(params)`
- `setSetting(scope, scopeId, key, value)`
- `getSetting(scope, scopeId, key)`
- `getEffectiveSetting(scope, scopeId, key)`
- `migrateSetting(scope, scopeId, fromKey, toKey, targetVersion)`
- `snapshot()`
- `listSchemas()`
- `listEntries(scope, scopeId)`

事件：

- `settings.changed`

`SettingsRuntime.loadFromStore()` / `saveToStore()` 使用 `users/<userId>/settings.json`，保存 schema、条目和迁移记录。密钥值不要放入普通 settings，应使用 `SecretRuntime`。

## 十五、其他公开 Runtime 速查

本节列出前文未展开的公开 Runtime。方法名以源码中的公开方法为准；具体参数类型从包入口导出的 `*Models` 类型中导入。

### 应用生命周期和任务

| Runtime | 方法 | 用途 |
|---|---|---|
| `AppRuntime` | `loadManifest()`、`saveManifest(globalMode)`、`loadRuntimeState()`、`saveRuntimeState(...)`、`saveDetailedRuntimeState(...)` | 管理运行时 manifest 和启动状态 |
| `LifecycleRuntime` | `initialize(globalMode)`、`markReady()`、`runStartup(options)` | 组织初始化、ready 标记和启动检查 |
| `TaskRuntime` | `createTask(type)`、`updateTask(taskId, patch)`、`completeTask(taskId)`、`failTask(taskId, error)`、`getTask(taskId)`、`listTasks()` | 管理通用后台任务状态 |
| `EventRuntime` | `emitServerStarted(source)`、`emitRuntimeSignal(signal, source)`、`listCatalog()`、`requireCatalogEntry(name)`、`mapUpstreamEventName(upstreamName)`、`publishCatalogEvent(name, payload)` | 兼容 SillyTavern 风格事件目录和运行时信号 |

### Prompt、模板、指令和文本处理

| Runtime | 方法 | 用途 |
|---|---|---|
| `AuthorNoteRuntime` | `buildInjection(input)` | 把作者注释转成 Prompt 注入段 |
| `PromptTemplateRuntime` | `deriveTemplatesFromChatTemplate(chatTemplate, hash)`、`registerTemplate(params)`、`getTemplate(id)`、`listTemplateIds()`、`renderTemplate(id, data)`、`renderContent(content, data)` | 管理和渲染 Prompt 模板 |
| `InstructRuntime` | `loadPresets(presets)`、`listPresets()`、`updateState(patch)`、`updateContext(patch)`、`getState()`、`getContext()`、`getContextPreset()`、`setModelTemplateMapping(modelId, presetName)`、`selectPreset(name)`、`autoSelectPreset(modelId)`、`getStoppingSequences(userName, characterName)`、`formatChatMessage(...)`、`formatStoryString(storyString)`、`formatPromptLine(name, message)` | 管理 instruct 预设、停止词和消息格式化 |
| `RegexRuntime` | `registerScript(script)`、`unregisterScript(scriptId)`、`listScripts()`、`removeEphemeralScripts()`、`applyScripts(input)` | 注册并应用正则替换脚本 |
| `MacroRuntime` | `registerMacro(params)`、`unregisterMacro(name)`、`expand(input)`、`expandWithStrategy(input)`、`diagnose(input)`、`autocomplete(prefix)`、`listMacros()` | 注册和展开宏变量 |
| `VariableRuntime` | `setVariable(...)`、`setContextVariable(...)`、`setPipeVariable(...)`、`writeCommandVariable(...)`、`getVariable(...)`、`getContextVariable(...)`、`getPipeVariable(...)`、`readCommandVariable(...)`、`deleteVariable(...)`、`deleteContextVariable(...)`、`resolveVariable(key, context)`、`expandVariableMacros(text, context)`、`exportVariables()`、`importVariables(data)`、`listVariables(scope, scopeId)`、`clearTemporaryVariables()`、`clearPipeVariables()` | 管理全局、上下文、管道和命令变量 |
| `PromptCompressionRuntime` | `setConfig(config)`、`getConfig()`、`estimateTokens(text)`、`applyCompression(originalTokens, text)` | 按配置压缩 Prompt 或历史文本 |
| `TokenizerRuntime` | `registerProfile(params)`、`bindModel(modelId, profileId)`、`getProfile(profileIdOrModelId)`、`listProfiles()`、`listTokenizerOptions()`、`selectBestTokenizer(input)`、`countTextForSelection(input)`、`clearCache()`、`countText(...)`、`countMessages(...)`、`buildBudget(...)`、`trimMessagesToBudget(...)` | 管理 tokenizer 配置、计数和预算裁剪 |
| `MessageFormattingRuntime` | `setConfig(config)`、`getConfig()`、`formatText(text)`、`isExtensionEnabled(ext)`、`getCodeBlockLanguages()` | 处理消息文本格式化配置 |
| `SystemPromptRuntime` | `loadSystemPrompts(prompts)`、`listSystemPrompts()`、`saveSystemPrompt(prompt)`、`setEnabled(enabled)`、`toggleSystemPrompt(value)`、`selectSystemPrompt(name, forceGet)`、`migrateFromInstruct(...)`、`getState()` | 管理系统 Prompt 列表和启用状态 |

### 聊天增强、附件、群组和工具

| Runtime | 方法 | 用途 |
|---|---|---|
| `SwipeRuntime` | `createSwipe(params)`、`regenerateSwipe(chatId, messageId)`、`switchSwipe(chatId, messageId, swipeIndex)`、`editSwipe(...)`、`deleteSwipe(...)`、`appendStreamDelta(...)`、`completeStream(...)`、`markFailed(...)`、`markInterrupted(...)`、`getActiveSwipe(...)`、`listSwipes(...)`、`listStates(...)` | 管理单条消息的多候选回复 |
| `BookmarkRuntime` | `createCheckpoint(messages, messageIndex, nameInput, mainChatName)`、`createBranch(messages, messageIndex, nameInput, mainChatName, swipeIndex?)`、`suggestCheckpointName(input)`、`suggestBranchName(input)` | 从聊天历史生成检查点或分支名称 |
| `BranchRuntime` | `createBranch(params)`、`createCheckpoint(params)`、`activateBranch(branchId)`、`getActiveBranch(parentChatId)`、`listBranches(parentChatId)`、`getLineage(chatId)`、`exportBranch(branchId)`、`restoreBranch(data, newBranchId, newChildChatId)` | 管理聊天分支和检查点 |
| `AttachmentRuntime` | `createAttachment(params)`、`getAttachment(attachmentId)`、`listAttachments()`、`bindAttachment(attachmentId, targetType, targetId)`、`listBindings(attachmentId)`、`listAttachmentsForTarget(targetType, targetId)`、`markCaptionResult(...)`、`markTranslationResult(...)`、`listPromptAttachments()`、`listRagDocuments()`、`exportAttachment(...)`、`importAttachment(...)`、`deleteAttachment(...)` | 管理消息附件、Prompt 附件和 RAG 文档附件 |
| `GroupRuntime` | `loadFromStore()`、`saveToStore()`、`createGroup(params)`、`updateGroup(groupId, params)`、`deleteGroup(groupId)`、`getGroup(groupId)`、`listGroups()`、`addMember(...)`、`removeMember(...)`、`reorderMembers(...)`、`listMembers(groupId)`、`bindPersona(...)`、`selectSpeaker(...)`、`buildPromptData(...)`、`queueRegenerate(...)`、`queueContinue(...)`、`queueToolCall(...)`、`listGenerationRequests(...)`、`exportGroup(...)`、`importGroup(...)` | 管理群聊、成员、发言者、群聊生成队列和群聊持久化 |
| `CommandRuntime` | `registerCommand(params)`、`unregisterCommand(name)`、`parseText(text)`、`executeText(text, options)`、`executePipeline(text, options)`、`autocomplete(prefix)`、`getHelp(name)`、`listCommands()` | 注册、解析和执行 slash command |
| `ToolCallingRuntime` | `registerTool(params)`、`unregisterTool(name)`、`listTools()`、`listOpenAITools()`、`invokeToolCalls(calls, reasoningText)`、`executeCallLoop(params)`、`formatInvocationMessage(invocation)` | 管理 OpenAI tool calling 兼容工具 |
| `PluginRuntime` | `installPlugin(manifest)`、`uninstallPlugin(pluginId)`、`enablePlugin(pluginId)`、`disablePlugin(pluginId)`、`getPlugin(pluginId)`、`listPlugins()`、`registerHook(...)`、`unregisterHook(...)`、`dispatchHook(...)`、`setPluginSetting(...)`、`getPluginSetting(...)`、`listPluginSettings(...)`、`addPromptInjection(...)`、`removePluginPromptInjections(pluginId)`、`getPromptInjections(hookPoint)`、`listHooks(pluginId)`、`exportPlugin(...)`、`importPlugin(...)` | 管理插件兼容子集、hook、设置和 Prompt 注入 |

### 媒体、资源和内容

| Runtime | 方法 | 用途 |
|---|---|---|
| `ImageRuntime` | `uploadImage(params)`、`readImageContent(imageId)`、`listImages(folderName, sortOrder)`、`listFolders()`、`deleteImage(imageId)` | 管理图片资源 |
| `ImageMetadataRuntime` | `detectFormat(data)`、`extractMetadata(data)`、`extractCharacterCard(data)`、`writeMetadata(params)`、`writePngCharacterCard(data, cardJson)`、`writeWebpCharacterCard(data, cardJson)`、`isValidImage(data)` | 读取和写入图片 metadata，支持 PNG / WebP 角色卡 |
| `ImageCaptionRuntime` | `startCaption(params)`、`updateProgress(taskId, progress)`、`completeCaption(taskId, result)`、`failCaption(taskId, error)`、`cancelCaption(taskId)`、`getTask(taskId)`、`listTasks(status?)`、`buildVisionRequest(model, imageUrl, prompt)`、`exportData()`、`importData(data)` | 管理图片描述任务和视觉模型请求体 |
| `GalleryRuntime` | `addImage(characterId, fileName, mimeType, path)`、`removeImage(imageId)`、`getImage(imageId)`、`listImages(characterId?)`、`setCaption(imageId, caption)`、`exportData()`、`importData(data)` | 管理角色图库 |
| `BackgroundRuntime` | `importBackground(params)`、`listBackgrounds()`、`listFolders()`、`activateBackground(fileName)`、`renameBackground(backgroundId, newFileName)`、`deleteBackground(backgroundId)` | 管理聊天背景图 |
| `ThumbnailRuntime` | `generateThumbnail(params)`、`getThumbnail(type, fileName)`、`readThumbnailContent(type, fileName)`、`listByType(type)`、`listThumbnails()`、`invalidateThumbnail(type, fileName)`、`getConfiguredDimensions(type)` | 管理缩略图记录和内容 |
| `ExpressionRuntime` | `setExpression(characterId, classification, label, spriteName, intensity, messageId)`、`getCurrentExpression(characterId)`、`listExpressions(characterId)`、`exportData()`、`importData(data)` | 管理角色当前表情状态 |
| `ContentManagerRuntime` | `listContent(contentType?)`、`listByStatus(status)`、`installContent(contentType, source, sourceUrl, displayName)`、`updateProgress(itemId, progress)`、`completeInstall(itemId, installPath, version)`、`failInstall(itemId, error)`、`removeContent(itemId)`、`getItem(itemId)`、`registerPackage(...)`、`listPackages(contentType?)`、`setPackageEnabled(packageId, enabled)`、`removePackage(packageId)`、`exportData()`、`importData(data)` | 管理扩展内容下载、安装和启用状态 |

### 检索、记忆、搜索和统计

| Runtime | 方法 | 用途 |
|---|---|---|
| `MemoryRuntime` | `createEntry(chatId, summary, keyPoints, originalMessages, tokenEstimate)`、`getLatestEntry(chatId)`、`listEntries(chatId?)`、`removeEntry(entryId)`、`buildPromptInjection(chatId, maxEntries)`、`exportData()`、`importData(data)` | 管理聊天摘要记忆，并生成 Prompt 注入文本 |
| `SearchRuntime` | `upsertDocument(document)`、`removeDocument(documentId)`、`searchText(text)`、`isFilterState(left, right)`、`hasAnyFilter(filter)`、`filterEntities(entities, filter)`、`searchByTag(tag)`、`searchMetadata(key, value)`、`search(query)`、`listDocuments()` | 管理内存搜索索引和实体过滤 |
| `StatsRuntime` | `recordTokenUsage(...)`、`recordMessage(...)`、`recordGeneration(...)`、`recordProviderRequest(...)`、`recordRagQuery(...)`、`recordPluginError(...)`、`processCharacterMessage(input)`、`getCharacterStats(characterKey)`、`listCharacterStats()`、`getUserStatsTotals()`、`getSnapshot()` | 记录 token、消息、生成、provider、RAG 和插件错误统计 |
| `SamplerRuntime` | `defaultParams()`、`savePreset(name, params, logitBias)`、`getPreset(presetId)`、`listPresets()`、`deletePreset(presetId)`、`buildLogitBiasJson(bias)`、`applyCfgScale(params, scale)`、`exportData()`、`importData(data)` | 管理采样参数和 logit bias |

### 网络、安全、用户和运维

| Runtime | 方法 | 用途 |
|---|---|---|
| `NetworkPolicyRuntime` | `evaluateHost(host, address)` | 判断网络请求是否被策略允许 |
| `ProxyRuntime` | `configure(settings)`、`getSettings()`、`resolve(targetUrl)` | 管理代理配置和目标 URL 解析 |
| `PermissionRuntime` | `grant(params)`、`revoke(...)`、`check(...)`、`requestConsent(...)`、`resolveConsent(...)`、`checkNetworkAccess(...)`、`addAllowedFileRoot(...)`、`checkFileAccess(...)`、`blockDangerousApi(...)`、`checkDangerousApi(...)`、`setExecutionTimeout(...)`、`recordPluginCrash(pluginId)`、`isPluginIsolated(pluginId)`、`listAudit()`、`listPolicies(subjectType)` | 管理插件或主体权限、同意请求和审计 |
| `SecurityRuntime` | `addRule(pattern, action, scope)`、`removeRule(ruleId)`、`checkInput(scope, input)`、`listRules()`、`listAudits()`、`exportData()`、`importData(data)` | 管理输入安全规则和审计 |
| `UserRuntime` | `createUser(params)`、`listUsers(includeDisabled?)`、`listPublicUsers(discreetLogin)`、`listAdminUsers(adminHandle)`、`getUser(handle)`、`getViewModel(handle, includeAdminFields?)`、`enableUser(...)`、`disableUser(...)`、`promoteUser(...)`、`demoteUser(...)`、`deleteUser(...)`、`changeName(...)`、`changeAvatar(...)`、`changePassword(...)`、`login(handle, password)`、`logout(sessionId)`、`validateSession(sessionId)`、`listSessions()`、`getUserDirectories(handle)`、`slugify(text)` | 管理用户、会话、权限角色和用户目录 |
| `I18nRuntime` | `getCurrentLocale()`、`setLocale(locale)`、`registerBundle(bundle)`、`addLocaleData(locale, source, entries)`、`translate(key, fallback, params)`、`listLocale(locale)`、`listMissing(locale)` | 管理本地化 bundle、翻译和缺失 key |
| `BackupRuntime` | `createBackup(rootPath, destinationPath, kind)`、`createMigrationBackup(rootPath, reason)`、`validateArchive(archive)`、`restoreBackup(archive, targetRootPath)` | 管理备份、迁移备份、校验和恢复 |
| `MigrationRuntime` | `createPlan(steps)`、`executeStep(planId, stepId)`、`rollbackStep(planId, stepId)`、`getPlan(planId)`、`listPlans()`、`exportData()`、`importData(data)` | 管理迁移计划和步骤状态 |
| `RecoveryRuntime` | `createSnapshot(type, metadata)`、`getLatestSnapshot(type)`、`attemptRecovery(type)`、`listSnapshots()` | 管理恢复快照和恢复尝试 |
| `DiagnosticsRuntime` | `recordPromptTrace(...)`、`recordEventTrace(...)`、`recordPluginTrace(...)`、`recordCommandTrace(...)`、`recordScriptTrace(...)`、`recordToolCallTrace(...)`、`recordStreamTrace(...)`、`listRecords()`、`listByKind(kind)`、`listErrors()`、`createBundle(name, kinds, path)`、`listBundles()`、`getHealthSummary()` | 管理诊断记录、错误列表和诊断包 |
| `DataCleanupRuntime` | `registerOrphanFile(path)`、`registerCorruptIndex(path)`、`runCleanup()`、`getStats()` | 记录孤儿文件、损坏索引并生成清理报告 |
| `WebScraperRuntime` | `createRequest(url, extractText, extractImages, maxChars)`、`completeScrape(requestId, title, textContent, imageUrls)`、`failScrape(requestId, error)` | 管理网页抓取任务状态；真实抓取由宿主实现 |

### 翻译、reasoning 和音视频任务

| Runtime | 方法 | 用途 |
|---|---|---|
| `ReasoningRuntime` | `startStreamingAccumulator()`、`stopStreamingAccumulator()`、`applyDelta(messageId, delta)`、`editReasoning(messageId, snapshot)`、`setMetadata(...)`、`setVisibility(...)`、`setPromptPolicy(...)`、`copyReasoning(messageId)`、`formatForPrompt(messageId)`、`getReasoning(messageId)`、`listReasoning()` | 管理模型 reasoning 文本、可见性和 Prompt 策略 |
| `TranslationRuntime` | `setStrategy(strategy)`、`getStrategy(scope)`、`listStrategies()`、`createEntry(...)`、`completeEntry(...)`、`failEntry(...)`、`getEntry(...)`、`findInCache(...)`、`addToCache(...)`、`clearCache()`、`cacheStats()`、`createTask(...)`、`updateTaskProgress(...)`、`completeTask(...)`、`failTask(...)`、`cancelTask(...)`、`getTask(...)`、`listTasks(status?)`、`listEntries()`、`exportData()`、`importData(data)` | 管理翻译策略、翻译条目、缓存和批量任务 |
| `ASRRuntime` | `startTranscription(params)`、`updateProgress(...)`、`completeTranscription(...)`、`failTranscription(...)`、`cancelTranscription(...)`、`getTask(...)`、`listTasks(status?)`、`buildWhisperRequest(...)`、`exportData()`、`importData(data)` | 管理语音转文字任务和 Whisper 请求体 |
| `TTSRuntime` | `synthesize(params)`、`updateProgress(...)`、`completeSynthesis(...)`、`failSynthesis(...)`、`cancelSynthesis(...)`、`getTask(...)`、`listTasks(status?)`、`saveVoiceProfile(...)`、`getVoiceProfile(...)`、`listVoiceProfiles(provider?)`、`deleteVoiceProfile(...)`、`buildOpenAITTSRequest(...)`、`buildEdgeTTSRequest(...)`、`exportData()`、`importData(data)` | 管理文字转语音任务、音色配置和请求体 |

## 十六、事件目录

事件命名规则通常是 `领域.动作`。下表列出当前源码中直接发布的主要事件。

| 事件名 | 含义 |
|---|---|
| `character.created` | 创建或复制角色 |
| `character.imported` | 导入角色 |
| `character.updated` | 更新角色 |
| `character.deleted` | 删除角色，payload 包含角色记录 |
| `character.deleted.id` | 删除角色，payload 只包含角色 ID |
| `chat.created` | 创建或复制聊天 |
| `chat.imported` | 导入聊天 JSONL |
| `chat.updated` | 重命名或归档聊天 |
| `chat.duplicated` | 复制聊天 |
| `chat.deleted` | 删除聊天 |
| `message.added` | 添加消息 |
| `message.updated` | 更新或移动消息 |
| `message.deleted` | 删除消息 |
| `worldinfo.created` | 创建世界书 |
| `worldinfo.updated` | 世界书或条目更新 |
| `worldinfo.deleted` | 删除世界书 |
| `worldinfo.imported` | 导入世界书 |
| `worldinfo.activated` | 世界书条目激活 |
| `prompt.built` | Prompt 构建完成 |
| `stream.started` | 流会话开始 |
| `stream.delta` | 流式增量到达 |
| `stream.completed` | 流会话完成 |
| `stream.aborted` | 流会话中止 |
| `generation.started` | Provider 生成任务开始 |
| `generation.completed` | Provider 生成任务完成 |
| `generation.failed` | Provider 生成任务失败或中止 |
| `connectionProfile.created` | 连接配置创建 |
| `connectionProfile.updated` | 连接配置更新 |
| `connectionProfile.deleted` | 连接配置删除 |
| `connectionProfile.activeChanged` | 激活连接配置变化 |
| `secret.created` | 密钥创建 |
| `secret.updated` | 密钥状态更新 |
| `secret.deleted` | 密钥删除 |
| `secret.rotated` | 密钥轮换 |
| `avatar.uploaded` | 头像上传 |
| `avatar.deleted` | 头像删除 |
| `databank.document.created` | Data Bank 文档创建 |
| `databank.document.enabled` | 文档启用 |
| `databank.document.disabled` | 文档禁用 |
| `databank.document.updated` | 文档元数据更新 |
| `databank.document.deleted` | 文档删除 |
| `vector.upserted` | 向量写入或覆盖 |
| `vector.deleted` | 向量删除 |
| `rag.retrieved` | RAG 检索完成 |
| `embedding.model.registered` | embedding 模型注册 |
| `embedding.result` | embedding 结果保存 |
| `ui.requested` | Runtime 请求宿主展示 UI |
| `ui.resolved` | UI 请求已响应 |
| `persona.created` | 用户人格创建 |
| `persona.updated` | 用户人格更新 |
| `persona.deleted` | 用户人格删除 |
| `persona.changed` | 当前用户人格变化 |
| `persona.imported` | 用户人格导入 |
| `preset.created` | 预设创建 |
| `preset.updated` | 预设更新 |
| `preset.deleted` | 预设删除 |
| `preset.bound` | 预设绑定 |
| `preset.imported` | 预设导入 |
| `preset.migrated` | 预设迁移 |
| `quickReply.setUpdated` | 快捷回复集合变化 |
| `quickReply.executed` | 快捷回复执行 |
| `asset.imported` | 资源导入 |
| `asset.renamed` | 资源重命名 |
| `asset.deleted` | 资源删除 |
| `file.uploaded` | 文件上传 |
| `file.deleted` | 文件删除 |
| `sprite.uploaded` | 表情图上传 |
| `sprite.expression.changed` | 表情选择变化 |
| `sprite.deleted` | 表情图删除 |
| `theme.saved` | 主题保存 |
| `theme.activated` | 主题激活 |
| `theme.background.changed` | 背景变化 |
| `theme.deleted` | 主题删除 |
| `settings.changed` | 设置变化 |
| `server-started` | 运行时服务启动信号 |
| `runtime.signal` | 运行时通用信号 |
| `event.catalog.published` | 事件目录事件发布 |
| `task.updated` | 通用任务状态变化 |
| `tag.map.updated` | 标签映射变化 |
| `i18n.locale.changed` | 当前语言变化 |
| `i18n.bundle.registered` | 本地化 bundle 注册 |
| `i18n.missing` | 翻译 key 缺失 |
| `sampler.preset.saved` | 采样预设保存 |
| `image.uploaded` | 图片上传 |
| `image.deleted` | 图片删除 |
| `caption.started` | 图片描述任务开始 |
| `caption.progress` | 图片描述任务进度 |
| `caption.completed` | 图片描述任务完成 |
| `caption.failed` | 图片描述任务失败 |
| `caption.cancelled` | 图片描述任务取消 |
| `background.imported` | 背景导入 |
| `background.renamed` | 背景重命名 |
| `background.deleted` | 背景删除 |
| `thumbnail.generated` | 缩略图生成 |
| `thumbnail.invalidated` | 缩略图失效 |
| `image.generation.started` | 图片生成开始 |
| `image.generation.progress` | 图片生成进度 |
| `image.generation.completed` | 图片生成完成 |
| `image.generation.failed` | 图片生成失败 |
| `image.generation.cancelled` | 图片生成取消 |
| `image.generation.preset.saved` | 图片生成预设保存 |
| `asr.transcription.started` | 转录开始 |
| `asr.transcription.progress` | 转录进度 |
| `asr.transcription.completed` | 转录完成 |
| `asr.transcription.failed` | 转录失败 |
| `asr.transcription.cancelled` | 转录取消 |
| `tts.synthesis.started` | TTS 开始 |
| `tts.synthesis.progress` | TTS 进度 |
| `tts.synthesis.completed` | TTS 完成 |
| `tts.synthesis.failed` | TTS 失败 |
| `tts.synthesis.cancelled` | TTS 取消 |
| `tts.voice.profile.saved` | TTS 音色配置保存 |
| `network.request.allowed` | 网络策略允许请求 |
| `network.request.blocked` | 网络策略阻止请求 |
| `permission.granted` | 权限授予 |
| `permission.consent.requested` | 请求用户同意 |
| `permission.consent.resolved` | 用户同意请求已处理 |
| `permission.checked` | 权限检查完成 |
| `diagnostics.bundle.created` | 诊断包创建 |
| `diagnostics.record.created` | 诊断记录创建 |
| `backup.completed` | 备份完成 |
| `backup.restored` | 备份恢复 |
| `datacleanup.completed` | 数据清理完成 |
| `migration.started` | 迁移开始 |
| `migration.step.completed` | 迁移步骤完成 |
| `migration.completed` | 迁移完成 |
| `recovery.attempted` | 恢复尝试完成 |
| `plugin.registered` | 插件注册 |
| `plugin.uninstalled` | 插件卸载 |
| `plugin.enabled` | 插件启用 |
| `plugin.disabled` | 插件禁用 |
| `plugin.hook.applied` | 插件 hook 应用 |
| `plugin.prompt.injected` | 插件注入 Prompt |
| `stats.updated` | 统计数据变化 |
| `stats.provider.error` | provider 错误被统计 |
| `stats.plugin.error` | 插件错误被统计 |
| `command.registered` | 命令注册 |
| `command.executed` | 命令执行 |
| `command.error` | 命令错误 |
| `tool.registered` | 工具注册 |
| `tool.called` | 工具调用 |
| `tool.error` | 工具错误 |
| `regex.applied` | 正则脚本应用 |
| `authorNote.built` | 作者注释生成 |
| `promptTemplate.rendered` | Prompt 模板渲染 |
| `prompt.compression.applied` | Prompt 压缩应用 |
| `macro.registered` | 宏注册 |
| `macro.expanded` | 宏展开 |
| `variable.changed` | 变量写入或更新 |
| `variable.deleted` | 变量删除 |
| `tokenizer.profile.registered` | tokenizer 配置注册 |
| `tokenizer.counted` | token 统计完成 |
| `tokenizer.budget.built` | token 预算生成 |
| `message.swipe.changed` | 消息 swipe 变化 |
| `message.swipe.deleted` | 消息 swipe 删除 |
| `message.reasoning.delta` | 消息 reasoning 增量 |
| `message.reasoning.updated` | 消息 reasoning 更新 |
| `reasoning.delta` | reasoning 增量 |
| `reasoning.updated` | reasoning 记录更新 |
| `attachment.added` | 附件添加 |
| `attachment.updated` | 附件更新 |
| `attachment.deleted` | 附件删除 |
| `message.attachment.added` | 消息附件添加 |
| `message.attachment.deleted` | 消息附件删除 |
| `bookmark.created` | 书签或检查点创建 |
| `bookmark.branch.created` | 从书签创建聊天分支 |
| `branch.checkpoint.created` | 分支检查点创建 |
| `branch.activated` | 激活分支变化 |
| `group.created` | 群组创建 |
| `group.updated` | 群组更新 |
| `group.deleted` | 群组删除 |
| `group.member.added` | 群组成员添加 |
| `group.persona.bound` | 群组 persona 绑定 |
| `group.speaker.selected` | 群组发言者选择 |
| `group.imported` | 群组导入 |
| `memory.extracted` | 聊天记忆摘要创建 |
| `search.indexed` | 搜索文档写入索引 |
| `search.removed` | 搜索文档移除 |
| `search.result` | 搜索完成 |
| `gallery.image.added` | 角色图库图片添加 |
| `gallery.image.removed` | 角色图库图片移除 |
| `expression.changed` | 角色表情状态变化 |
| `content.download.progress` | 内容下载或安装进度变化 |
| `content.installed` | 内容安装完成 |
| `content.install.failed` | 内容安装失败 |
| `content.removed` | 内容移除 |
| `proxy.configured` | 代理配置变化 |
| `proxy.resolved` | 目标 URL 代理解析完成 |
| `security.check` | 安全输入检查完成 |
| `translation.strategy.updated` | 翻译策略更新 |
| `translation.cache.hit` | 翻译缓存命中 |
| `translation.task.started` | 翻译任务开始 |
| `translation.task.progress` | 翻译任务进度 |
| `translation.task.completed` | 翻译任务完成 |
| `translation.task.failed` | 翻译任务失败 |
| `translation.task.cancelled` | 翻译任务取消 |
| `webscraper.completed` | 网页抓取任务完成 |
| `user.deleted` | 用户删除 |
| `user.logged_in` | 用户登录 |
| `user.logged_out` | 用户登出 |

## 十七、错误处理约定

大多数读取、更新、删除方法在目标不存在时会抛出 `Error`。宿主应在 UI 层捕获异常并显示用户可理解的错误。

常见错误：

- `Character not found: <id>`：角色不存在。
- `Chat not found: <id>`：聊天不存在。
- `消息未找到: <id>`：消息不存在。
- `WorldBook not found: <id>`：世界书不存在。
- `WorldInfo entry not found: <book>/<entry>`：世界书条目不存在。
- `Secret not found: <ref>`：密钥不存在。
- `Vector collection not found: <id>`：向量集合不存在。
- `Vector dimension mismatch`：向量维度不匹配。

## 十八、版本和能力边界

当前 SDK 中“请求体构造”“OpenAI-compatible chat streaming 默认发送”“响应解析”“事件分发”“本地数据管理”由 SDK 负责；系统权限、安全存储、文件选择器、UI 渲染，以及内置适配器未覆盖的 provider 请求发送由宿主负责。

OpenAI-compatible chat streaming 可由 `OpenAIOhosProviderStreamSource` 通过 `openai_ohos` 直接发出。`ProviderRuntime` 仍保留 `ProviderStreamSource` 抽象，方便宿主替换为自定义网络、代理、离线模型或测试替身。Embedding、图片、Whisper、TTS 等 Runtime 当前仍主要提供请求体、任务状态和结果写回接口。
