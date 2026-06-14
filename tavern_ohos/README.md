# OpenOHOS Headless Tavern Runtime

`tavern_ohos` 是一个面向 OpenHarmony / HarmonyOS 应用的无 UI SillyTavern 后台运行时 SDK。它不包含 Web UI，也不打包 Node.js SillyTavern Server；宿主应用负责界面、权限申请和平台能力接入，本 SDK 负责角色、聊天、消息、Prompt、世界书、预设、插件兼容子集、资源文件、RAG、OpenAI-compatible 流式请求适配、流式响应解析、导入导出和事件分发等后台逻辑。

## 上游同步基准

本模块按 SillyTavern 官方仓库的 `release` 分支做后台能力对齐。后续同步升级时，先更新下列基准信息，再对照 `sillytavern_endpoint_feature_parity_matrix.md` 检查 endpoint 和功能差异。

| 字段 | 值 |
|---|---|
| 官方仓库 | <https://github.com/SillyTavern/SillyTavern> |
| 对齐分支 | `release` |
| 对齐版本 | `1.18.0` |
| 对齐提交 | `51ad27fb86d39a3daca3adaa970375c9670c12df` |
| 记录日期 | `2026-06-11` |

核对命令：

```bash
curl -fsSL https://raw.githubusercontent.com/SillyTavern/SillyTavern/release/package.json
git ls-remote https://github.com/SillyTavern/SillyTavern.git refs/heads/release
```

## 能力边界

SDK 当前提供的是 headless runtime，不直接负责 UI 渲染。OpenAI-compatible chat streaming 默认可使用内置 `OpenAIOhosProviderStreamSource`，它通过 `openai_ohos` 发起 `/chat/completions` SSE 请求；宿主仍可实现自己的 `ProviderStreamSource` 接入 HarmonyOS `http`、WebSocket、SSE、代理网关或离线模型。Embedding、图片、Whisper、TTS 等其他请求体构造类 Runtime 仍由宿主决定真实网络发送和结果写回。

## 详细文档

面向项目接入和二次开发时，优先阅读 `doc` 目录中的两份文档：

- [使用指南](doc/usage-guide.md)：按“前提、步骤、示例、事件”的方式说明角色卡、聊天、世界书、Prompt、OpenAI-compatible 请求、RAG、资源和设置等功能如何在宿主项目中使用。
- [API 文档](doc/api-reference.md)：按 Runtime、公开方法、事件名和错误约定说明 SDK 的 API；例如 `message.added` 表示 `MessageRuntime.addMessage()` 成功添加消息后发布的事件。

适合放在 SDK 内的逻辑：

- 角色卡、聊天、消息、分支、书签、swipe、群聊数据管理。
- Prompt 拼装、世界书激活、正则替换、宏、变量、指令模板、预设。
- Data Bank、向量、RAG、搜索索引、附件、图片、缩略图、主题等本地数据。
- OpenAI-compatible 流式响应解析、reasoning delta 分离、stream snapshot 更新。
- 密钥引用、连接配置、权限记录、网络策略判断、诊断脱敏。
- SillyTavern 兼容格式导入导出。

宿主应用仍需实现：

- 页面、路由、组件、弹窗、文件选择器、媒体预览等 UI。
- 应用沙箱根目录，例如从 UIAbility 或页面上下文取得的 `filesDir`，用于创建 SDK 默认文件存储。
- 除内置 `OpenAIOhosProviderStreamSource` 覆盖的 OpenAI-compatible chat streaming 之外的 OpenRouter、Ollama、Whisper、TTS、Embedding 等真实 HTTP 请求。
- 平台权限申请、证书、代理、网络错误重试、后台任务调度。
- 设备端安装和 on-device 测试运行。

## 安装与引用

当前模块是 HAR 包，包名为 `tavern_ohos`，入口为 `Index.ets`。在同一 DevEco 工程内，宿主模块可以通过 `oh-package.json5` 引入本地模块。

```json5
{
  "dependencies": {
    "tavern_ohos": "file:../tavern_ohos"
  }
}
```

在 ArkTS 代码中从包入口导入：

```ts
import {
  EventBus,
  SandboxTavernFileStore,
  CharacterRuntime,
  ChatRuntime,
  MessageRuntime,
  PromptRuntime,
  StreamingRuntime,
  ProviderRuntime,
  type TavernFileStore,
} from 'tavern_ohos';
```

如果宿主模块使用源码相对路径开发，也可以按工程配置从 `../tavern_ohos/Index` 引入；发布或模块化接入时建议使用包名导入。

## 基础架构

SDK 由多个 Runtime 组成，没有单例总入口。推荐宿主应用创建一个应用级容器，统一持有共享依赖：

- `EventBus`：运行时事件总线。
- `TavernFileStore`：文件存储抽象。
- `rootPath`：数据根目录，例如 `tavern-data`。
- `userId`：当前用户 ID，例如 `default`。
- 业务 Runtime：按需创建并复用。

最小初始化示例：

```ts
import {
  EventBus,
  SandboxTavernFileStore,
  CharacterRuntime,
  ChatRuntime,
  MessageRuntime,
  PromptRuntime,
  type TavernFileStore,
  type RuntimeEvent,
  type MessageEventPayload,
} from 'tavern_ohos';

const events = new EventBus();
const files: TavernFileStore = new SandboxTavernFileStore(appFilesDir);
const rootPath = 'tavern-data';
const userId = 'default';

const characters = new CharacterRuntime(files, events, rootPath, userId);
const chats = new ChatRuntime(files, events, rootPath, userId);
const prompt = new PromptRuntime(events);

events.subscribe<MessageEventPayload>(
  'message.added',
  (event: RuntimeEvent<MessageEventPayload>) => {
    const message = event.payload.message;
    console.info(`消息已创建: ${message.id}`);
  },
);
```

`SandboxTavernFileStore` 是正式应用的默认落盘实现。它只需要宿主传入应用沙箱目录，写入文件时会按需创建父目录；不需要宿主预先知道 SDK 内部会用到哪些目录。`InMemoryFileStore` 只适合单元测试和临时会话。

## 存储适配

大部分本地数据 Runtime 都接收 `TavernFileStore`，并在 `rootPath/users/<userId>/...` 下组织数据。正式应用直接使用 `SandboxTavernFileStore`：

```ts
import { SandboxTavernFileStore, type TavernFileStore } from 'tavern_ohos';

const files: TavernFileStore = new SandboxTavernFileStore(appFilesDir);
await files.writeText('tavern-data/users/default/example.txt', 'hello', false);
const value = await files.readText('tavern-data/users/default/example.txt');
```

`SandboxTavernFileStore` 的行为：

- 所有 SDK 路径都会解析到构造函数传入的沙箱根目录下。
- 写入和追加文件前会自动创建父目录。
- 不会在初始化时创建全套 Tavern 目录，只在具体功能写入时按需创建。
- 遇到 `..` 路径会抛错，避免逃逸应用数据目录。
- `createBackup` 为 `true` 时，会在覆盖前创建同路径 `.bak` 文件。

自定义 `TavernFileStore` 只适合加密存储、云同步、测试替身或特殊迁移工具。自定义实现需要保证：

- 路径分隔符统一处理为 `/`。
- 阻止 `..` 或绝对路径逃逸应用数据根目录。
- `writeText()` 和 `appendText()` 写入前能按需创建父目录。
- `list()` 返回直接子节点名称。
- 二进制资源目前通常以字符串或 ArrayBuffer 形式由具体 Runtime 处理，宿主可按模块需求封装。

## 事件总线

所有 Runtime 通过 `EventBus` 发布事件。事件名采用字符串，例如 `chat.created`、`message.added`、`stream.delta`、`generation.completed`。订阅返回 `EventSubscription`，不用时应调用 `unsubscribe()`。

```ts
import {
  EventBus,
  type RuntimeEvent,
  type StreamDeltaPayload,
} from 'tavern_ohos';

const events = new EventBus();

const subscription = events.subscribe<StreamDeltaPayload>(
  'stream.delta',
  (event: RuntimeEvent<StreamDeltaPayload>) => {
    console.info(event.payload.snapshot);
  },
);

subscription.unsubscribe();
```

事件 payload 会按 Runtime 内部策略做拷贝，宿主不应通过修改事件对象反向修改内部状态。

## 角色与聊天

角色、聊天和消息是最常见的组合。`CharacterRuntime` 管角色元数据，`ChatRuntime` 管聊天记录索引，`MessageRuntime` 管某个聊天内的消息 JSONL。

```ts
import {
  CharacterRuntime,
  ChatRuntime,
  MessageRuntime,
  EventBus,
  InMemoryFileStore,
  type TavernFileStore,
} from 'tavern_ohos';

const events = new EventBus();
const files: TavernFileStore = new InMemoryFileStore();
const rootPath = 'tavern-data';
const userId = 'default';

const characters = new CharacterRuntime(files, events, rootPath, userId);
const chats = new ChatRuntime(files, events, rootPath, userId);

const character = await characters.createCharacter({
  name: 'Alice',
  description: '一名友好的助手。',
  personality: '温和、清晰、可靠。',
  scenario: '和用户进行日常对话。',
  firstMessage: '你好，我是 Alice。',
  exampleDialogue: '',
  tags: ['assistant'],
});

const chat = await chats.createChat({
  title: '和 Alice 的对话',
  characterId: character.id,
  personaId: 'persona-default',
});

const messages = new MessageRuntime(files, events, rootPath, userId, chat.id);
await messages.addMessage({
  role: 'user',
  name: 'User',
  text: '你好',
});
await messages.addMessage({
  role: 'assistant',
  name: character.name,
  text: character.firstMessage,
});
```

常用能力：

- `ChatRuntime.createChat()` 创建聊天。
- `ChatRuntime.exportChatJsonl()` 导出 SillyTavern 风格 JSONL。
- `ChatRuntime.importChatJsonl()` 导入 JSONL，导入前会先解析，避免畸形 JSONL 留下半创建聊天。
- `MessageRuntime.addMessage()` 创建消息。
- `MessageRuntime.updateMessage()` 更新消息。
- `MessageRuntime.deleteMessage()` 删除消息。

## 聊天和消息保存、读取和导入导出

`ChatRuntime` 管聊天会话元数据，`MessageRuntime` 管单个聊天内的消息。默认路径结构是：

```text
<rootPath>/users/<userId>/chats/index.json
<rootPath>/users/<userId>/chats/<chatId>/chat.json
<rootPath>/users/<userId>/chats/<chatId>/messages.jsonl
```

`chat.json` 保存标题、角色 ID、用户人格 ID、归档状态和下一条消息 ID。`messages.jsonl` 保存消息列表，便于按 SillyTavern JSONL 格式导入导出。

### 创建、读取、搜索和管理聊天

```ts
const chat = await chats.createChat({
  title: '和 Alice 的对话',
  characterId: 'char-1',
  personaId: 'persona-default',
});

const allChats = await chats.listChats();
const matchedChats = await chats.searchChats('Alice');
const loadedChat = await chats.getChat(chat.id);
const renamedChat = await chats.renameChat(loadedChat.id, '新的聊天标题');
const archivedChat = await chats.archiveChat(renamedChat.id, true);
const copiedChat = await chats.duplicateChat(archivedChat.id, '聊天副本');

await chats.deleteChat(copiedChat.id);
```

注意：

- `listChats()` 会刷新每个聊天的消息数量和预览文本，因此会读取对应消息文件。
- `searchChats()` 只匹配标题和预览文本，不做全文消息搜索。
- `archiveChat()` 只修改归档标记，不删除消息。
- `duplicateChat()` 会复制消息 JSONL。

### 添加、读取、更新和删除消息

可以通过 `new MessageRuntime(...)` 创建消息运行时，也可以使用 `chats.messages(chatId)` 获取。

```ts
const messages = chats.messages(chat.id);

const userMessage = await messages.addMessage({
  role: 'user',
  name: 'User',
  text: '你好',
});

const assistantMessage = await messages.addMessage({
  role: 'assistant',
  name: 'Alice',
  text: '你好，有什么可以帮你？',
});

const page = await messages.listMessagesPage(0, 20);
const loadedMessage = await messages.getMessage(userMessage.id);

await messages.updateMessage(assistantMessage.id, {
  text: '你好，我在。',
  isSystem: false,
});

await messages.moveMessage(assistantMessage.id, 0);
await messages.hideMessage(userMessage.id, true);
await messages.setMessageRating(assistantMessage.id, 5);
await messages.setMessageBookmark(assistantMessage.id, true);
await messages.deleteMessages([userMessage.id, assistantMessage.id]);
```

消息字段要点：

- `role` 通常为 `user`、`assistant` 或 `system`。
- `text` 是正文；导出到 SillyTavern JSONL 时会映射成 `mes`。
- `isSystem` 为 `true` 的消息在 `PromptRuntime` 当前实现中会跳过聊天历史拼装。
- `swipes`、`activeSwipeIndex`、`extraJson` 会保存在消息记录中；评分和书签写入 `extraJson`。

### 导入和导出聊天 JSONL

`ChatRuntime.exportChatJsonl()` 会导出头部 metadata 行和消息行。`importChatJsonl()` 会先解析 JSONL，再创建聊天并写入消息。

```ts
const exportedJsonl = await chats.exportChatJsonl(chat.id);

const importedChat = await chats.importChatJsonl(
  exportedJsonl,
  '导入的聊天',
  'char-1',
  'persona-default',
);
```

导入注意事项：

- header 行不创建消息；包含 `name` 字段的行才会转为消息。
- `is_user` / `is_system` 会映射为 `role`、`isUser`、`isSystem`。
- `send_date` 缺失时会使用当前时间。
- `swipes` 会保留；`extra` 会转成内部 `extraJson`。
- 导入畸形 JSONL 会抛错，宿主应在 UI 中提示用户并避免覆盖旧聊天。

## 角色卡保存、读取和导入导出

`CharacterRuntime` 是角色卡主入口。它负责把角色记录保存到 `TavernFileStore`，默认路径结构是：

```text
<rootPath>/users/<userId>/characters/index.json
<rootPath>/users/<userId>/characters/<characterId>/character.json
<rootPath>/users/<userId>/characters/<characterId>/avatar.png
```

`index.json` 保存列表页需要的轻量索引，`character.json` 保存完整 `CharacterRecord`。`avatar.png` 是角色头像约定路径，头像内容本身由 `AvatarRuntime` 写入。

### 保存新角色卡

创建本地角色时调用 `createCharacter()`。它会分配 `char-<nextId>`，写入角色 JSON，更新角色索引，并发布 `character.created` 事件。

```ts
import {
  CharacterRuntime,
  EventBus,
  InMemoryFileStore,
  type TavernFileStore,
} from 'tavern_ohos';

const files: TavernFileStore = new InMemoryFileStore();
const events = new EventBus();
const characters = new CharacterRuntime(files, events, 'tavern-data', 'default');

const alice = await characters.createCharacter({
  name: 'Alice',
  description: '一名友好的助手。',
  personality: '温和、清晰、可靠。',
  scenario: '和用户进行日常对话。',
  firstMessage: '你好，我是 Alice。',
  exampleDialogue: '<START>\nUser: 你好\nAlice: 你好。',
  tags: ['assistant', 'daily'],
  favorite: true,
  talkativeness: 0.5,
  world: 'main-world',
});

console.info(alice.id);
```

创建后的 `CharacterRecord` 会包含更多字段，例如 `creatorNotes`、`systemPrompt`、`postHistoryInstructions`、`alternateGreetings`、`sourceFormat`、`sourceJson` 等。当前 `createCharacter()` 只接收基础字段；需要保留完整 SillyTavern V2 原始字段时，优先用 `importCharacterJson()`。

### 读取、列表、更新、复制和删除

常见角色管理操作如下：

```ts
const list = await characters.listCharacters();
for (let index = 0; index < list.length; index += 1) {
  console.info(`${list[index].id}: ${list[index].name}`);
}

const loaded = await characters.getCharacter(alice.id);

const updated = await characters.updateCharacter(loaded.id, {
  name: loaded.name,
  description: `${loaded.description}\n补充说明。`,
  personality: loaded.personality,
  scenario: loaded.scenario,
  firstMessage: loaded.firstMessage,
  exampleDialogue: loaded.exampleDialogue,
  tags: loaded.tags.concat(['updated']),
  favorite: loaded.favorite,
});

const copied = await characters.duplicateCharacter(updated.id, `${updated.name} 副本`);

await characters.deleteCharacter(copied.id);
```

注意：

- `listCharacters()` 返回的是 `CharacterIndexEntry[]`，只适合列表展示。
- `getCharacter()` 才会读取完整 `CharacterRecord`。
- `updateCharacter()` 会清空 `sourceJson`，因为角色已不再完全等同于原始导入文件。
- `deleteCharacter()` 会递归删除该角色目录，包括头像、表情图等同目录资源。

### 导入 SillyTavern V2 JSON 角色卡

`importCharacterJson()` 直接接收 SillyTavern `chara_card_v2` JSON 字符串。它会读取 `data.name`、`data.description`、`data.personality`、`data.scenario`、`data.first_mes`、`data.mes_example`、`data.tags`、`data.alternate_greetings` 和 `data.extensions`。

```ts
const cardJson = JSON.stringify({
  spec: 'chara_card_v2',
  spec_version: '2.0',
  data: {
    name: 'Bob',
    description: 'Imported character',
    personality: 'Kind',
    scenario: 'Workshop',
    first_mes: 'Hi',
    mes_example: '<START>',
    creator_notes: '导入说明',
    system_prompt: '保持角色设定。',
    post_history_instructions: '',
    creator: 'unknown',
    character_version: '1.0.0',
    tags: ['imported'],
    alternate_greetings: ['Hello'],
    extensions: {
      fav: true,
      talkativeness: 0.8,
      world: 'test-world',
    },
  },
});

const imported = await characters.importCharacterJson(cardJson);
const sameJson = await characters.exportCharacterJson(imported.id);
```

如果导入后没有修改角色，`exportCharacterJson()` 会优先返回原始 `sourceJson`，这样可以保留 SDK 暂时不理解的供应商扩展字段。角色被 `updateCharacter()` 修改后，`exportCharacterJson()` 会用当前 `CharacterRecord` 重新生成标准 V2 JSON。

### 导入 V1、charx 和 PNG metadata 角色卡

`CharacterRuntime.importCharacterJson()` 只直接保存 V2 JSON。V1、charx 和带 metadata 的 PNG 需要先用 `CharacterCodecRuntime` 解析，再导出为 V2 JSON 后保存。

```ts
import {
  CharacterCodecRuntime,
  CharacterRuntime,
  EventBus,
  InMemoryFileStore,
  type CharacterCodecResult,
  type TavernFileStore,
} from 'tavern_ohos';

const files: TavernFileStore = new InMemoryFileStore();
const events = new EventBus();
const characters = new CharacterRuntime(files, events, 'tavern-data', 'default');
const codec = new CharacterCodecRuntime();

const parsed: CharacterCodecResult = codec.parseCharacterJson(cardJson);
const normalizedV2Json = codec.exportToV2(parsed);
const saved = await characters.importCharacterJson(normalizedV2Json);
```

PNG 角色卡的流程如下：

```ts
const parsedFromPng = codec.parsePngCharacterCard(pngArrayBuffer);
const pngV2Json = codec.exportToV2(parsedFromPng);
const savedFromPng = await characters.importCharacterJson(pngV2Json);
```

导出 PNG metadata 角色卡时，需要提供一份有效 PNG 作为载体：

```ts
const exportedJson = await characters.exportCharacterJson(savedFromPng.id);
const parsedForExport = codec.parseCharacterJson(exportedJson);
const pngWithCard = codec.exportToPng(parsedForExport, sourcePngArrayBuffer);
```

当前支持状态：

- V2 JSON：`CharacterRuntime.importCharacterJson()` 可直接保存。
- V1 JSON：`CharacterCodecRuntime.parseCharacterJson()` 可解析，再转 V2 保存。
- charx：`CharacterCodecRuntime.parseCharacterJson()` 可读取归档中的第一个角色，再转 V2 保存。
- PNG metadata：`CharacterCodecRuntime.parsePngCharacterCard()` 可解析，`exportToPng()` 可写入。
- WebP metadata：当前 `ImageMetadataRuntime` 能识别 WebP 格式，但不支持写入 WebP 角色卡 metadata。

### 保存和读取角色头像

角色记录中的 `avatarPath` 只是约定路径。头像内容通过 `AvatarRuntime` 单独保存和读取。

```ts
import {
  AvatarRuntime,
  EventBus,
  InMemoryFileStore,
  type AvatarCrop,
  type TavernFileStore,
} from 'tavern_ohos';

const files: TavernFileStore = new InMemoryFileStore();
const events = new EventBus();
const avatars = new AvatarRuntime(files, events);

const crop: AvatarCrop = {
  x: 0,
  y: 0,
  width: 0,
  height: 0,
};
const avatarSourceContent = 'png-data';

const avatar = await avatars.uploadAvatar(
  'character',
  alice.id,
  'avatar.png',
  'image/png',
  avatarSourceContent,
  crop,
);

const avatarRecord = await avatars.getAvatar('character', alice.id);
const loadedAvatarContent = await avatars.readAvatarContent('character', alice.id);
```

`AvatarRuntime` 当前使用 `tavern-data/users/default/...` 固定路径；如果宿主应用使用了不同 `rootPath` 或 `userId`，需要在宿主侧统一约定，或后续把 `AvatarRuntime` 改造成可注入根路径和用户 ID。

## Prompt 拼装

`PromptRuntime` 负责把系统段、角色段、世界书段、历史消息、作者注释、插件注入等内容拼成 prompt sections。它不直接请求模型。

```ts
import {
  EventBus,
  PromptRuntime,
  type CharacterRecord,
  type ChatMessage,
  type WorldInfoActivation,
} from 'tavern_ohos';

const prompt = new PromptRuntime(new EventBus());

const character: CharacterRecord = {
  schemaVersion: 1,
  id: 'character-1',
  name: 'Alice',
  description: 'Alice 是一名友好的助手。',
  personality: '温和、清晰、可靠。',
  scenario: '和用户进行日常对话。',
  firstMessage: '你好，我是 Alice。',
  exampleDialogue: '',
  creatorNotes: '',
  systemPrompt: '',
  postHistoryInstructions: '',
  creator: '',
  characterVersion: '',
  avatarPath: '',
  tags: ['assistant'],
  alternateGreetings: [],
  favorite: false,
  talkativeness: 0.5,
  world: '',
  sourceFormat: 'native',
  sourceJson: '',
  createdAt: Date.now(),
  updatedAt: Date.now(),
};

const messages: Array<ChatMessage> = [
  {
    schemaVersion: 1,
    id: 'msg-1',
    index: 0,
    name: 'User',
    role: 'user',
    isUser: true,
    isSystem: false,
    sendDate: new Date().toISOString(),
    text: '你好',
    swipes: [],
    activeSwipeIndex: 0,
    extraJson: '',
  },
  {
    schemaVersion: 1,
    id: 'msg-2',
    index: 1,
    name: 'Alice',
    role: 'assistant',
    isUser: false,
    isSystem: false,
    sendDate: new Date().toISOString(),
    text: '你好，有什么可以帮你？',
    swipes: [],
    activeSwipeIndex: 0,
    extraJson: '',
  },
];

const worldInfo: WorldInfoActivation = {
  entries: [],
  matches: [],
  promptText: '当前场景：图书馆。',
};

const result = prompt.buildPrompt({
  id: 'prompt-1',
  systemPrompt: '你是一个可靠的助手。',
  personaName: 'User',
  personaDescription: '用户喜欢简洁回答。',
  authorNote: '',
  character: character,
  messages: messages,
  worldInfo: worldInfo,
  maxEstimatedTokens: 4096,
});

const promptText = result.finalText;
```

实际项目通常会在构建 prompt 前先调用：

- `WorldInfoRuntime.activateEntries()`：根据消息文本激活世界书条目。
- `AuthorNoteRuntime.buildAuthorNote()`：生成作者注释段。
- `RegexRuntime.applyScripts()`：按脚本处理文本。
- `PromptTemplateRuntime` / `InstructRuntime`：套用模板和 instruct 格式。
- `TokenizerRuntime`：估算 token，并按预算裁剪消息。

## 世界书保存、读取和激活

`WorldInfoRuntime` 用来管理 SillyTavern worldbook 和 entry，并根据消息缓冲区激活条目。默认路径结构是：

```text
<rootPath>/users/<userId>/worldbooks/index.json
<rootPath>/users/<userId>/worldbooks/<worldBookId>.json
```

`index.json` 保存世界书列表和条目数量，单个 `<worldBookId>.json` 保存完整 `WorldBook` 和所有 `WorldInfoEntry`。

### 创建世界书和条目

```ts
import {
  EventBus,
  InMemoryFileStore,
  WorldInfoRuntime,
  type TavernFileStore,
} from 'tavern_ohos';

const files: TavernFileStore = new InMemoryFileStore();
const worldInfo = new WorldInfoRuntime(files, new EventBus(), 'tavern-data', 'default');

const book = await worldInfo.createWorldBook('设定集');
const dragonEntry = await worldInfo.createEntry(book.id, {
  comment: '龙',
  keys: ['dragon', '龙'],
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

字段含义：

- `comment`：条目备注，通常用于管理界面展示。
- `keys`：主关键词。消息缓冲区命中任一主关键词时，条目可被激活。
- `secondaryKeys`：二级关键词。`selective` 为 `true` 时，主关键词和二级关键词都命中才激活。
- `content`：注入 prompt 的正文。
- `constant`：恒定条目，不需要关键词命中。
- `selective`：是否启用二级关键词判断。
- `enabled`：是否参与激活。
- `insertionOrder`：插入排序，越小越靠前。
- `position`：位置标记，当前 Runtime 保存该字段；实际插入 Prompt 时由宿主或 Prompt 流程决定如何分段。
- `caseSensitive`：关键词匹配是否区分大小写。

### 列表、读取、更新和删除

```ts
const worldBooks = await worldInfo.listWorldBooks();
for (let index = 0; index < worldBooks.length; index += 1) {
  console.info(`${worldBooks[index].id}: ${worldBooks[index].name}`);
}

const loadedBook = await worldInfo.getWorldBook(book.id);

const updatedEntry = await worldInfo.updateEntry(book.id, dragonEntry.id, {
  comment: '龙族',
  keys: ['dragon', '龙', '龙族'],
  secondaryKeys: ['北方山脉'],
  content: '龙族生活在北方山脉，通常守护古老遗迹。',
  constant: false,
  selective: true,
  enabled: true,
  insertionOrder: 20,
  position: 'before',
  caseSensitive: false,
});

await worldInfo.deleteEntry(book.id, updatedEntry.id);
await worldInfo.deleteWorldBook(book.id);
```

注意：

- `listWorldBooks()` 返回 `WorldBookIndexEntry[]`，只适合列表展示。
- `getWorldBook()` 返回完整 `WorldBook`，包含 `entries`。
- `deleteWorldBook()` 删除的是单个世界书 JSON，并从索引移除。
- `deleteEntry()` 会更新世界书文件和索引里的 `entryCount`。

### 导入和导出世界书 JSON

`exportWorldBookJson()` 导出的是 SDK 当前 `WorldBook` 结构。`importWorldBookJson()` 会重新分配新的 `worldbook-<nextId>`，并根据导入条目修正 `nextEntryId`。

```ts
const exportedWorldBookJson = await worldInfo.exportWorldBookJson(loadedBook.id);
const importedWorldBook = await worldInfo.importWorldBookJson(exportedWorldBookJson, '导入的设定集');
```

导入外部 JSON 时建议先校验：

- `entries` 是否为数组。
- 每个 entry 是否具备 `keys`、`secondaryKeys`、`content`、`enabled` 等字段。
- `uid` 和 `id` 是否可能重复。
- 用户可见名称是否需要重命名，避免覆盖已有世界书的语义。

### 激活世界书条目

普通激活会把所有目标世界书的可用条目放入候选列表，按 `insertionOrder` 排序后返回。

```ts
const activeBook = await worldInfo.createWorldBook('战役设定');
await worldInfo.createEntry(activeBook.id, {
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

const activation = await worldInfo.activateEntries([activeBook.id], ['我看到了一条龙。']);
console.info(activation.promptText);
```

`activateEntries()` 返回的 `entries` 和 `matches` 已按插入顺序对齐，可用于调试命中来源。

返回值说明：

- `entries`：被激活的完整条目。
- `matches`：每个条目的命中信息，包含 `worldBookId`、`entryId`、`key`。
- `promptText`：按顺序拼接后的条目正文，可传给 `PromptRuntime.buildPrompt()` 的 `worldInfo.promptText`。

递归激活会把第一轮激活出来的条目正文加入下一轮扫描，适合“条目 A 提到条目 B 的关键词”的场景：

```ts
const recursive = await worldInfo.activateEntriesRecursive(
  [activeBook.id],
  ['我看到了一条龙。'],
  2,
  2048,
);
```

`maxDepth` 控制递归轮数，`maxTokens` 当前按粗略字符预算截断 `promptText`，不是精确 tokenizer 预算。需要严格 token 控制时，应把结果交给 `TokenizerRuntime` 或宿主侧 tokenizer 再裁剪。

## 常用数据 Runtime 速查

除角色、聊天和世界书外，SDK 里还有多组可持久化或可导入导出的 Runtime。常用入口如下，具体参数类型都从 `tavern_ohos` 包入口导出。

| 数据域 | Runtime | 新建或保存 | 读取或列表 | 更新 | 删除 | 导入导出 |
|---|---|---|---|---|---|---|
| 用户人格 | `PersonaRuntime` | `loadFromStore()`、`createPersona()`、`selectPersona()`、`bindPersona()`、`saveToStore()` | `getPersona()`、`listPersonas()`、`getSelectedPersona()`、`getBoundPersona()`、`buildPromptData()` | `updatePersona()` | `deletePersona()` | `exportPersona()`、`importPersona()` |
| 生成预设 | `PresetRuntime` | `loadFromStore()`、`createPreset()`、`bindPreset()`、`saveToStore()` | `getPreset()`、`listPresets()`、`getBinding()`、`listBindings()` | `updatePreset()`、`migratePreset()` | `deletePreset()` | `exportPreset()`、`importPreset()` |
| 快捷回复 | `QuickReplyRuntime` | `loadFromStore()`、`createSet()`、`addItem()`、`saveToStore()` | `getSet()`、`listSets()`、`listButtons()` | `addItem()` 覆盖同 ID 项、`setItemVisible()` | `deleteSet()`、`removeItem()` | `exportSet()`、`importSet()` |
| Data Bank | `DataBankRuntime` | `createDocument()` | `getDocument()`、`readDocumentContent()`、`listDocuments()`、`listByScope()`、`listByTag()` | `setDocumentEnabled()`、`updateMetadata()` | `deleteDocument()` | `exportData()`、`importData()` |
| 向量库 | `VectorRuntime` | `createCollection()`、`upsertVector()` | `listVectors()`、`query()` | `upsertVector()` | `deleteByDocument()`、`deleteByScope()` | 当前以集合目录和 JSONL 持久化，没有独立 `exportData()` |
| 头像 | `AvatarRuntime` | `uploadAvatar()` | `getAvatar()`、`readAvatarContent()`、`listByTargetType()` | 再次 `uploadAvatar()` 覆盖同一目标 | `deleteAvatar()` | 当前没有独立 `exportData()` |
| 资源文件 | `AssetRuntime` | `importAsset()` | `readAssetContent()`、`listAssets()`、`listByType()` | `renameAsset()` | `deleteAsset()` | 当前没有独立 `exportData()` |
| 上传文件 | `FileRuntime` | `uploadFile()` | `readFileContent()`、`listFiles()` | 当前没有通用更新方法 | `deleteFile()` | 当前没有独立 `exportData()` |
| 表情图 | `SpriteRuntime` | `uploadSprite()`、`importRisuSprites()`、`setExpression()` | `listSprites()`、`getExpression()` | 再次 `uploadSprite()` 覆盖同一表情 | `deleteSprite()` | 当前没有独立 `exportData()` |
| 主题 | `ThemeRuntime` | `saveTheme()`、`activateTheme()`、`setActiveBackground()` | `listThemes()`、`getActiveThemeName()`、`getActiveBackground()` | 再次 `saveTheme()` 覆盖同名主题 | `deleteTheme()` | `exportThemes()`、`importThemes()` |
| 设置 | `SettingsRuntime` | `loadFromStore()`、`registerSchema()`、`setSetting()`、`saveToStore()` | `getSetting()`、`getEffectiveSetting()`、`listSchemas()`、`listEntries()`、`snapshot()` | `setSetting()`、`migrateSetting()` | 当前没有通用删除方法 | `snapshot()` 可作为导出快照 |
| 密钥 | `SecretRuntime` | `loadFromStore()`、`createSecret()`、`rotateSecret()`、`saveToStore()` | `readSecret()`、`readActiveSecret()`、`listSecretStates()` | `updateSecret()` | `deleteSecret()` | `exportIndex()` 只导出脱敏索引，不导出明文 |
| 连接配置 | `ConnectionProfileRuntime` | `loadFromStore()`、`createProfile()`、`setActiveProfile()`、`saveToStore()` | `getProfile()`、`listProfiles()`、`resolveActiveProfile()`、`toProviderRequest()` | `updateProfile()` | `deleteProfile()` | 当前没有独立 `exportData()` |

使用这些 Runtime 时要注意两类差异：

- 文件型 Runtime 会在每个公开写入方法里直接落盘，例如 `DataBankRuntime`、`VectorRuntime`、`AssetRuntime`、`FileRuntime`、`SpriteRuntime`、`ThemeRuntime`。
- 配置型 Runtime 保留同步 CRUD API，跨启动保存使用显式 `loadFromStore()` / `saveToStore()`。已支持该模式的模块包括 `GroupRuntime`、`PersonaRuntime`、`PresetRuntime`、`QuickReplyRuntime`、`SettingsRuntime`、`SecretRuntime`、`ConnectionProfileRuntime`。宿主只需要传入 `TavernFileStore`，不需要了解内部目录结构。

配置型 Runtime 的通用步骤：

1. 用 `SandboxTavernFileStore(context.filesDir)` 或自定义加密存储创建文件存储。
2. 构造 Runtime 时传入 `events, files, 'tavern-data', 'default'`。
3. 应用启动或切换用户后先调用 `await runtime.loadFromStore()`。
4. 调用 `create...()`、`update...()`、`delete...()` 等同步 API 修改内存态。
5. 在修改完成、页面退后台或应用退出前调用 `await runtime.saveToStore()`。

## 连接配置、密钥与请求头

连接配置由 `ConnectionProfileRuntime` 管理，密钥由 `SecretRuntime` 管理，请求头由 `NetworkService` 解析。`secretRef` 是密钥引用，不建议把真实 API key 放进普通设置或日志。

```ts
import {
  ConnectionProfileRuntime,
  EventBus,
  NetworkService,
  SandboxTavernFileStore,
  SecretRuntime,
} from 'tavern_ohos';

const events = new EventBus();
const files = new SandboxTavernFileStore(context.filesDir);
const connections = new ConnectionProfileRuntime(events, files, 'tavern-data', 'default');
const secrets = new SecretRuntime(events, files, 'tavern-data', 'default');
const network = new NetworkService(connections, secrets);

await secrets.loadFromStore();
await connections.loadFromStore();

const secret = secrets.createSecret({
  id: 'openai-secret',
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
  additionalHeaders: [],
  enabled: true,
});

const requestProfile = connections.toProviderRequest('profile-openai');
const headers = network.resolveHeadersForProfile('profile-openai');
```

注意：`OpenAIOhosProviderStreamSource` 使用 `apiKey` 自动生成 `Authorization: Bearer <key>`。如果宿主改用自定义 `ProviderStreamSource`，则仍需在 `additionalHeaders` 或宿主网络层自行处理鉴权请求头。

## OpenAI-compatible 文本请求

`ProviderRuntime.buildTextCompletionRequest()` 用于构造 completion 请求对象。它不会发 HTTP。

```ts
import {
  EventBus,
  ProviderRuntime,
  StreamingRuntime,
  type ProviderTextCompletionRequest,
} from 'tavern_ohos';

const provider = new ProviderRuntime(new EventBus(), new StreamingRuntime(new EventBus()));

const request: ProviderTextCompletionRequest = provider.buildTextCompletionRequest({
  apiType: 'openai',
  model: 'gpt-4o-mini',
  prompt: 'User: 你好\nAssistant:',
  temperature: 0.7,
  maxTokens: 256,
  stop: ['User:', 'Assistant:'],
  stream: false,
  topP: 0.9,
});

// 宿主网络层可用 request.path 和 request.body 发起 HTTP POST。
// URL 通常是 `${serverUrl}${request.path}`。
```

不同 `apiType` 会影响 path：

| `apiType` | path |
|---|---|
| `openai` / `generic` 默认 | `/v1/completions` |
| `openrouter` | `/v1/chat/completions` |
| `dreamgen` | `/api/openai/v1/completions` |
| `mancer` | `/oai/v1/completions` |
| `llamacpp` | `/completion` |
| `ollama` | `/api/generate` |

## OpenAI-compatible 流式响应接入

OpenAI-compatible chat streaming 推荐直接使用内置 `OpenAIOhosProviderStreamSource`。它会调用 `openai_ohos` 的 `OpenAIRequestClient.streamPost('/chat/completions', ...)`，自动拼接 `baseURL`、`Authorization`、默认 headers、超时和 SSE 解析，再把事件转给 `ProviderRuntime` 更新 `StreamingRuntime`。

```ts
import {
  EventBus,
  OpenAIOhosProviderStreamSource,
  ProviderRuntime,
  StreamingRuntime,
} from 'tavern_ohos';

const events = new EventBus();
const streaming = new StreamingRuntime(events);
const provider = new ProviderRuntime(events, streaming);
const source = new OpenAIOhosProviderStreamSource({
  apiKey: 'sk-...',
  baseURL: 'https://api.openai.com/v1',
  defaultHeaders: {
    'OpenAI-Project': 'proj_...',
  },
});

const task = await provider.startOpenAICompatibleStream({
  taskId: 'generation-1',
  chatId: 'chat-1',
  messageId: 'message-1',
  request: {
    provider: 'openai-compatible',
    model: 'gpt-4o-mini',
    messages: [
      { role: 'user', content: '你好' },
    ],
    temperature: 0.7,
    maxTokens: 256,
    stop: [],
    stream: true,
  },
  source: source,
});

console.info(task.status);
```

接入步骤：

1. 创建 `EventBus` 和 `StreamingRuntime`。
2. 创建 `ProviderRuntime`。
3. 用 API key、`baseURL` 和可选 headers 创建 `OpenAIOhosProviderStreamSource`。
4. 创建待写回的 assistant 消息，并让 `StreamingRuntime.attachMessageRuntime(messages)` 绑定消息运行时。
5. 调用 `startOpenAICompatibleStream()`，把 `source` 传入。
6. 需要取消时调用 `abortProviderStream(taskId, reason)`，运行时会关闭 `openai_ohos` 返回的 stream handle。

SSE 数据应是 OpenAI-compatible 格式，例如：

```text
data: {"choices":[{"delta":{"content":"你"}}]}

data: {"choices":[{"delta":{"content":"好"}}]}

data: [DONE]
```

`ProviderRuntime` 会自动：

- 解析 SSE event。
- 识别 `[DONE]`。
- 从 `choices[].delta.content` 提取可见文本。
- 从 `reasoning_content` / `reasoning` 提取推理文本。
- 写入 `StreamingRuntime` 的 `snapshot` / `reasoningSnapshot`。
- 发布 `generation.started`、`stream.delta`、`generation.completed` 或 `generation.failed` 事件。

如果项目需要自定义代理、非 OpenAI SSE 协议、WebSocket、离线模型或测试替身，仍可实现 `ProviderStreamSource`：

```ts
import {
  type ProviderStreamHandle,
  type ProviderStreamRequest,
  type ProviderStreamSink,
  type ProviderStreamSource,
} from 'tavern_ohos';

class HttpSseSource implements ProviderStreamSource {
  async start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle> {
    // 这里由宿主接入自定义网络层。
    // 每收到一段 OpenAI-compatible SSE 原文后调用 await sink.onChunk(chunk)。
    // 请求完成时调用 await sink.onDone()。
    // 请求失败时调用 await sink.onError(message)。
    return {
      close(): void {
        // 这里关闭宿主网络请求。
      },
    };
  }
}
```

## 将流式结果写回消息

`StreamingRuntime` 可以挂接 `MessageRuntime`。挂接后，每次普通文本 delta 都会把当前 snapshot 写入对应消息；reasoning delta 只更新 `reasoningSnapshot`，不会写进消息正文。

```ts
import {
  ChatRuntime,
  EventBus,
  InMemoryFileStore,
  MessageRuntime,
  StreamingRuntime,
  type TavernFileStore,
} from 'tavern_ohos';

const events = new EventBus();
const files: TavernFileStore = new InMemoryFileStore();
const chats = new ChatRuntime(files, events, 'tavern-data', 'default');

const chat = await chats.createChat({
  title: '流式对话',
  characterId: 'character-1',
  personaId: 'persona-default',
});

const messages = new MessageRuntime(files, events, 'tavern-data', 'default', chat.id);
const assistant = await messages.addMessage({
  role: 'assistant',
  name: 'Assistant',
  text: '',
});

const streaming = new StreamingRuntime(events);
streaming.attachMessageRuntime(messages);

const session = streaming.startStream({
  taskId: 'generation-1',
  chatId: chat.id,
  messageId: assistant.id,
});

await streaming.applyDelta(session.id, '你好', false);
streaming.completeStream(session.id);
```

## Embedding、图片、Whisper 和 TTS 请求体

这些 Runtime 当前也只负责构造请求体和管理任务状态，不直接发送网络请求。

```ts
import {
  ASRRuntime,
  EmbeddingRuntime,
  EventBus,
  ImageGenerationRuntime,
  TTSRuntime,
} from 'tavern_ohos';

const events = new EventBus();

const embedding = new EmbeddingRuntime(events);
const embeddingBody = embedding.buildOpenAIRequest('text-embedding-3-small', ['hello']);

const image = new ImageGenerationRuntime(events);
const imageBody = image.buildOpenAIImageRequest('画一只猫', 'dall-e-3', 1, '1024x1024');

const asr = new ASRRuntime(events);
const whisperBody = asr.buildWhisperRequest('audio.mp3', 'whisper-1', 'zh', '转录提示');

const tts = new TTSRuntime(events);
const ttsBody = tts.buildOpenAITTSRequest('你好', 'nova', 'tts-1', 1.0, 'mp3');
```

宿主网络层应按目标 provider 的 endpoint 自行发起请求，并把响应结果写回对应 Runtime，例如保存 embedding 结果、完成 TTS task、写入图片文件或更新消息。

## Data Bank、向量和 RAG

`DataBankRuntime` 管理文档，`VectorRuntime` 管理向量集合，`RagRuntime` 执行检索和 prompt 注入。Embedding 向量本身通常来自宿主网络层请求 OpenAI / Ollama / Cohere 等 provider 后写入。

```ts
import {
  DataBankRuntime,
  EventBus,
  InMemoryFileStore,
  RagRuntime,
  VectorRuntime,
  type TavernFileStore,
} from 'tavern_ohos';

const events = new EventBus();
const files: TavernFileStore = new InMemoryFileStore();

const dataBank = new DataBankRuntime(files, events);
const vectors = new VectorRuntime(files, events);
const rag = new RagRuntime(vectors, events);

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
  metadataJson: '{"source":"databank"}',
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

await secrets.saveToStore();
await connections.saveToStore();
```

`SecretRuntime.saveToStore()` 会把密钥明文交给传入的 `TavernFileStore`。生产环境建议传入加密存储或系统安全存储适配器；如果直接使用 `SandboxTavernFileStore`，请把应用沙箱备份和日志策略纳入安全设计。

## 导入导出与备份

多个 Runtime 提供专门的 JSON、JSONL、单项导入导出或快照方法。推荐宿主应用做迁移、备份、用户数据导入时按模块分别导出，再组合成应用级归档。

常见入口：

- `ChatRuntime.exportChatJsonl()` / `ChatRuntime.importChatJsonl()`
- `WorldInfoRuntime.exportWorldBookJson()` / `WorldInfoRuntime.importWorldBookJson()`
- `CharacterRuntime.exportCharacterJson()` / `CharacterRuntime.importCharacterJson()`
- `PersonaRuntime.exportPersona()` / `PersonaRuntime.importPersona()`
- `PresetRuntime.exportPreset()` / `PresetRuntime.importPreset()`
- `QuickReplyRuntime.exportSet()` / `QuickReplyRuntime.importSet()`
- `DataBankRuntime.exportData()` / `DataBankRuntime.importData()`
- `ThemeRuntime.exportThemes()` / `ThemeRuntime.importThemes()`
- `SettingsRuntime.snapshot()`
- `SecretRuntime.exportIndex()`，只导出脱敏索引
- `BackupRuntime`、`MigrationRuntime`、`RecoveryRuntime`

导入前建议：

- 先校验 schema 和版本。
- 对用户可控路径使用 SDK 的安全路径逻辑或宿主侧白名单。
- 对 replace 导入先备份旧数据。
- 对密钥只迁移 `secretRef` 或加密后的安全存储，不导出明文。

## 权限、网络策略与诊断

`PermissionRuntime` 用于记录 subject 对资源的授权，例如插件是否允许访问网络、密钥或私有地址。`NetworkPolicyRuntime` 用于根据 host/address 判断私网、环回地址和阻断策略。`DiagnosticsRuntime` 可记录诊断日志，并对 token、API key、Bearer header 做脱敏。

推荐调用顺序：

1. UI 或插件提出请求。
2. `PermissionRuntime.checkNetworkAccess()` 判断 subject 是否有权限。
3. 宿主网络层解析 DNS 后，把 host 和 address 交给 `NetworkPolicyRuntime.evaluateHost()`。
4. 通过后才发起真实 HTTP 请求。
5. 请求失败时写入 `DiagnosticsRuntime`，不要记录明文密钥。

## UI 桥接

`UIBridgeRuntime` 用来把 headless 运行时中的 UI 请求转成事件，例如文件选择、确认框、媒体预览等。SDK 不直接展示 UI，宿主订阅事件后自行渲染界面，再回写响应。

适合通过 UI 桥接处理的场景：

- 选择角色卡、图片、音频、备份文件。
- 展示插件或导入流程中的确认框。
- 预览图片、音频、附件。
- 请求用户输入或二次确认危险操作。

## 测试

模块内测试位于 `tavern_ohos/src/test` 和 `tavern_ohos/src/ohosTest`。常用验证命令：

```bash
# 检查补丁空白
git diff --check -- tavern_ohos

# 构建 HAR
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=tavern_ohos@default assembleHar -p buildMode=debug --no-daemon

# 生成设备测试 HAP
env DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=tavern_ohos@default genOnDeviceTestHap -p buildMode=debug --no-daemon

# 检查设备
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc list targets
```

如果 `hdc list targets` 返回 `[Empty]`，说明当前没有可安装运行的设备，只能完成编译级验证。

## 同步升级流程

后续同步 SillyTavern 官方仓库时建议按以下流程：

1. 更新 README 中的 `对齐版本`、`对齐提交`、`记录日期`。
2. 对比官方 `release` 分支的 endpoint、前端脚本、插件接口、数据格式变更。
3. 更新 `sillytavern_endpoint_feature_parity_matrix.md`。
4. 先补测试，再改 Runtime。
5. 对网络请求相关变更，明确区分“请求体构造”“真实网络发送”“响应解析”三个层次。
6. 跑 ArkTS 静态检查、HAR 构建、测试 HAP 构建和设备端测试。

## 常见问题

### 为什么没有一个 `TavernRuntime` 总入口？

当前模块按能力拆分 Runtime，方便宿主应用按需组合，也方便测试每个领域逻辑。宿主可以自行封装一个应用级容器，集中创建 `EventBus`、`TavernFileStore` 和各 Runtime。

### 为什么 ProviderRuntime 还保留 `ProviderStreamSource`？

`ProviderRuntime` 只负责任务状态、SSE 归一化、流式快照和事件发布；请求来源由 `ProviderStreamSource` 提供。SDK 内置的 `OpenAIOhosProviderStreamSource` 是默认 OpenAI-compatible chat streaming 实现，适合直接请求 OpenAI 或兼容网关。保留自定义 source 是为了支持企业代理、非标准 provider、离线模型、测试替身、额外审计和宿主统一网络治理。

### `openai` 请求头会自动加 Authorization 吗？

使用 `OpenAIOhosProviderStreamSource` 时会自动加 `Authorization: Bearer <apiKey>`。使用自定义 `ProviderStreamSource` 时，鉴权由自定义 source 或宿主网络层负责。

### 可以直接导入 SillyTavern 的角色卡和世界书吗？

角色卡、PNG metadata、WebP metadata、charx、世界书、聊天 JSONL 等能力已由对应 Runtime 覆盖。具体状态以 `sillytavern_endpoint_feature_parity_matrix.md` 为准。
