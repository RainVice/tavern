/**
 * 描述调用流式生成能力时需要传入的参数。
 */
export interface StreamStartParams {
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
}

/**
 * 描述流式生成模块在运行时交换的数据结构。
 */
export interface StreamSession {
  /**
   * 标识。
   */
  id: string;
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
   * 状态值，由当前实例内部维护。
   */
  status: string;
  /**
   * snapshot 值，由当前实例内部维护。
   */
  snapshot: string;
  /**
   * reasoning Snapshot 值，由当前实例内部维护。
   */
  reasoningSnapshot: string;
  /**
   * abort Reason 值，由当前实例内部维护。
   */
  abortReason: string;
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
 * 描述流式生成事件发布时携带的数据结构。
 */
export interface StreamStartPayload {
  /**
   * session 值，由当前实例内部维护。
   */
  session: StreamSession;
}

/**
 * 描述流式生成事件发布时携带的数据结构。
 */
export interface StreamDeltaPayload {
  /**
   * session 标识。
   */
  sessionId: string;
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
   * delta 值，由当前实例内部维护。
   */
  delta: string;
  /**
   * snapshot 值，由当前实例内部维护。
   */
  snapshot: string;
  /**
   * reasoning 值，由当前实例内部维护。
   */
  reasoning: boolean;
  /**
   * reasoning Snapshot 值，由当前实例内部维护。
   */
  reasoningSnapshot: string;
}

/**
 * 描述流式生成事件发布时携带的数据结构。
 */
export interface StreamCompletePayload {
  /**
   * session 值，由当前实例内部维护。
   */
  session: StreamSession;
}

/**
 * 描述流式生成事件发布时携带的数据结构。
 */
export interface StreamAbortPayload {
  /**
   * session 值，由当前实例内部维护。
   */
  session: StreamSession;
}
