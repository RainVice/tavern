/**
 * 描述调用消息候选回复能力时需要传入的参数。
 */
export interface SwipeCreateParams {
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * 文本内容。
   */
  text: string;
}

/**
 * 描述消息候选回复持久化或内存索引中的一条记录。
 */
export interface SwipeRecord {
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * 索引数据或循环位置，由当前实例内部维护。
   */
  index: number;
  /**
   * 文本内容。
   */
  text: string;
  /**
   * active 值，由当前实例内部维护。
   */
  active: boolean;
  /**
   * state 值，由当前实例内部维护。
   */
  state: string;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
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
 * 描述消息候选回复模块在运行时交换的数据结构。
 */
export interface SwipeStreamState {
  /**
   * 索引数据或循环位置，由当前实例内部维护。
   */
  index: number;
  /**
   * state 值，由当前实例内部维护。
   */
  state: string;
  /**
   * 文本内容。
   */
  text: string;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
}

/**
 * 描述消息候选回复事件发布时携带的数据结构。
 */
export interface SwipeChangedPayload {
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * swipe Index 值，由当前实例内部维护。
   */
  swipeIndex: number;
  /**
   * swipe 值，由当前实例内部维护。
   */
  swipe: SwipeRecord;
}

/**
 * 描述消息候选回复事件发布时携带的数据结构。
 */
export interface SwipeDeletedPayload {
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * swipe Index 值，由当前实例内部维护。
   */
  swipeIndex: number;
}
