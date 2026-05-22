# OpenAI Harmony SDK

HarmonyOS/ArkTS 版 OpenAI SDK 当前提供两层能力：

- `models/*`：核心 OpenAI API 的输入/输出模型对象，字段带中文说明和对应 API 标注。
- `client/*`：可真实发起请求的 SDK 入口，使用方式尽量贴近官方 SDK。

## 基础用法

```ts
import { OpenAI } from 'library';

const client = new OpenAI({
  apiKey: 'sk-...',
});

const models = await client.models.list();
```

如果需要代理或自定义网关：

```ts
const client = new OpenAI({
  apiKey: 'sk-...',
  baseURL: 'https://example.test/v1',
  organization: 'org_xxx',
  project: 'proj_xxx',
  timeout: 60000,
  maxRetries: 2,
});
```

## 已实现请求资源

### Models

```ts
await client.models.list();
await client.models.retrieve('gpt-4o');
await client.models.delete('ft:gpt-...');
```

### Responses

```ts
await client.responses.create({
  model: 'gpt-5.4',
  input: '你好',
});

await client.responses.retrieve('resp_...');
await client.responses.cancel('resp_...');
await client.responses.delete('resp_...');
```

### Conversations

```ts
const conversation = await client.conversations.create({});

await client.conversations.items.create(conversation.id, {
  item: {
    type: 'message',
    role: 'user',
    content: [{ type: 'input_text', text: '你好' }],
  },
});

await client.conversations.items.list(conversation.id, {
  include: ['file_search_call.results'],
});

await client.conversations.delete(conversation.id);
```

### ChatKit

```ts
const session = await client.chatkit.sessions.create({
  user: 'user_123',
  workflow: {
    id: 'workflow_alpha',
    version: '2024-10-01',
  },
});

await client.chatkit.threads.list({ user: 'user_123', limit: 20 });
await client.chatkit.threads.retrieve('cthr_...');
await client.chatkit.threads.items.list('cthr_...');
await client.chatkit.sessions.cancel(session.id!);
```

### Assistants v2

```ts
const assistant = await client.beta.assistants.create({
  model: 'gpt-4o-mini',
  name: 'Helper',
  instructions: 'Help.',
});

const thread = await client.beta.threads.create({});

await client.beta.threads.messages.create(thread.id, {
  role: 'user',
  content: '你好',
});

const run = await client.beta.threads.runs.create(thread.id, {
  assistant_id: assistant.id,
});

await client.beta.threads.runs.steps.list(thread.id, run.id);
await client.beta.threads.delete(thread.id);
await client.beta.assistants.delete(assistant.id);
```

### Chat Completions

```ts
await client.chat.completions.create({
  model: 'gpt-5.4',
  messages: [{ role: 'user', content: '你好' }],
});

await client.chat.completions.retrieve('chatcmpl_...');
await client.chat.completions.list({ model: 'gpt-5.4', limit: 10 });
await client.chat.completions.update('chatcmpl_...', { metadata: { key: 'value' } });
await client.chat.completions.delete('chatcmpl_...');
```

### Embeddings

```ts
await client.embeddings.create({
  model: 'text-embedding-3-small',
  input: '鸿蒙 OpenAI SDK',
});
```

### Images

```ts
await client.images.generate({
  model: 'gpt-image-1',
  prompt: 'A clean SDK logo',
});

await client.images.edit({
  model: 'gpt-image-1',
  prompt: 'Edit this image',
  image: 'file://image.png',
});

await client.images.createVariation({
  model: 'dall-e-2',
  image: 'file://image.png',
});
```

### Audio

```ts
const speech = await client.audio.speech.create({
  model: 'gpt-4o-mini-tts',
  input: '你好',
  voice: 'alloy',
  response_format: 'mp3',
});

await client.audio.transcriptions.create({
  file: 'file://audio.wav',
  model: 'gpt-4o-transcribe',
});

await client.audio.translations.create({
  file: 'file://audio.wav',
  model: 'whisper-1',
});

const consent = await client.audio.voiceConsents.create({
  name: 'John Doe',
  language: 'en-US',
  recording: 'file://consent.wav',
});

await client.audio.voices.create({
  name: 'My voice',
  consent: consent.id,
  audio_sample: 'file://sample.wav',
});
```

### Realtime

```ts
const secret = await client.realtime.clientSecrets.create({
  expires_after: { anchor: 'created_at', seconds: 600 },
  session: {
    type: 'realtime',
    model: 'gpt-realtime',
    instructions: 'Be concise.',
  },
});

await client.realtime.transcriptionSessions.create({
  input_audio_format: 'pcm16',
  input_audio_transcription: {
    model: 'gpt-4o-transcribe',
    language: 'zh',
  },
});
```

### Moderations

```ts
await client.moderations.create({
  input: '需要审核的内容',
});
```

### Files

```ts
await client.files.create({
  file: 'file://input.jsonl',
  purpose: 'batch',
});

await client.files.list();
await client.files.retrieve('file_...');
await client.files.content('file_...');
await client.files.delete('file_...');
```

### Uploads

```ts
const upload = await client.uploads.create({
  bytes: 1024,
  filename: 'input.jsonl',
  mime_type: 'text/jsonl',
  purpose: 'fine-tune',
});

const part = await client.uploads.parts.create(upload.id, {
  data: 'file://chunk-1.bin',
});

await client.uploads.complete(upload.id, {
  part_ids: [part.id],
});

await client.uploads.cancel(upload.id);
```

### Batches

```ts
await client.batches.create({
  input_file_id: 'file_...',
  endpoint: '/v1/responses',
  completion_window: '24h',
});

await client.batches.list();
await client.batches.retrieve('batch_...');
await client.batches.cancel('batch_...');
```

### Vector Stores

```ts
const vectorStore = await client.vectorStores.create({
  name: 'Docs',
  file_ids: ['file_...'],
});

await client.vectorStores.files.create(vectorStore.id, {
  file_id: 'file_...',
});

await client.vectorStores.fileBatches.create(vectorStore.id, {
  file_ids: ['file_1', 'file_2'],
});

await client.vectorStores.search(vectorStore.id, {
  query: '如何接入 OpenAI SDK?',
});

await client.vectorStores.delete(vectorStore.id);
```

### Fine-tuning

```ts
const job = await client.fineTuning.jobs.create({
  model: 'gpt-4o-mini',
  training_file: 'file_...',
});

await client.fineTuning.jobs.retrieve(job.id);
await client.fineTuning.jobs.listEvents(job.id);
await client.fineTuning.jobs.listCheckpoints(job.id);
await client.fineTuning.jobs.cancel(job.id);
```

### Evals

```ts
const evalObject = await client.evals.create({
  name: 'Quality eval',
  data_source_config: { type: 'custom' },
  testing_criteria: [{ type: 'string_check', name: 'contains' }],
});

const run = await client.evals.runs.create(evalObject.id, {
  name: 'Run 1',
  data_source: {
    type: 'jsonl',
    source: { type: 'file_id', id: 'file_...' },
  },
});

await client.evals.runs.outputItems.list(evalObject.id, run.id);
await client.evals.delete(evalObject.id);
```

### Containers

```ts
const container = await client.containers.create({
  name: 'My Container',
  memory_limit: '4g',
});

await client.containers.files.create(container.id, {
  file: 'file://input.txt',
});

await client.containers.files.list(container.id);
await client.containers.files.content(container.id, 'cfile_...');
await client.containers.delete(container.id);
```

### Legacy Completions

```ts
await client.completions.create({
  model: 'gpt-3.5-turbo-instruct',
  prompt: 'hello',
});
```

## 当前边界

- 当前请求层覆盖 JSON 请求、multipart 上传、普通 GET、DELETE、二进制响应转 base64。
- 默认会对 408、409、429 和 5xx 临时错误自动重试 2 次，可通过 `maxRetries` 调整。
- SSE streaming、Realtime WebSocket/WebRTC transport、文件内容落盘下载还未实现；`files.content()` 已可读取文本内容。
- HAR 已声明 `ohos.permission.INTERNET`；如果宿主应用没有合并权限，需要在 entry 模块也声明。
