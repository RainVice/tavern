/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderCapability {
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: string;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * supports Streaming 值，由当前实例内部维护。
   */
  supportsStreaming: boolean;
  /**
   * supports System Prompt 值，由当前实例内部维护。
   */
  supportsSystemPrompt: boolean;
  /**
   * supports Tools 列表，由当前实例内部维护。
   */
  supportsTools: boolean;
  /**
   * supports Reasoning 值，由当前实例内部维护。
   */
  supportsReasoning: boolean;
  /**
   * supports Vision Input 值，由当前实例内部维护。
   */
  supportsVisionInput: boolean;
  /**
   * supports Image Output 值，由当前实例内部维护。
   */
  supportsImageOutput: boolean;
  /**
   * supports Json Schema 值，由当前实例内部维护。
   */
  supportsJsonSchema: boolean;
  /**
   * supports Logprobs 列表，由当前实例内部维护。
   */
  supportsLogprobs: boolean;
  /**
   * supports Seed 值，由当前实例内部维护。
   */
  supportsSeed: boolean;
  /**
   * supports Stop Strings 列表，由当前实例内部维护。
   */
  supportsStopStrings: boolean;
  /**
   * supports Assistant Prefill 值，由当前实例内部维护。
   */
  supportsAssistantPrefill: boolean;
  /**
   * supports Text Completion 值，由当前实例内部维护。
   */
  supportsTextCompletion: boolean;
  /**
   * supports Chat Completion 值，由当前实例内部维护。
   */
  supportsChatCompletion: boolean;
  /**
   * max Context 值，由当前实例内部维护。
   */
  maxContext: number;
  /**
   * tokenizer 值，由当前实例内部维护。
   */
  tokenizer: string;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderChatMessage {
  /**
   * role 值，由当前实例内部维护。
   */
  role: string;
  /**
   * 内容。
   */
  content: string;
}

/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface ProviderStreamRequest {
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: string;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * 消息列表。
   */
  messages: Array<ProviderChatMessage>;
  /**
   * temperature 值，由当前实例内部维护。
   */
  temperature: number;
  /**
   * max Tokens 列表，由当前实例内部维护。
   */
  maxTokens: number;
  /**
   * stop 值，由当前实例内部维护。
   */
  stop: Array<string>;
  /**
   * stream 值，由当前实例内部维护。
   */
  stream: boolean;
}

/**
 * 描述调用Provider 请求能力时需要传入的参数。
 */
export interface ProviderTextCompletionBuildParams {
  /**
   * api Type 值，由当前实例内部维护。
   */
  apiType: string;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * temperature 值，由当前实例内部维护。
   */
  temperature: number;
  /**
   * max Tokens 列表，由当前实例内部维护。
   */
  maxTokens: number;
  /**
   * stop 值，由当前实例内部维护。
   */
  stop: Array<string>;
  /**
   * stream 值，由当前实例内部维护。
   */
  stream: boolean;
  /**
   * top P 值，由当前实例内部维护。
   */
  topP?: number;
  /**
   * presence Penalty 值，由当前实例内部维护。
   */
  presencePenalty?: number;
  /**
   * frequency Penalty 值，由当前实例内部维护。
   */
  frequencyPenalty?: number;
  /**
   * seed 值，由当前实例内部维护。
   */
  seed?: number;
}

/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface ProviderTextCompletionRequest {
  /**
   * api Type 值，由当前实例内部维护。
   */
  apiType: string;
  /**
   * 路径。
   */
  path: string;
  /**
   * body 值，由当前实例内部维护。
   */
  body: ProviderTextCompletionBody;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderTextCompletionBody {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * temperature 值，由当前实例内部维护。
   */
  temperature: number;
  /**
   * max tokens 列表，由当前实例内部维护。
   */
  max_tokens?: number;
  /**
   * max new tokens 列表，由当前实例内部维护。
   */
  max_new_tokens?: number;
  /**
   * num predict 值，由当前实例内部维护。
   */
  num_predict?: number;
  /**
   * stop 值，由当前实例内部维护。
   */
  stop: Array<string>;
  /**
   * stream 值，由当前实例内部维护。
   */
  stream: boolean;
  /**
   * top p 值，由当前实例内部维护。
   */
  top_p?: number;
  /**
   * presence penalty 值，由当前实例内部维护。
   */
  presence_penalty?: number;
  /**
   * frequency penalty 值，由当前实例内部维护。
   */
  frequency_penalty?: number;
  /**
   * seed 值，由当前实例内部维护。
   */
  seed?: number;
  /**
   * raw 值，由当前实例内部维护。
   */
  raw?: boolean;
  /**
   * 配置选项。
   */
  options?: ProviderTextCompletionOptions;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderTextCompletionOptions {
  /**
   * temperature 值，由当前实例内部维护。
   */
  temperature: number;
  /**
   * num predict 值，由当前实例内部维护。
   */
  num_predict: number;
  /**
   * stop 值，由当前实例内部维护。
   */
  stop: Array<string>;
  /**
   * top p 值，由当前实例内部维护。
   */
  top_p?: number;
  /**
   * presence penalty 值，由当前实例内部维护。
   */
  presence_penalty?: number;
  /**
   * frequency penalty 值，由当前实例内部维护。
   */
  frequency_penalty?: number;
  /**
   * seed 值，由当前实例内部维护。
   */
  seed?: number;
}

/**
 * 描述调用Provider 请求能力时需要传入的参数。
 */
export interface ProviderStreamStartParams {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * request 值，由当前实例内部维护。
   */
  request: ProviderStreamRequest;
  /**
   * 来源类型，由当前实例内部维护。
   */
  source: ProviderStreamSource;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderStreamHandle {
  /**
   * 执行 close 的内部处理步骤，供当前模块复用。
   */
  close(): void;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderStreamSink {
  /**
   * 执行 onChunk 的内部处理步骤，供当前模块复用。

   */
  onChunk(chunk: string): Promise<void>;
  /**
   * 执行 onError 的内部处理步骤，供当前模块复用。
   * @param message 消息记录。
   */
  onError(message: string): Promise<void>;
  /**
   * 执行 onDone 的内部处理步骤，供当前模块复用。
   */
  onDone(): Promise<void>;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderStreamSource {
  /**
   * 启动目标对象流程，并记录初始任务或会话状态。
   * @param request 待处理的请求对象。
   */
  start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle>;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderStreamTask {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * session 标识。
   */
  sessionId: string;
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: string;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: string;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
  /**
   * finish Reason 值，由当前实例内部维护。
   */
  finishReason: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述Provider 请求事件发布时携带的数据结构。
 */
export interface ProviderGenerationPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: ProviderStreamTask;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderSSEEvent {
  /**
   * event 值，由当前实例内部维护。
   */
  event: string;
  /**
   * 数据内容。
   */
  data: string;
  /**
   * 标识。
   */
  id: string;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderNormalizedChunk {
  /**
   * text Delta 值，由当前实例内部维护。
   */
  textDelta: string;
  /**
   * reasoning Delta 值，由当前实例内部维护。
   */
  reasoningDelta: string;
  /**
   * finish Reason 值，由当前实例内部维护。
   */
  finishReason: string;
  /**
   * raw JSON 字符串。
   */
  rawJson: string;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface OpenAICompatibleChatChunk {
  /**
   * choices 列表，由当前实例内部维护。
   */
  choices: Array<OpenAICompatibleChatChoice>;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface OpenAICompatibleChatChoice {
  /**
   * delta 值，由当前实例内部维护。
   */
  delta?: OpenAICompatibleChatDelta;
  /**
   * finish reason 值，由当前实例内部维护。
   */
  finish_reason?: string | null;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface OpenAICompatibleChatDelta {
  /**
   * 内容。
   */
  content?: string | null;
  /**
   * reasoning content 值，由当前实例内部维护。
   */
  reasoning_content?: string | null;
  /**
   * reasoning 值，由当前实例内部维护。
   */
  reasoning?: string | null;
}
