import type { StreamSessionStatus } from '../contracts/PublicContracts';

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
   * 流式会话唯一标识。
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
   * 当前状态：running / completed / aborted。
   */
  status: StreamSessionStatus;
  /**
   * 已累积的消息内容快照。
   */
  snapshot: string;
  /**
   * 已累积的推理过程内容快照。
   */
  reasoningSnapshot: string;
  /**
   * 中止原因描述，仅在 status 为 aborted 时有意义。
   */
  abortReason: string;
  /**
   * 会话创建时间戳。
   */
  createdAt: number;
  /**
   * 会话最近一次更新时间戳。
   */
  updatedAt: number;
}

/**
 * 描述流式生成事件发布时携带的数据结构。
 */
export interface StreamStartPayload {
  /**
   * 启动时创建的流式会话对象。
   */
  session: StreamSession;
}

/**
 * 描述流式增量事件发布时携带的数据结构。
 */
export interface StreamDeltaPayload {
  /**
   * 所属流式会话标识。
   */
  sessionId: string;
  /**
   * 所属任务标识。
   */
  taskId: string;
  /**
   * 所属聊天标识。
   */
  chatId: string;
  /**
   * 所属消息标识。
   */
  messageId: string;
  /**
   * 本次增量文本片段。
   */
  delta: string;
  /**
   * 累积后的消息内容快照。
   */
  snapshot: string;
  /**
   * 是否为推理过程增量而非最终内容。
   */
  reasoning: boolean;
  /**
   * 累积后的推理过程内容快照。
   */
  reasoningSnapshot: string;
}

/**
 * 描述流式完成事件发布时携带的数据结构。
 */
export interface StreamCompletePayload {
  /**
   * 完成时的流式会话对象。
   */
  session: StreamSession;
}

/**
 * 描述流式中止事件发布时携带的数据结构。
 */
export interface StreamAbortPayload {
  /**
   * 中止时的流式会话对象。
   */
  session: StreamSession;
}
