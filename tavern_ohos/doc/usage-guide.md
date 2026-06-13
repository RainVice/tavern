# tavern_ohos 使用指南

本文面向宿主应用开发者，说明如何把 `tavern_ohos` 接入到 OpenHarmony / HarmonyOS 项目里，并按功能场景完成初始化、保存、读取、请求构造、事件监听和 UI 刷新。

`tavern_ohos` 是无 UI 后台运行时 SDK。它负责 SillyTavern 风格的数据结构、Prompt 组装、世界书激活、流式响应解析、导入导出、事件分发和应用沙箱内的默认文件读写；宿主应用负责页面、权限、真实网络请求、密钥安全存储和设备能力。

## 一、接入前提

使用任何功能前，宿主应用都需要准备这些基础对象：

1. 引入 HAR 包。
2. 创建一个全局 `EventBus`。
3. 使用 `SandboxTavernFileStore` 创建文件存储，测试时可改用 `InMemoryFileStore`。
4. 约定 `rootPath` 和 `userId`。
5. 按功能创建 Runtime。
6. 订阅必要事件，并在页面销毁时取消订阅。

### 1. 引入模块

在宿主模块 `oh-package.json5` 中添加本地依赖：

```json5
{
  "dependencies": {
    "tavern_ohos": "file:../tavern_ohos"
  }
}
```

ArkTS 中从包入口导入：

```ts
import {
  EventBus,
  SandboxTavernFileStore,
  CharacterRuntime,
  ChatRuntime,
  MessageRuntime,
  WorldInfoRuntime,
  PromptRuntime,
  StreamingRuntime,
  ProviderRuntime,
  type EventSubscription,
  type TavernFileStore,
} from 'tavern_ohos';
```

### 2. 创建应用级运行时容器

推荐宿主封装一个容器，统一管理 Runtime，避免每个页面重复初始化：

```ts
import {
  EventBus,
  SandboxTavernFileStore,
  CharacterRuntime,
  ChatRuntime,
  WorldInfoRuntime,
  PromptRuntime,
  StreamingRuntime,
  ProviderRuntime,
  type TavernFileStore,
} from 'tavern_ohos';

export class TavernRuntimeContainer {
  readonly events: EventBus;
  readonly files: TavernFileStore;
  readonly rootPath: string;
  readonly userId: string;
  readonly characters: CharacterRuntime;
  readonly chats: ChatRuntime;
  readonly worldInfo: WorldInfoRuntime;
  readonly prompt: PromptRuntime;
  readonly streaming: StreamingRuntime;
  readonly provider: ProviderRuntime;

  constructor(appFilesDir: string, files?: TavernFileStore) {
    this.events = new EventBus();
    this.files = files ?? new SandboxTavernFileStore(appFilesDir);
    this.rootPath = 'tavern-data';
    this.userId = 'default';
    this.characters = new CharacterRuntime(this.files, this.events, this.rootPath, this.userId);
    this.chats = new ChatRuntime(this.files, this.events, this.rootPath, this.userId);
    this.worldInfo = new WorldInfoRuntime(this.files, this.events, this.rootPath, this.userId);
    this.prompt = new PromptRuntime(this.events);
    this.streaming = new StreamingRuntime(this.events);
    this.provider = new ProviderRuntime(this.events, this.streaming);
  }
}
```

正式应用使用 `SandboxTavernFileStore`。它只需要应用沙箱根目录，写入时按需创建父目录。`InMemoryFileStore` 只适合测试和临时演示。

### 3. 文件存储使用前的检查

使用需要落盘的功能前，先确认这些点：

1. 从 UIAbility 或页面上下文取得应用可写沙箱目录，再传给 `SandboxTavernFileStore`。
2. 不需要调用初始化目录的方法；SDK 会在具体功能写入时创建父目录。
3. `rootPath` 只表示 SDK 数据根的相对目录，例如 `tavern-data`。
4. 多个 Runtime 必须复用同一个 `TavernFileStore`、`rootPath` 和 `userId`。
5. 只有加密存储、云同步、测试替身等高级场景才需要自定义 `TavernFileStore`。

角色、聊天、世界书、Data Bank、向量、资源、文件、头像、表情图等功能都依赖 `TavernFileStore`。

## 二、事件总线使用方式

SDK 内部状态变更后会发布事件。页面应订阅事件刷新列表或展示状态。

```ts
import {
  type RuntimeEvent,
  type MessageEventPayload,
  type EventSubscription,
} from 'tavern_ohos';

const subscriptions: Array<EventSubscription> = [];

subscriptions.push(container.events.subscribe<MessageEventPayload>(
  'message.added',
  (event: RuntimeEvent<MessageEventPayload>) => {
    const message = event.payload.message;
    console.info(`收到新消息: ${message.id}`);
  },
));

// 页面销毁时取消订阅。
for (let index = 0; index < subscriptions.length; index += 1) {
  subscriptions[index].unsubscribe();
}
```

事件对象包含：

- `name`：事件名，例如 `message.added`。
- `payload`：事件数据。
- `sequence`：当前 `EventBus` 内递增序号。
- `timestamp`：发布时间戳。

事件 payload 会被深拷贝。修改事件对象不会反向修改 Runtime 内部状态。

## 三、角色卡功能

### 场景一：创建并保存本地角色卡

前提：

1. 已创建 `EventBus`。
2. 已准备 `TavernFileStore`。
3. 已创建 `CharacterRuntime`。

步骤：

1. 调用 `createCharacter()`。
2. 保存返回的 `CharacterRecord.id`。
3. 刷新角色列表或监听 `character.created`。
4. 如需头像，再调用 `AvatarRuntime.uploadAvatar()`。

```ts
const character = await container.characters.createCharacter({
  name: 'Alice',
  description: '一名友好的助手。',
  personality: '温和、清晰、可靠。',
  scenario: '和用户进行日常对话。',
  firstMessage: '你好，我是 Alice。',
  exampleDialogue: '<START>\nUser: 你好\nAlice: 你好。',
  tags: ['assistant'],
  favorite: true,
  talkativeness: 0.5,
  world: 'main-world',
});
```

保存结果：

- 角色索引写入 `<rootPath>/users/<userId>/characters/index.json`。
- 完整角色写入 `<rootPath>/users/<userId>/characters/<characterId>/character.json`。
- 事件 `character.created` 会发布。

### 场景二：读取角色卡详情和列表

前提：

1. 已有角色 ID。
2. 使用同一 `rootPath`、`userId` 和 `TavernFileStore`。

步骤：

1. 列表页调用 `listCharacters()`。
2. 详情页调用 `getCharacter(characterId)`。
3. 不要把 `CharacterIndexEntry` 当完整角色使用。

```ts
const list = await container.characters.listCharacters();
const detail = await container.characters.getCharacter(list[0].id);
```

### 场景三：更新、复制和删除角色卡

前提：

1. 已有完整 `CharacterRecord`。
2. 更新时需要传入所有 `CharacterUpdateParams` 必需字段。

步骤：

1. 先 `getCharacter()`。
2. 修改字段后调用 `updateCharacter()`。
3. 如需另存一份，调用 `duplicateCharacter()`。
4. 删除时调用 `deleteCharacter()`，并清理 UI 当前选中状态。

```ts
const loaded = await container.characters.getCharacter('char-1');

const updated = await container.characters.updateCharacter(loaded.id, {
  name: loaded.name,
  description: `${loaded.description}\n补充设定。`,
  personality: loaded.personality,
  scenario: loaded.scenario,
  firstMessage: loaded.firstMessage,
  exampleDialogue: loaded.exampleDialogue,
  tags: loaded.tags,
  favorite: loaded.favorite,
});

const copied = await container.characters.duplicateCharacter(updated.id, `${updated.name} 副本`);
await container.characters.deleteCharacter(copied.id);
```

注意：`updateCharacter()` 会清空 `sourceJson`，之后再导出会按当前记录重新生成 V2 JSON。

### 场景四：导入 SillyTavern 角色卡

前提：

1. 用户选择了 JSON、charx、PNG 或 WebP 文件。
2. 宿主已经读取文件内容。
3. JSON 文本用字符串传入；PNG / WebP 用 `ArrayBuffer` 传入。

步骤：

1. V2 JSON 可直接调用 `importCharacterJson()`。
2. V1、charx、PNG metadata、WebP metadata 先用 `CharacterCodecRuntime` 解析。
3. 解析结果通过 `exportToV2()` 转成 V2 JSON。
4. 再调用 `importCharacterJson()` 保存。

```ts
import { CharacterCodecRuntime } from 'tavern_ohos';

const codec = new CharacterCodecRuntime();

const parsed = codec.parseCharacterJson(rawCardJson);
const normalizedV2 = codec.exportToV2(parsed);
const saved = await container.characters.importCharacterJson(normalizedV2);
```

PNG metadata：

```ts
const parsedFromPng = codec.parsePngCharacterCard(pngArrayBuffer);
const normalizedV2 = codec.exportToV2(parsedFromPng);
const saved = await container.characters.importCharacterJson(normalizedV2);
```

WebP metadata：

```ts
const parsedFromWebp = codec.parseWebpCharacterCard(webpArrayBuffer);
const normalizedV2 = codec.exportToV2(parsedFromWebp);
const saved = await container.characters.importCharacterJson(normalizedV2);
```

事件：

- `character.imported`：导入成功。

### 场景五：导出角色卡

前提：

1. 已有角色 ID。
2. 需要 JSON 时直接导出。
3. 需要 PNG 或 WebP 时必须提供一个有效图片作为载体。

步骤：

1. 调用 `exportCharacterJson(characterId)`。
2. 如果导出 PNG 或 WebP，使用 `CharacterCodecRuntime.parseCharacterJson()` 解析 JSON。
3. 调用 `exportToPng(parsed, sourcePngArrayBuffer)` 或 `exportToWebp(parsed, sourceWebpArrayBuffer)` 写入 metadata。

```ts
const json = await container.characters.exportCharacterJson('char-1');
const parsed = codec.parseCharacterJson(json);
const png = codec.exportToPng(parsed, sourcePngArrayBuffer);
const webp = codec.exportToWebp(parsed, sourceWebpArrayBuffer);
```

### 场景六：保存和读取头像

前提：

1. 已有角色 ID。
2. 宿主已读取图片内容。当前 `AvatarRuntime` 的 `content` 是字符串。

步骤：

1. 创建 `AvatarRuntime`。
2. 调用 `uploadAvatar('character', characterId, ...)`。
3. 需要展示时调用 `getAvatar()` 获取记录，再用 `readAvatarContent()` 读取内容。

```ts
import { AvatarRuntime, type AvatarCrop } from 'tavern_ohos';

const avatars = new AvatarRuntime(container.files, container.events);
const crop: AvatarCrop = { x: 0, y: 0, width: 0, height: 0 };

await avatars.uploadAvatar('character', 'char-1', 'avatar.png', 'image/png', 'png-data', crop);
const avatar = await avatars.getAvatar('character', 'char-1');
const content = await avatars.readAvatarContent('character', 'char-1');
```

事件：

- `avatar.uploaded`：头像保存或覆盖。
- `avatar.deleted`：头像删除。

## 四、聊天和消息功能

### 场景一：创建聊天

前提：

1. 已有角色 ID。
2. 已有用户人格 ID，或使用宿主约定的默认 ID。
3. 已创建 `ChatRuntime`。

步骤：

1. 调用 `createChat()` 创建会话。
2. 使用 `chats.messages(chat.id)` 获取消息 Runtime。
3. 写入用户消息和助手消息。
4. 页面监听 `chat.created`、`message.added`。

```ts
const chat = await container.chats.createChat({
  title: '和 Alice 的对话',
  characterId: 'char-1',
  personaId: 'persona-default',
});

const messages = container.chats.messages(chat.id);
await messages.addMessage({ role: 'user', name: 'User', text: '你好' });
await messages.addMessage({ role: 'assistant', name: 'Alice', text: '你好。' });
```

### 场景二：展示聊天列表

前提：

1. 使用同一 `rootPath` 和 `userId`。
2. 消息文件存在或为空。

步骤：

1. 调用 `listChats()`。
2. 使用返回的 `messageCount` 和 `previewMessage` 渲染列表。
3. 搜索时调用 `searchChats(query)`。

```ts
const chats = await container.chats.listChats();
const matched = await container.chats.searchChats('Alice');
```

### 场景三：消息分页和修改

前提：

1. 已有 `chatId`。
2. 已创建 `MessageRuntime`。

步骤：

1. `listMessagesPage(start, limit)` 分页。
2. `updateMessage()` 修改正文和系统标记。
3. `moveMessage()` 调整顺序。
4. `hideMessage()` 设置 `isSystem`。
5. `setMessageRating()`、`setMessageBookmark()` 写入 `extraJson`。
6. 删除单条用 `deleteMessage()`，批量删除用 `deleteMessages()`。

```ts
const messages = container.chats.messages('chat-1');
const page = await messages.listMessagesPage(0, 30);
await messages.updateMessage('msg-2', { text: '新的回复。', isSystem: false });
await messages.setMessageRating('msg-2', 5);
await messages.setMessageBookmark('msg-2', true);
await messages.deleteMessage('msg-1');
```

事件：

- `message.added`：新增消息。
- `message.updated`：更新、移动消息时发布。
- `message.deleted`：删除消息。

### 场景四：聊天导入导出

前提：

1. 导出时已有 `chatId`。
2. 导入时宿主已选择目标角色和用户人格。

步骤：

1. 导出调用 `exportChatJsonl(chatId)`。
2. 导入调用 `importChatJsonl(jsonl, title, characterId, personaId)`。
3. 导入失败时捕获 JSON 解析异常并提示用户。

```ts
const jsonl = await container.chats.exportChatJsonl('chat-1');
const imported = await container.chats.importChatJsonl(jsonl, '导入聊天', 'char-1', 'persona-default');
```

事件：

- `chat.imported`：导入聊天。
- `chat.updated`：重命名或归档。
- `chat.deleted`：删除聊天。

## 五、世界书功能

### 场景一：创建世界书

前提：

1. 已创建 `WorldInfoRuntime`。
2. 已准备 `TavernFileStore`。

步骤：

1. 调用 `createWorldBook(name)`。
2. 调用 `createEntry(worldBookId, params)` 添加条目。
3. 保存返回的 `worldBook.id`。

```ts
const book = await container.worldInfo.createWorldBook('战役设定');
await container.worldInfo.createEntry(book.id, {
  comment: '龙',
  keys: ['龙'],
  secondaryKeys: [],
  content: '龙是一种古老而强大的生物。',
  constant: false,
  selective: false,
  enabled: true,
  insertionOrder: 10,
  position: 'before',
  caseSensitive: false,
});
```

事件：

- `worldinfo.created`：创建世界书。
- `worldinfo.updated`：新增、更新、删除条目。

### 场景二：读取和维护世界书

前提：

1. 已有 `worldBookId`。

步骤：

1. 列表页调用 `listWorldBooks()`。
2. 详情页调用 `getWorldBook(worldBookId)`。
3. 更新条目调用 `updateEntry()`。
4. 删除条目调用 `deleteEntry()`。
5. 删除世界书调用 `deleteWorldBook()`。

```ts
const list = await container.worldInfo.listWorldBooks();
const book = await container.worldInfo.getWorldBook(list[0].id);
const entry = book.entries[0];

await container.worldInfo.updateEntry(book.id, entry.id, {
  comment: entry.comment,
  keys: entry.keys,
  secondaryKeys: entry.secondaryKeys,
  content: `${entry.content}\n补充设定。`,
  constant: entry.constant,
  selective: entry.selective,
  enabled: entry.enabled,
  insertionOrder: entry.insertionOrder,
  position: entry.position,
  caseSensitive: entry.caseSensitive,
});
```

### 场景三：激活世界书并拼进 Prompt

前提：

1. 已有至少一个世界书 ID。
2. 已有最近聊天消息文本。
3. 已创建 `PromptRuntime`。

步骤：

1. 从聊天消息提取文本数组。
2. 调用 `activateEntries(worldBookIds, messages)`。
3. 把返回的 `WorldInfoActivation` 传给 `PromptRuntime.buildPrompt()`。
4. 需要递归扫描时改用 `activateEntriesRecursive()`。

```ts
const history = ['User: 我看到了一条龙。'];
const activation = await container.worldInfo.activateEntries(['worldbook-1'], history);

const prompt = container.prompt.buildPrompt({
  id: 'prompt-1',
  systemPrompt: '你是一个可靠的助手。',
  personaName: 'User',
  personaDescription: '',
  authorNote: '',
  character: characterRecord,
  messages: chatMessages,
  worldInfo: activation,
  maxEstimatedTokens: 4096,
});
```

事件：

- `worldinfo.activated`：激活完成。payload 包含 `worldBookIds`、`entries`、`matches`。

### 场景四：世界书导入导出

前提：

1. 导出时已有 `worldBookId`。
2. 导入时宿主已校验 JSON 来源。

步骤：

1. 导出调用 `exportWorldBookJson(worldBookId)`。
2. 导入调用 `importWorldBookJson(json, newName)`。
3. 导入后 SDK 会生成新 ID，不覆盖原 ID。

```ts
const json = await container.worldInfo.exportWorldBookJson('worldbook-1');
const imported = await container.worldInfo.importWorldBookJson(json, '导入的世界书');
```

## 六、Prompt 组装

前提：

1. 已有完整 `CharacterRecord`。
2. 已有 `ChatMessage[]`。
3. 已完成世界书激活，或传入空 `WorldInfoActivation`。
4. 已准备 persona 文本和 author note 文本。

步骤：

1. 调用 `PromptRuntime.buildPrompt()`。
2. 读取 `result.finalText` 作为模型 prompt。
3. 查看 `result.sections` 调试每段来源。
4. 根据 `result.debug.trimmedSections` 判断是否裁剪了历史消息。

```ts
const result = container.prompt.buildPrompt({
  id: 'prompt-1',
  systemPrompt: '你是一个可靠的助手。',
  personaName: 'User',
  personaDescription: '用户喜欢简洁回答。',
  authorNote: '',
  character: characterRecord,
  messages: chatMessages,
  worldInfo: activation,
  maxEstimatedTokens: 4096,
});

const promptText = result.finalText;
```

事件：

- `prompt.built`：Prompt 构建完成。

## 七、OpenAI-compatible 请求和流式响应

SDK 不直接发送 HTTP。宿主必须实现网络层。

### 场景一：构造文本补全请求体

前提：

1. 已有模型、prompt、采样参数。
2. 已有 serverUrl 和 headers。

步骤：

1. 调用 `ProviderRuntime.buildTextCompletionRequest()`。
2. 宿主拼接 URL：`${serverUrl}${request.path}`。
3. 宿主使用 HarmonyOS 网络 API 发起 POST。
4. 宿主解析非流式响应并写回消息。

```ts
const request = container.provider.buildTextCompletionRequest({
  apiType: 'openai',
  model: 'gpt-4o-mini',
  prompt: promptText,
  temperature: 0.7,
  maxTokens: 512,
  stop: [],
  stream: false,
  topP: 0.9,
});
```

### 场景二：接入 OpenAI-compatible SSE 流

前提：

1. 已有 `StreamingRuntime` 和 `ProviderRuntime`。
2. 已有待写回的 assistant 消息 ID。
3. 宿主能发起 SSE、WebSocket 或分块 HTTP 请求。
4. 宿主实现 `ProviderStreamSource`。

步骤：

1. 先创建 assistant 空消息。
2. 调用 `streaming.attachMessageRuntime(messages)`，让普通文本 delta 自动写回消息。
3. 实现 `ProviderStreamSource.start()`。
4. 每收到一段 SSE 文本，调用 `sink.onChunk(chunk)`。
5. 完成时调用 `sink.onDone()`。
6. 失败时调用 `sink.onError(message)`。

```ts
import {
  type ProviderStreamHandle,
  type ProviderStreamRequest,
  type ProviderStreamSink,
  type ProviderStreamSource,
} from 'tavern_ohos';

class HttpSseSource implements ProviderStreamSource {
  async start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle> {
    // 这里接入宿主网络层。收到每段 SSE 原文后调用 sink.onChunk(chunk)。
    return {
      close(): void {
        // 这里关闭宿主请求。
      },
    };
  }
}

const messages = container.chats.messages('chat-1');
const assistant = await messages.addMessage({ role: 'assistant', name: 'Alice', text: '' });
container.streaming.attachMessageRuntime(messages);

await container.provider.startOpenAICompatibleStream({
  taskId: 'generation-1',
  chatId: 'chat-1',
  messageId: assistant.id,
  request: {
    provider: 'openai-compatible',
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: '你好' }],
    temperature: 0.7,
    maxTokens: 512,
    stop: [],
    stream: true,
  },
  source: new HttpSseSource(),
});
```

事件：

- `generation.started`：生成任务开始。
- `stream.started`：内部流会话开始。
- `stream.delta`：收到普通文本或 reasoning 增量。
- `stream.completed`：流会话完成。
- `generation.completed`：Provider 任务完成。
- `generation.failed`：Provider 任务失败或中止。

`stream.delta` 中：

- `delta` 是本次增量。
- `snapshot` 是当前普通文本累计内容。
- `reasoning` 表示本次增量是否为推理文本。
- `reasoningSnapshot` 是推理文本累计内容。

## 八、连接配置和密钥

前提：

1. 不要把真实 API key 写入普通日志。
2. 已准备 `TavernFileStore`；生产环境建议给 `SecretRuntime` 传入加密存储或系统安全存储适配器。
3. `NetworkService` 只解析 headers，不发送请求。

步骤：

1. 用 `new SecretRuntime(events, files, 'tavern-data', 'default')` 和 `new ConnectionProfileRuntime(events, files, 'tavern-data', 'default')` 创建运行时。
2. 应用启动后先调用 `await secrets.loadFromStore()` 和 `await connections.loadFromStore()`。
3. 用 `SecretRuntime.createSecret()` 创建密钥引用。
4. 用 `ConnectionProfileRuntime.createProfile()` 创建连接配置。
5. 调用 `await secrets.saveToStore()` 和 `await connections.saveToStore()` 保存修改。
6. 用 `NetworkService.resolveHeadersForProfile()` 得到请求头。
7. 用 `toProviderRequest()` 得到 provider 请求元数据。

```ts
import { ConnectionProfileRuntime, SecretRuntime, NetworkService } from 'tavern_ohos';

const connections = new ConnectionProfileRuntime(container.events);
const secrets = new SecretRuntime(container.events);
const network = new NetworkService(connections, secrets);

const secret = secrets.createSecret({
  id: 'openai-key',
  providerId: 'openai',
  scope: 'profile',
  scopeId: 'profile-openai',
  label: 'OpenAI API Key',
  value: 'sk-...',
  active: true,
});

connections.createProfile({
  id: 'profile-openai',
  name: 'OpenAI',
  apiType: 'openai',
  model: 'gpt-4o-mini',
  serverUrl: 'https://api.openai.com/v1',
  secretRef: secret.secretRef,
  generationPresetId: '',
  systemPromptPresetId: '',
  contextTemplateId: '',
  instructTemplateId: '',
  tokenizer: 'openai',
  stopStrings: [],
  reasoningFormat: '',
  toolCallingEnabled: false,
  proxyUrl: '',
  additionalHeaders: [
    { name: 'Authorization', value: 'Bearer sk-...', secret: true },
  ],
  enabled: true,
});

const headers = network.resolveHeadersForProfile('profile-openai');
```

注意：当前 `openai` / `openai-compatible` 建议宿主显式提供 `Authorization`，或在宿主网络层补齐。

## 九、Data Bank、Embedding、向量和 RAG

前提：

1. 已有文档内容。
2. 宿主能调用 embedding provider 得到向量。
3. 已创建 `DataBankRuntime`、`VectorRuntime`、`RagRuntime`。

步骤：

1. 用 `DataBankRuntime.createDocument()` 保存文档。
2. 用 `EmbeddingRuntime.buildOpenAIRequest()` 构造 embedding 请求体。
3. 宿主发送 embedding 请求。
4. 用 `VectorRuntime.createCollection()` 建集合。
5. 用 `VectorRuntime.upsertVector()` 写入向量。
6. 用 `RagRuntime.retrieve()` 检索。
7. 把 `result.promptText` 放入 Prompt。

```ts
const doc = await dataBank.createDocument({
  id: 'doc-1',
  scope: 'global',
  sourceType: 'manual',
  fileName: '设定资料.txt',
  mimeType: 'text/plain',
  content: '龙生活在北方山脉。',
  tags: ['lore'],
  metadataJson: '{}',
  enabled: true,
});

await vectors.createCollection({
  id: 'lore',
  provider: 'openai',
  model: 'text-embedding-3-small',
  dimension: 3,
  metadataJson: '{}',
});

await vectors.upsertVector('lore', {
  id: doc.id,
  documentId: doc.id,
  scope: doc.scope,
  text: doc.content,
  embedding: [0.1, 0.2, 0.3],
  metadataJson: '{}',
  createdAt: Date.now(),
  updatedAt: Date.now(),
});

const result = rag.retrieve({
  query: '龙在哪里生活？',
  queryEmbedding: [0.1, 0.2, 0.29],
  collectionIds: ['lore'],
  topK: 3,
  scoreThreshold: 0,
  scope: 'global',
  promptTemplate: '参考资料：\n${text}',
});
```

事件：

- `databank.document.created`
- `databank.document.updated`
- `databank.document.deleted`
- `vector.upserted`
- `vector.deleted`
- `rag.retrieved`

## 十、Persona、Preset 和 Quick Reply

这些 Runtime 保留同步 CRUD API，跨启动持久化由 SDK 内部完成。宿主只需要传入 `TavernFileStore`，启动时调用 `loadFromStore()`，修改后调用 `saveToStore()`。

### Persona

前提：

1. 已创建 `new PersonaRuntime(events, files, 'tavern-data', 'default')`。
2. 需要在聊天或全局作用域绑定 persona。

步骤：

1. 应用启动后调用 `await personas.loadFromStore()`。
2. `createPersona()` 创建。
3. `selectPersona()` 设置当前 persona。
4. `bindPersona(scope, scopeId, personaId)` 绑定到聊天或角色。
5. 调用 `await personas.saveToStore()` 保存。
6. `buildPromptDataForScope()` 生成 Prompt 所需 persona 信息。

### Preset

步骤：

1. 用 `new PresetRuntime(events, files, 'tavern-data', 'default')` 创建。
2. 应用启动后调用 `await presets.loadFromStore()`。
3. `createPreset()` 创建预设。
4. `bindPreset(ownerType, ownerId, presetKind, presetId)` 绑定预设。
5. 调用 `await presets.saveToStore()` 保存。
6. `getBinding()` 获取当前绑定。
7. `exportPreset()` / `importPreset()` 做单项导入导出。

### Quick Reply

前提：

1. 已创建 `CommandRuntime`。
2. 用 `new QuickReplyRuntime(events, commands, files, 'tavern-data', 'default')` 创建。

步骤：

1. 应用启动后调用 `await quickReplies.loadFromStore()`。
2. `createSet()` 创建集合，集合里包含 `scope` 和 `scopeId`。
3. `addItem()` 添加按钮。
4. 调用 `await quickReplies.saveToStore()` 保存。
5. `listButtons(scope, scopeId)` 给 UI 渲染按钮。
6. 用户点击后调用 `executeItem()`。
7. 自动触发用 `executeAutoTrigger()`。

## 十一、UI 桥接

`UIBridgeRuntime` 用于让 headless 运行时提出 UI 请求，宿主监听事件后展示真实 UI。

前提：

1. 已创建 `UIBridgeRuntime`。
2. 页面订阅 `ui.requested`。
3. UI 处理完成后调用 `respond()`。

步骤：

1. Runtime 调用 `requestConfirm()`、`requestFilePicker()` 等方法。
2. 宿主收到 `ui.requested`。
3. 宿主展示弹窗、文件选择器或进度条。
4. 宿主调用 `respond(requestId, response)`。

```ts
import { UIBridgeRuntime, type UIRequestEventPayload } from 'tavern_ohos';

const ui = new UIBridgeRuntime(container.events);

container.events.subscribe<UIRequestEventPayload>('ui.requested', (event) => {
  const request = event.payload.request;
  // 宿主根据 request.kind 渲染对应 UI。
});

const request = ui.requestConfirm('删除角色', '确定要删除这个角色吗？');
ui.respond(request.id, {
  accepted: true,
  value: '',
  values: [],
  fileUris: [],
  metadataJson: '{}',
});
```

事件：

- `ui.requested`：有 UI 请求。
- `ui.resolved`：请求已被响应。

## 十二、资源、文件、表情图、主题和设置

### 资源和文件

`AssetRuntime` 适合管理通用资源，`FileRuntime` 适合上传文件并可选绑定附件或 Data Bank。

步骤：

1. 上传或导入资源。
2. 列表页读取记录。
3. 展示时读取内容。
4. 删除时清理关联记录。

### 表情图

步骤：

1. `uploadSprite()` 上传表情。
2. `listSprites(characterName, subfolderName)` 展示表情列表。
3. `setExpression()` 设置当前表情。
4. `getExpression()` 读取当前表情。

### 主题

步骤：

1. `saveTheme()` 保存主题。
2. `listThemes()` 展示主题列表。
3. `activateTheme()` 激活。
4. `setActiveBackground()` 设置背景。
5. `exportThemes()` / `importThemes()` 做备份。

### 设置

步骤：

1. 用 `new SettingsRuntime(events, files, 'tavern-data', 'default')` 创建。
2. 应用启动后调用 `await settings.loadFromStore()`。
3. `registerSchema()` 注册设置项。
4. `setSetting()` 写入设置。
5. 调用 `await settings.saveToStore()` 保存。
6. `getEffectiveSetting()` 读取作用域设置，自动回退全局值或默认值。
7. `snapshot()` 导出当前设置快照。

## 十三、功能接入检查清单

接入任意功能时，按下面顺序检查：

1. 这个功能是否需要 `TavernFileStore`。
2. 这个功能是否有 `loadFromStore()` / `saveToStore()`，是否需要在启动、退后台或切换用户时调用。
3. 当前页面需要订阅哪些事件。
4. 页面销毁时是否调用 `unsubscribe()`。
5. 写入 API 是否返回完整记录，列表 API 是否只是索引记录。
6. 真实网络请求是否由宿主实现。
7. 密钥是否进入日志、普通设置或可导出 JSON。
8. 导入用户文件前是否做 JSON schema、路径和大小校验。
9. 删除操作是否会递归删除关联目录或关联记录。
10. 流式生成是否已创建空 assistant 消息并挂接 `StreamingRuntime.attachMessageRuntime()`。
