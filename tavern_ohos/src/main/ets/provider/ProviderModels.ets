/**
 * 声明一个 Provider 后端所支持的能力特性集合。
 */
export interface ProviderCapability {
  /** 后端名称标识，如 "openai-compatible"、"anthropic" 等。 */
  provider: string;
  /** 后端对应的默认模型名称。 */
  model: string;
  /** 是否支持流式输出。 */
  supportsStreaming: boolean;
  /** 是否支持系统提示词（System Prompt）。 */
  supportsSystemPrompt: boolean;
  /** 是否支持工具/函数调用。 */
  supportsTools: boolean;
  /** 是否支持推理过程输出（如思维链）。 */
  supportsReasoning: boolean;
  /** 是否支持视觉输入（图片理解）。 */
  supportsVisionInput: boolean;
  /** 是否支持图片输出（图片生成）。 */
  supportsImageOutput: boolean;
  /** 是否支持 JSON Schema 约束的输出格式。 */
  supportsJsonSchema: boolean;
  /** 是否支持返回对数概率（logprobs）。 */
  supportsLogprobs: boolean;
  /** 是否支持随机种子设定。 */
  supportsSeed: boolean;
  /** 是否支持停止字符串列表。 */
  supportsStopStrings: boolean;
  /** 是否支持助理预填充（Assistant Prefill）。 */
  supportsAssistantPrefill: boolean;
  /** 是否支持文本补全（非聊天形式的 Completion 接口）。 */
  supportsTextCompletion: boolean;
  /** 是否支持聊天补全（Chat Completion 接口）。 */
  supportsChatCompletion: boolean;
  /** 后端的最大上下文窗口大小（token 数）。 */
  maxContext: number;
  /** 后端使用的 tokenizer 名称，用于 token 计数。 */
  tokenizer: string;
}

/**
 * 聊天消息结构，包含角色和文本内容。
 */
export interface ProviderChatMessage {
  /** 消息角色：如 "user"、"assistant"、"system"。 */
  role: string;
  /** 消息文本内容。 */
  content: string;
}

/**
 * 流式聊天补全请求的结构，用于发送给外部 API 或网络层。
 */
export interface ProviderStreamRequest {
  /** 后端名称标识。 */
  provider: string;
  /** 请求使用的模型名称。 */
  model: string;
  /** 对话历史消息列表。 */
  messages: Array<ProviderChatMessage>;
  /** 采样温度参数（0~2），控制输出随机性。 */
  temperature: number;
  /** 生成的最大 token 数上限。 */
  maxTokens: number;
  /** 停止字符串列表，命中任意一个即停止生成。 */
  stop: Array<string>;
  /** 是否启用流式输出。 */
  stream: boolean;
}

/**
 * 文本补全（非聊天）接口的构建参数。
 */
export interface ProviderTextCompletionBuildParams {
  /** API 类型标识，如 "ollama"、"generic"、"dreamgen" 等，用于路由到不同的请求构建逻辑。 */
  apiType: string;
  /** 模型名称。 */
  model: string;
  /** 输入提示词文本。 */
  prompt: string;
  /** 采样温度参数。 */
  temperature: number;
  /** 生成的最大 token 数。 */
  maxTokens: number;
  /** 停止字符串列表。 */
  stop: Array<string>;
  /** 是否启用流式输出。 */
  stream: boolean;
  /** Top-P 采样参数，控制累积概率阈值。 */
  topP?: number;
  /** 存在惩罚系数，降低已出现 token 的重复概率。 */
  presencePenalty?: number;
  /** 频率惩罚系数，降低高频 token 的重复概率。 */
  frequencyPenalty?: number;
  /** 随机种子，用于可复现的生成结果。 */
  seed?: number;
}

/**
 * 文本补全请求的最终结构，包含 API 路由和请求体，准备发送给网络层。
 */
export interface ProviderTextCompletionRequest {
  /** API 类型标识。 */
  apiType: string;
  /** 请求路径。 */
  path: string;
  /** 请求体数据。 */
  body: ProviderTextCompletionBody;
}

/**
 * 文本补全的请求体（Body），包含多后端兼容的采样参数字段。
 */
export interface ProviderTextCompletionBody {
  /** 模型名称。 */
  model: string;
  /** 提示词文本。 */
  prompt: string;
  /** 温度参数。 */
  temperature: number;
  /** OpenAI 风格的最大 token 数。 */
  max_tokens?: number;
  /** Text Generation Inference 风格的最大 token 数。 */
  max_new_tokens?: number;
  /** Ollama 风格的预测 token 数。 */
  num_predict?: number;
  /** 停止字符串。 */
  stop: Array<string>;
  /** 是否流式输出。 */
  stream: boolean;
  /** Top-P 采样参数。 */
  top_p?: number;
  /** 存在惩罚系数。 */
  presence_penalty?: number;
  /** 频率惩罚系数。 */
  frequency_penalty?: number;
  /** 随机种子。 */
  seed?: number;
  /** Ollama 原始模式开关。 */
  raw?: boolean;
  /** Ollama 风格的采样选项对象。 */
  options?: ProviderTextCompletionOptions;
}

/**
 * Ollama 文本补全的采样选项子对象。
 */
export interface ProviderTextCompletionOptions {
  /** 温度参数。 */
  temperature: number;
  /** 预测 token 数。 */
  num_predict: number;
  /** 停止字符串。 */
  stop: Array<string>;
  /** Top-P 采样参数。 */
  top_p?: number;
  /** 存在惩罚系数。 */
  presence_penalty?: number;
  /** 频率惩罚系数。 */
  frequency_penalty?: number;
  /** 随机种子。 */
  seed?: number;
}

/**
 * 启动流式生成请求所需的参数集合。
 */
export interface ProviderStreamStartParams {
  /** 唯一任务标识。 */
  taskId: string;
  /** 所属聊天会话标识。 */
  chatId: string;
  /** 所属消息标识。 */
  messageId: string;
  /** 流式请求的完整参数。 */
  request: ProviderStreamRequest;
  /** 数据来源（如 OpenAI 兼容的流式请求源）。 */
  source: ProviderStreamSource;
}

/**
 * 流式请求的句柄，提供关闭/中止流的能力。
 */
export interface ProviderStreamHandle {
  /** 关闭当前流式请求，释放网络连接。 */
  close(): void;
}

/**
 * 流式数据的消费者，接收来自源端的流式数据块、错误和完成事件。
 */
export interface ProviderStreamSink {
  /** 处理接收到的原始数据块。 */
  onChunk(chunk: string): Promise<void>;
  /**
   * 处理流式请求过程中的错误。
   * @param message 错误描述信息。
   */
  onError(message: string): Promise<void>;
  /** 处理流式请求正常结束事件。 */
  onDone(): Promise<void>;
}

/**
 * 流式数据的来源，负责启动请求并将数据投递到 Sink。
 */
export interface ProviderStreamSource {
  /**
   * 启动流式请求，建立与后端的连接。
   * @param request 流式请求参数。
   * @param sink 数据消费者，接收流式事件。
   * @returns 流式句柄，可用于关闭请求。
   */
  start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle>;
}

/**
 * Provider 流式任务的状态记录，贯穿任务的整个生命周期。
 */
export interface ProviderStreamTask {
  /** 唯一任务标识。 */
  taskId: string;
  /** 所属 session 标识。 */
  sessionId: string;
  /** 所属聊天会话标识。 */
  chatId: string;
  /** 所属消息标识。 */
  messageId: string;
  /** 后端名称。 */
  provider: string;
  /** 使用的模型名称。 */
  model: string;
  /** 任务状态：running / completed / failed / aborted。 */
  status: string;
  /** 错误信息，仅 status 为 failed 或 aborted 时有意义。 */
  error: string;
  /** 结束原因，如 "stop"、"length"、"content_filter" 等。 */
  finishReason: string;
  /** 任务创建时间戳（毫秒）。 */
  createdAt: number;
  /** 任务最后更新时间戳（毫秒）。 */
  updatedAt: number;
}

/**
 * Provider 生成事件发布时携带的载荷。
 */
export interface ProviderGenerationPayload {
  /** 当前已完成/失败/中止的流式任务。 */
  task: ProviderStreamTask;
}

/**
 * 解析后的 SSE 事件数据结构。
 */
export interface ProviderSSEEvent {
  /** 事件类型名称，如 "message"、"error"、"ping"。 */
  event: string;
  /** 事件数据内容（JSON 字符串）。 */
  data: string;
  /** 事件标识（可选，来自 SSE 协议的 id 字段）。 */
  id: string;
}

/**
 * 归一化后的流式数据块，统一了不同后端输出的格式差异。
 */
export interface ProviderNormalizedChunk {
  /** 本次数据块中的文本增量。 */
  textDelta: string;
  /** 本次数据块中的推理过程增量（如思维链文本）。 */
  reasoningDelta: string;
  /** 结束原因，非空时表示生成已终止。 */
  finishReason: string;
  /** 原始 JSON 字符串，保留后端原始响应。 */
  rawJson: string;
}

/**
 * OpenAI 兼容格式的流式聊天补全 Chunk。
 */
export interface OpenAICompatibleChatChunk {
  /** 候选结果列表。 */
  choices: Array<OpenAICompatibleChatChoice>;
}

/**
 * OpenAI 兼容格式的单个候选结果。
 */
export interface OpenAICompatibleChatChoice {
  /** 增量数据（delta 模式）。 */
  delta?: OpenAICompatibleChatDelta;
  /** 结束原因。 */
  finish_reason?: string | null;
}

/**
 * OpenAI 兼容格式的增量数据，包含文本内容和推理内容。
 */
export interface OpenAICompatibleChatDelta {
  /** 文本增量内容。 */
  content?: string | null;
  /** 推理过程增量内容（DeepSeek/OpenAI 风格）。 */
  reasoning_content?: string | null;
  /** 推理过程增量内容（通用风格）。 */
  reasoning?: string | null;
}
