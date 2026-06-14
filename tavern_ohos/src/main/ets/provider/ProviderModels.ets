import type {
  ChatMessageRole,
  ConnectionApiType,
  ProviderId,
  RuntimeTaskStatus,
  TokenizerStrategy,
} from '../contracts/PublicContracts';

/**
 * 声明供应商/后端能力的接口，描述其支持的模型功能特性。
 */
export interface ProviderCapability {
  /**
   * 供应商标识符（如 'openai'、'anthropic'）。
   */
  provider: ProviderId;
  /**
   * 后端模型名称标识。
   */
  model: string;
  /**
   * 是否支持流式输出。
   */
  supportsStreaming: boolean;
  /**
   * 是否支持系统提示词（system prompt）。
   */
  supportsSystemPrompt: boolean;
  /**
   * 是否支持函数调用/工具使用。
   */
  supportsTools: boolean;
  /**
   * 是否支持推理过程输出（如思维链）。
   */
  supportsReasoning: boolean;
  /**
   * 是否支持图片输入（视觉识别）。
   */
  supportsVisionInput: boolean;
  /**
   * 是否支持图片输出。
   */
  supportsImageOutput: boolean;
  /**
   * 是否支持 JSON Schema 结构化输出。
   */
  supportsJsonSchema: boolean;
  /**
   * 是否支持返回对数概率（logprobs）。
   */
  supportsLogprobs: boolean;
  /**
   * 是否支持随机种子（seed）参数。
   */
  supportsSeed: boolean;
  /**
   * 是否支持停止字符串（stop sequences）。
   */
  supportsStopStrings: boolean;
  /**
   * 是否支持助手预填充（assistant prefilled message）。
   */
  supportsAssistantPrefill: boolean;
  /**
   * 是否支持文本补全模式。
   */
  supportsTextCompletion: boolean;
  /**
   * 是否支持聊天补全模式。
   */
  supportsChatCompletion: boolean;
  /**
   * 最大上下文长度（token 数）。
   */
  maxContext: number;
  /**
   * 使用的分词器策略。
   */
  tokenizer: TokenizerStrategy;
}

/**
 * 聊天消息结构，用于向 Provider 发送对话上下文。
 */
export interface ProviderChatMessage {
  /**
   * 消息角色（user、assistant、system）。
   */
  role: ChatMessageRole;
  /**
   * 消息文本内容。
   */
  content: string;
}

/**
 * Provider 流式请求的入参，包含模型选择、采样参数和对话上下文。
 */
export interface ProviderStreamRequest {
  /**
   * 供应商类型标识。
   */
  provider: ProviderId;
  /**
   * 目标模型名称。
   */
  model: string;
  /**
   * 对话消息列表。
   */
  messages: Array<ProviderChatMessage>;
  /**
   * 采样温度参数。
   */
  temperature: number;
  /**
   * 最大生成 token 数。
   */
  maxTokens: number;
  /**
   * 停止字符串列表。
   */
  stop: Array<string>;
  /**
   * 是否启用流式输出。
   */
  stream: boolean;
}

/**
 * 文本补全功能的构建参数，包含所有可配置的采样选项。
 */
export interface ProviderTextCompletionBuildParams {
  /**
   * API 连接类型（如 openai、ollama、llamacpp 等）。
   */
  apiType: ConnectionApiType;
  /**
   * 模型名称。
   */
  model: string;
  /**
   * 输入提示文本。
   */
  prompt: string;
  /**
   * 采样温度。
   */
  temperature: number;
  /**
   * 最大生成 token 数。
   */
  maxTokens: number;
  /**
   * 停止字符串列表。
   */
  stop: Array<string>;
  /**
   * 是否启用流式输出。
   */
  stream: boolean;
  /**
   * top-p 采样参数（可选）。
   */
  topP?: number;
  /**
   * 存在惩罚系数（可选）。
   */
  presencePenalty?: number;
  /**
   * 频率惩罚系数（可选）。
   */
  frequencyPenalty?: number;
  /**
   * 随机种子（可选）。
   */
  seed?: number;
}

/**
 * 文本补全的完整请求数据结构，包含目标路径和请求体。
 */
export interface ProviderTextCompletionRequest {
  /**
   * API 连接类型。
   */
  apiType: ConnectionApiType;
  /**
   * 请求路径（如 '/v1/completions'）。
   */
  path: string;
  /**
   * 请求体数据。
   */
  body: ProviderTextCompletionBody;
}

/**
 * 文本补全请求体，包含模型和采样参数，兼容多种后端命名差异。
 */
export interface ProviderTextCompletionBody {
  /**
   * 模型名称。
   */
  model: string;
  /**
   * 输入提示文本。
   */
  prompt: string;
  /**
   * 采样温度。
   */
  temperature: number;
  /**
   * 最大生成 token 数（OpenAI 风格字段名）。
   */
  max_tokens?: number;
  /**
   * 最大生成 token 数（HuggingFace 风格字段名）。
   */
  max_new_tokens?: number;
  /**
   * 最大生成 token 数（Ollama 风格字段名）。
   */
  num_predict?: number;
  /**
   * 停止字符串列表。
   */
  stop: Array<string>;
  /**
   * 是否启用流式输出。
   */
  stream: boolean;
  /**
   * top-p 采样参数（可选）。
   */
  top_p?: number;
  /**
   * 存在惩罚系数（可选）。
   */
  presence_penalty?: number;
  /**
   * 频率惩罚系数（可选）。
   */
  frequency_penalty?: number;
  /**
   * 随机种子（可选）。
   */
  seed?: number;
  /**
   * 是否启用原始模式（Ollama 等后端使用）（可选）。
   */
  raw?: boolean;
  /**
   * 附加的采样配置选项（Ollama 等后端使用）。
   */
  options?: ProviderTextCompletionOptions;
}

/**
 * 文本补全的额外采样选项，主要服务于 Ollama 等后端的 options 嵌套结构。
 */
export interface ProviderTextCompletionOptions {
  /**
   * 采样温度。
   */
  temperature: number;
  /**
   * 最大生成 token 数。
   */
  num_predict: number;
  /**
   * 停止字符串列表。
   */
  stop: Array<string>;
  /**
   * top-p 采样参数（可选）。
   */
  top_p?: number;
  /**
   * 存在惩罚系数（可选）。
   */
  presence_penalty?: number;
  /**
   * 频率惩罚系数（可选）。
   */
  frequency_penalty?: number;
  /**
   * 随机种子（可选）。
   */
  seed?: number;
}

/**
 * 启动 Provider 流式任务的参数，包含任务标识和流式来源。
 */
export interface ProviderStreamStartParams {
  /**
   * 任务唯一标识。
   */
  taskId: string;
  /**
   * 关联的聊天会话标识。
   */
  chatId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * 流式请求参数。
   */
  request: ProviderStreamRequest;
  /**
   * 流式数据源（如 OpenAI SSE 源）。
   */
  source: ProviderStreamSource;
}

/**
 * Provider 流式连接的句柄，提供关闭流式连接的能力。
 */
export interface ProviderStreamHandle {
  /**
   * 关闭当前流式连接。
   */
  close(): void;
}

/**
 * Provider 流式数据的消费者接口，接收流式事件。
 */
export interface ProviderStreamSink {
  /**
   * 处理接收到的数据块。
   * @param chunk SSE 原始数据块字符串。
   */
  onChunk(chunk: string): Promise<void>;
  /**
   * 处理流式传输中的错误。
   * @param message 错误描述信息。
   */
  onError(message: string): Promise<void>;
  /**
   * 标记流式传输完成。
   */
  onDone(): Promise<void>;
}

/**
 * Provider 流式数据源接口，负责启动流式请求并输出数据到 sink。
 */
export interface ProviderStreamSource {
  /**
   * 启动流式请求，开始接收数据。
   * @param request 流式请求参数。
   * @param sink 数据消费者。
   * @returns 流式连接句柄，可在外部关闭。
   */
  start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle>;
}

/**
 * 运行中的 Provider 流式任务状态信息。
 */
export interface ProviderStreamTask {
  /**
   * 任务唯一标识。
   */
  taskId: string;
  /**
   * 所属流式会话标识。
   */
  sessionId: string;
  /**
   * 关联的聊天会话标识。
   */
  chatId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * 供应商类型。
   */
  provider: ProviderId;
  /**
   * 模型名称。
   */
  model: string;
  /**
   * 任务当前状态（running / completed / failed / aborted）。
   */
  status: RuntimeTaskStatus;
  /**
   * 错误信息（为空表示无错误）。
   */
  error: string;
  /**
   * 模型返回的结束原因（stop / length / content_filter 等）。
   */
  finishReason: string;
  /**
   * 任务创建时间戳。
   */
  createdAt: number;
  /**
   * 任务最近更新时间戳。
   */
  updatedAt: number;
}

/**
 * Provider 生成事件发布时携带的数据载荷。
 */
export interface ProviderGenerationPayload {
  /**
   * 关联的流式任务状态。
   */
  task: ProviderStreamTask;
}

/**
 * 解析后的 SSE 事件，包含事件名称、数据和标识。
 */
export interface ProviderSSEEvent {
  /**
   * SSE 事件类型名称（如 'message'、'error'）。
   */
  event: string;
  /**
   * SSE 事件数据内容。
   */
  data: string;
  /**
   * SSE 事件 ID。
   */
  id: string;
}

/**
 * 规范化后的 Provider 数据块，统一不同后端的增量数据格式。
 */
export interface ProviderNormalizedChunk {
  /**
   * 增量文本内容。
   */
  textDelta: string;
  /**
   * 增量推理过程内容（如思维链）。
   */
  reasoningDelta: string;
  /**
   * 模型返回的结束原因。
   */
  finishReason: string;
  /**
   * 原始 JSON 字符串，供调试或日志使用。
   */
  rawJson: string;
}

/**
 * OpenAI 兼容格式的流式聊天块结构。
 */
export interface OpenAICompatibleChatChunk {
  /**
   * 候选结果列表。
   */
  choices: Array<OpenAICompatibleChatChoice>;
}

/**
 * OpenAI 兼容格式的单个候选结果。
 */
export interface OpenAICompatibleChatChoice {
  /**
   * 增量数据（可选，流式结束时可能不存在）。
   */
  delta?: OpenAICompatibleChatDelta;
  /**
   * 结束原因（可选，流式结束时提供）。
   */
  finish_reason?: string | null;
}

/**
 * OpenAI 兼容格式的增量数据，包含文本和推理内容。
 */
export interface OpenAICompatibleChatDelta {
  /**
   * 增量文本内容（可选）。
   */
  content?: string | null;
  /**
   * 增量推理内容（可选，支持推理的模型使用）。
   */
  reasoning_content?: string | null;
  /**
   * 增量推理内容（备用字段，某些后端使用）。
   */
  reasoning?: string | null;
}
