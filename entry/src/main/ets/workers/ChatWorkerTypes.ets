/** 主线程发送给 ChatWorker 的请求类型。 */
export enum ChatRequestType {
  /** 请求模型生成回复。 */
  Request,
}

/** ChatWorker 回传给主线程的响应类型。 */
export enum ChatResponseType {
  /** worker 已收到请求，主线程可保持发送中状态。 */
  Started,
  /** 模型返回了一段增量文本。 */
  Response,
  /** 模型流式响应结束。 */
  Completed,
  /** 发送、请求或解析过程中出现错误。 */
  Error,
}

/** OpenAI Chat Completions 支持的基础消息角色。 */
export type ChatWorkerMessageRole = 'system' | 'developer' | 'user' | 'assistant';

/** 发送给模型的单条上下文消息。 */
export interface ChatWorkerMessage {
  role: ChatWorkerMessageRole;
  content: string;
}

/** 发起模型请求所需的最小提供商配置。 */
export interface ChatWorkerProviderConfig {
  apiKey: string;
  baseUrl: string;
  model: string;
}

/** 主线程发送给 ChatWorker 的完整请求。 */
export interface ChatRequest {
  type: ChatRequestType;
  /** 用于在异步回包时对应本次发送。 */
  requestId: string;
  /** 当前页面已有对话上下文，包含本次用户消息。 */
  history: ChatWorkerMessage[];
  /** 允许为空，由 worker 返回配置缺失错误。 */
  provider?: ChatWorkerProviderConfig;
}

/** ChatWorker 返回给主线程的响应。 */
export interface ChatResponse {
  type: ChatResponseType;
  requestId: string;
  /** Response 响应的增量文本内容。 */
  content?: string;
  /** Error 事件的错误信息。 */
  error?: string;
}
