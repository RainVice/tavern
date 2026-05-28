import type { CompletionUsage, CursorPageParams, JsonObject, Metadata, OpenAIListResponse, OpenAIModel } from './Common';

/**
 * Chat Completions 常见模型 ID。
 *
 * API：`POST /v1/chat/completions`。
 * 说明：Chat Completions 是兼容旧使用方式的对话生成 API；新项目官方更推荐 Responses API。
 */
export type ChatModel = OpenAIModel | 'gpt-5.4' | 'gpt-4.1' | 'gpt-4o' | 'gpt-4o-mini';

/**
 * Chat message 角色。
 *
 * API：`POST /v1/chat/completions` 的 `messages` 字段。
 * 说明：`developer` 是新模型推荐的开发者指令角色，`system` 兼容旧式系统指令。
 */
export type ChatCompletionRole = 'system' | 'developer' | 'user' | 'assistant' | 'tool';

/**
 * Chat 文本内容块。
 *
 * API：`POST /v1/chat/completions`。
 * 说明：用于多模态消息中的文本片段。
 */
export interface ChatCompletionContentPartText {
  /**
   * 内容块类型。
   *
   * API：Chat Completions。
   * 说明：固定为 `text`。
   */
  type: 'text';

  /**
   * 文本内容。
   *
   * API：Chat Completions。
   * 说明：发送给模型的消息文本。
   */
  text: string;
}

/**
 * Chat 图片内容块。
 *
 * API：`POST /v1/chat/completions`。
 * 说明：用于视觉模型输入图片。
 */
export interface ChatCompletionContentPartImage {
  /**
   * 内容块类型。
   *
   * API：Chat Completions。
   * 说明：固定为 `image_url`。
   */
  type: 'image_url';

  /**
   * 图片信息。
   *
   * API：Chat Completions。
   * 说明：包含 URL 和可选细节等级。
   */
  image_url: ChatCompletionImageUrl;
}

/**
 * Chat 图片 URL。
 *
 * API：`POST /v1/chat/completions`。
 * 说明：可传公网 URL 或 base64 data URL。
 */
export interface ChatCompletionImageUrl {
  /**
   * 图片地址。
   *
   * API：Chat Completions。
   * 说明：完整 URL 或 data URL。
   */
  url: string;

  /**
   * 图像细节。
   *
   * API：Chat Completions。
   * 说明：`auto` 由模型自动决定，`high` 通常消耗更多 token。
   */
  detail?: 'auto' | 'low' | 'high';
}

/**
 * Chat 输入内容。
 *
 * API：`POST /v1/chat/completions`。
 * 说明：可为字符串，或多模态内容块数组。
 */
export type ChatCompletionMessageContent = string | Array<ChatCompletionContentPartText | ChatCompletionContentPartImage>;

/**
 * Chat 输入消息。
 *
 * API：`POST /v1/chat/completions`。
 * 说明：官方使用 `messages` 数组描述对话历史。
 */
export interface ChatCompletionMessageParam {
  /**
   * 消息角色。
   *
   * API：Chat Completions。
   * 说明：用于区分系统、开发者、用户、助手和工具消息。
   */
  role: ChatCompletionRole;

  /**
   * 消息内容。
   *
   * API：Chat Completions。
   * 说明：普通文本或图文混合内容。
   */
  content?: ChatCompletionMessageContent | null;

  /**
   * 参与者名称。
   *
   * API：Chat Completions。
   * 说明：当同一角色有多个参与者时用于区分。
   */
  name?: string;

  /**
   * 工具调用 ID。
   *
   * API：Chat Completions。
   * 说明：`tool` 角色消息用于回填工具调用结果时需要。
   */
  tool_call_id?: string;

  /**
   * 助手工具调用。
   *
   * API：Chat Completions。
   * 说明：assistant 消息中模型请求调用的工具列表。
   */
  tool_calls?: Array<ChatCompletionMessageToolCall>;
}

/**
 * Chat function tool 定义。
 *
 * API：`POST /v1/chat/completions` 的 `tools` 字段。
 * 说明：让模型生成函数调用参数。
 */
export interface ChatCompletionTool {
  /**
   * 工具类型。
   *
   * API：Chat Completions。
   * 说明：固定为 `function`。
   */
  type: 'function';

  /**
   * 函数定义。
   *
   * API：Chat Completions。
   * 说明：包含函数名、说明和参数 schema。
   */
  function: ChatCompletionFunctionDefinition;
}

/**
 * Chat function 定义。
 *
 * API：`POST /v1/chat/completions`。
 * 说明：提供给模型的可调用函数描述。
 */
export interface ChatCompletionFunctionDefinition {
  /**
   * 函数名。
   *
   * API：Chat Completions。
   * 说明：模型返回工具调用时会使用该名称。
   */
  name: string;

  /**
   * 函数描述。
   *
   * API：Chat Completions。
   * 说明：告诉模型函数用途和调用时机。
   */
  description?: string;

  /**
   * 参数 JSON Schema。
   *
   * API：Chat Completions。
   * 说明：描述函数入参结构。
   */
  parameters?: JsonObject;

  /**
   * 是否严格遵守 schema。
   *
   * API：Chat Completions。
   * 说明：开启后模型必须按 schema 生成函数参数。
   */
  strict?: boolean | null;
}

/**
 * Chat 结构化输出格式。
 *
 * API：`POST /v1/chat/completions` 的 `response_format` 字段。
 * 说明：支持文本、JSON object 和 JSON Schema。
 */
export interface ChatCompletionResponseFormat {
  /**
   * 输出格式类型。
   *
   * API：Chat Completions。
   * 说明：`json_schema` 是结构化输出的推荐方式。
   */
  type: 'text' | 'json_object' | 'json_schema';

  /**
   * JSON Schema 配置。
   *
   * API：Chat Completions。
   * 说明：当 `type` 为 `json_schema` 时使用。
   */
  json_schema?: JsonObject;
}

/**
 * 创建 Chat Completion 请求。
 *
 * API：`POST /v1/chat/completions`。
 * 说明：兼容官方 Node SDK `client.chat.completions.create(...)` 的核心参数。
 */
export interface ChatCompletionCreateParams {
  /**
   * 对话消息。
   *
   * API：Chat Completions。
   * 说明：描述当前对话上下文，至少包含一条消息。
   */
  messages: Array<ChatCompletionMessageParam>;

  /**
   * 模型 ID。
   *
   * API：Chat Completions。
   * 说明：例如 `gpt-5.4`、`gpt-4.1`、`gpt-4o`。
   */
  model: ChatModel;

  /**
   * 频率惩罚。
   *
   * API：Chat Completions。
   * 说明：正值会降低模型重复相同词语的概率。
   */
  frequency_penalty?: number | null;

  /**
   * 最大完成 token。
   *
   * API：Chat Completions。
   * 说明：新模型推荐使用该字段限制输出与推理 token。
   */
  max_completion_tokens?: number | null;

  /**
   * 旧最大 token。
   *
   * API：Chat Completions。
   * 说明：兼容旧模型；推理模型通常不支持，建议优先使用 `max_completion_tokens`。
   */
  max_tokens?: number | null;

  /**
   * 元数据。
   *
   * API：Chat Completions。
   * 说明：用于给存储的 completion 附加业务键值。
   */
  metadata?: Metadata | null;

  /**
   * 输出模态。
   *
   * API：Chat Completions。
   * 说明：通常为 `text`，支持音频的模型可请求 `audio`。
   */
  modalities?: Array<'text' | 'audio'> | null;

  /**
   * 生成候选数量。
   *
   * API：Chat Completions。
   * 说明：大于 1 会增加 token 成本。
   */
  n?: number | null;

  /**
   * 是否并行工具调用。
   *
   * API：Chat Completions。
   * 说明：允许模型一次请求多个工具。
   */
  parallel_tool_calls?: boolean;

  /**
   * 存在惩罚。
   *
   * API：Chat Completions。
   * 说明：正值会鼓励模型引入新主题。
   */
  presence_penalty?: number | null;

  /**
   * 输出格式。
   *
   * API：Chat Completions。
   * 说明：用于 JSON 输出或结构化输出。
   */
  response_format?: ChatCompletionResponseFormat;

  /**
   * 随机种子。
   *
   * API：Chat Completions。
   * 说明：用于尽量复现实验输出；不保证绝对确定。
   */
  seed?: number | null;

  /**
   * 服务层级。
   *
   * API：Chat Completions。
   * 说明：控制默认、flex、priority 等处理策略。
   */
  service_tier?: 'auto' | 'default' | 'flex' | 'scale' | 'priority' | null;

  /**
   * 停止序列。
   *
   * API：Chat Completions。
   * 说明：模型遇到这些字符串时停止生成。
   */
  stop?: string | Array<string> | null;

  /**
   * 是否存储 completion。
   *
   * API：Chat Completions。
   * 说明：开启后可 retrieve/list/delete 已存储的 chat completion。
   */
  store?: boolean | null;

  /**
   * 是否流式返回。
   *
   * API：Chat Completions。
   * 说明：开启后返回 `ChatCompletionChunk` 事件流。
   */
  stream?: boolean | null;

  /**
   * 采样温度。
   *
   * API：Chat Completions。
   * 说明：范围通常为 0 到 2。
   */
  temperature?: number | null;

  /**
   * 工具选择策略。
   *
   * API：Chat Completions。
   * 说明：可为 `none`、`auto`、`required` 或指定具体 function。
   */
  tool_choice?: 'none' | 'auto' | 'required' | JsonObject;

  /**
   * 工具列表。
   *
   * API：Chat Completions。
   * 说明：当前核心层覆盖 function tool。
   */
  tools?: Array<ChatCompletionTool>;

  /**
   * nucleus sampling 参数。
   *
   * API：Chat Completions。
   * 说明：通常不要与 `temperature` 同时大幅调整。
   */
  top_p?: number | null;

  /**
   * 终端用户标识。
   *
   * API：Chat Completions。
   * 说明：用于滥用检测，建议使用不可逆匿名 ID。
   */
  user?: string;
}

/**
 * 更新已存储 Chat Completion 请求。
 *
 * API：`POST /v1/chat/completions/{completion_id}`。
 * 说明：官方当前主要支持更新 metadata。
 */
export interface ChatCompletionUpdateParams {
  /**
   * 元数据。
   *
   * API：Chat Completions update。
   * 说明：替换或更新已存储 completion 的业务键值。
   */
  metadata?: Metadata | null;
}

/**
 * Chat Completion 列表请求。
 *
 * API：`GET /v1/chat/completions`。
 * 说明：列出使用 `store: true` 创建的 chat completion。
 */
export interface ChatCompletionListParams extends CursorPageParams {
  /**
   * 按模型过滤。
   *
   * API：Chat Completions list。
   * 说明：只返回指定模型创建的 completion。
   */
  model?: string;
}

/**
 * Chat assistant 消息响应。
 *
 * API：Chat Completions 响应。
 * 说明：`choices[].message` 使用该模型。
 */
export interface ChatCompletionMessage {
  /**
   * 消息角色。
   *
   * API：Chat Completions 响应。
   * 说明：通常为 `assistant`。
   */
  role: 'assistant';

  /**
   * 文本内容。
   *
   * API：Chat Completions 响应。
   * 说明：模型生成的文本；工具调用场景可能为空。
   */
  content?: string | null;

  /**
   * 拒答文本。
   *
   * API：Chat Completions 响应。
   * 说明：模型拒绝回答时可能返回。
   */
  refusal?: string | null;

  /**
   * 工具调用列表。
   *
   * API：Chat Completions 响应。
   * 说明：模型请求调用工具时返回。
   */
  tool_calls?: Array<ChatCompletionMessageToolCall>;
}

/**
 * Chat 工具调用。
 *
 * API：Chat Completions 响应。
 * 说明：表示模型希望调用某个 function tool。
 */
export interface ChatCompletionMessageToolCall {
  /**
   * 工具调用 ID。
   *
   * API：Chat Completions 响应。
   * 说明：后续 tool message 需要用该 ID 关联结果。
   */
  id: string;

  /**
   * 工具类型。
   *
   * API：Chat Completions 响应。
   * 说明：固定为 `function`。
   */
  type: 'function';

  /**
   * 函数调用内容。
   *
   * API：Chat Completions 响应。
   * 说明：包含函数名和 JSON 字符串参数。
   */
  function: ChatCompletionFunctionCall;
}

/**
 * Chat 函数调用内容。
 *
 * API：Chat Completions 响应。
 * 说明：工具调用中的 function payload。
 */
export interface ChatCompletionFunctionCall {
  /**
   * 函数名。
   *
   * API：Chat Completions 响应。
   * 说明：对应请求中 `tools[].function.name`。
   */
  name: string;

  /**
   * 参数 JSON 字符串。
   *
   * API：Chat Completions 响应。
   * 说明：client 层需要按 schema 解析。
   */
  arguments: string;
}

/**
 * Chat completion 候选。
 *
 * API：Chat Completions 响应。
 * 说明：`choices` 数组中的一个候选结果。
 */
export interface ChatCompletionChoice {
  /**
   * 候选索引。
   *
   * API：Chat Completions 响应。
   * 说明：从 0 开始。
   */
  index: number;

  /**
   * 停止原因。
   *
   * API：Chat Completions 响应。
   * 说明：例如自然停止、长度限制、工具调用或内容过滤。
   */
  finish_reason: 'stop' | 'length' | 'tool_calls' | 'content_filter' | 'function_call';

  /**
   * 生成消息。
   *
   * API：Chat Completions 响应。
   * 说明：模型返回的 assistant message。
   */
  message: ChatCompletionMessage;

  /**
   * logprob 信息。
   *
   * API：Chat Completions 响应。
   * 说明：仅请求 `logprobs` 时可能返回；核心层用 JSON object 保留细节。
   */
  logprobs?: JsonObject | null;
}

/**
 * Chat Completion 响应对象。
 *
 * API：`POST /v1/chat/completions`、`GET /v1/chat/completions/{completion_id}`。
 * 说明：非流式 chat completion 的完整响应。
 */
export interface ChatCompletion {
  /**
   * Completion ID。
   *
   * API：Chat Completions 响应。
   * 说明：存储后可用于 retrieve/update/delete。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Chat Completions 响应。
   * 说明：固定为 `chat.completion`。
   */
  object: 'chat.completion';

  /**
   * 创建时间。
   *
   * API：Chat Completions 响应。
   * 说明：Unix 秒级时间戳。
   */
  created: number;

  /**
   * 模型 ID。
   *
   * API：Chat Completions 响应。
   * 说明：实际生成该 completion 的模型。
   */
  model: string;

  /**
   * 候选列表。
   *
   * API：Chat Completions 响应。
   * 说明：长度受请求参数 `n` 影响。
   */
  choices: Array<ChatCompletionChoice>;

  /**
   * token 用量。
   *
   * API：Chat Completions 响应。
   * 说明：用于成本统计。
   */
  usage?: CompletionUsage;

  /**
   * 服务层级。
   *
   * API：Chat Completions 响应。
   * 说明：返回实际使用的处理层级。
   */
  service_tier?: 'auto' | 'default' | 'flex' | 'scale' | 'priority' | null;

  /**
   * 系统指纹。
   *
   * API：Chat Completions 响应。
   * 说明：用于观察后端配置变化；官方已逐步弱化该字段。
   */
  system_fingerprint?: string;
}

/**
 * Chat Completion 列表响应。
 *
 * API：`GET /v1/chat/completions`。
 * 说明：返回已存储 chat completion 的列表。
 */
export type ChatCompletionListResponse = OpenAIListResponse<ChatCompletion>;

/**
 * 删除 Chat Completion 响应。
 *
 * API：`DELETE /v1/chat/completions/{completion_id}`。
 * 说明：表示已存储 completion 的删除结果。
 */
export interface ChatCompletionDeleted {
  /**
   * Completion ID。
   *
   * API：Chat Completions delete。
   * 说明：被删除的 completion ID。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Chat Completions delete。
   * 说明：固定为 `chat.completion.deleted`。
   */
  object: 'chat.completion.deleted';

  /**
   * 是否删除成功。
   *
   * API：Chat Completions delete。
   * 说明：成功时为 true。
   */
  deleted: boolean;
}

/**
 * 流式 chunk 增量内容。
 *
 * API：Chat Completions streaming。
 * 说明：chunk 中每个 choice 的增量消息片段。
 */
export interface ChatCompletionChunkDelta {
  /**
   * 消息角色。
   *
   * API：Chat Completions streaming。
   * 说明：通常在首个 chunk 中出现。
   */
  role?: string;

  /**
   * 文本内容增量。
   *
   * API：Chat Completions streaming。
   * 说明：模型逐步生成的文本片段。
   */
  content?: string | null;

  /**
   * 工具调用增量。
   *
   * API：Chat Completions streaming。
   * 说明：工具调用参数以流式方式分片返回。
   */
  tool_calls?: Array<ChatCompletionMessageToolCall>;

  /**
   * 拒答文本增量。
   *
   * API：Chat Completions streaming。
   * 说明：模型拒绝回答时可能出现。
   */
  refusal?: string | null;
}

/**
 * 流式 chunk 候选。
 *
 * API：Chat Completions streaming。
 * 说明：`ChatCompletionChunk.choices` 中的每个候选。
 */
export interface ChatCompletionChunkChoice {
  /**
   * 候选索引。
   *
   * API：Chat Completions streaming。
   * 说明：从 0 开始。
   */
  index: number;

  /**
   * 增量内容。
   *
   * API：Chat Completions streaming。
   * 说明：本 chunk 新增的消息片段。
   */
  delta: ChatCompletionChunkDelta;

  /**
   * logprob 信息。
   *
   * API：Chat Completions streaming。
   * 说明：仅请求 `logprobs` 时可能返回。
   */
  logprobs?: JsonObject | null;

  /**
   * 停止原因。
   *
   * API：Chat Completions streaming。
   * 说明：仅在最后一个 chunk 中有值。
   */
  finish_reason: string | null;
}

/**
 * Chat Completion 流式 chunk。
 *
 * API：`POST /v1/chat/completions` 设置 `stream: true`。
 * 说明：SSE 流中每次返回的增量对象。
 */
export interface ChatCompletionChunk {
  /**
   * Chunk ID。
   *
   * API：Chat Completions streaming。
   * 说明：通常与本次 completion 相关。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Chat Completions streaming。
   * 说明：固定为 `chat.completion.chunk`。
   */
  object: 'chat.completion.chunk';

  /**
   * 创建时间。
   *
   * API：Chat Completions streaming。
   * 说明：Unix 秒级时间戳。
   */
  created: number;

  /**
   * 模型 ID。
   *
   * API：Chat Completions streaming。
   * 说明：实际生成 chunk 的模型。
   */
  model: string;

  /**
   * 增量候选列表。
   *
   * API：Chat Completions streaming。
   * 说明：包含本次事件新增的 delta。
   */
  choices: Array<ChatCompletionChunkChoice>;
}
