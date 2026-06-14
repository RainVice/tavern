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
   * 所属聊天标识。
   */
  chatId: string;
  /**
   * 所属消息标识。
   */
  messageId: string;
  /**
   * 在同一条消息的候选回复列表中的索引位置。
   */
  index: number;
  /**
   * 候选回复的文本内容。
   */
  text: string;
  /**
   * 是否为当前激活的候选回复。
   */
  active: boolean;
  /**
   * 候选回复状态：complete / streaming / failed / interrupted。
   */
  state: string;
  /**
   * 失败或中断时的错误信息描述。
   */
  error: string;
  /**
   * 记录创建时间戳。
   */
  createdAt: number;
  /**
   * 记录最近一次更新时间戳。
   */
  updatedAt: number;
}

/**
 * 描述消息候选回复模块在运行时交换的数据结构。
 */
export interface SwipeStreamState {
  /**
   * 在同一条消息的候选回复列表中的索引位置。
   */
  index: number;
  /**
   * 候选回复状态：complete / streaming / failed / interrupted。
   */
  state: string;
  /**
   * 候选回复的文本内容。
   */
  text: string;
  /**
   * 失败或中断时的错误信息描述。
   */
  error: string;
}

/**
 * 描述消息候选回复事件发布时携带的数据结构。
 */
export interface SwipeChangedPayload {
  /**
   * 所属聊天标识。
   */
  chatId: string;
  /**
   * 所属消息标识。
   */
  messageId: string;
  /**
   * 被变更的候选回复索引。
   */
  swipeIndex: number;
  /**
   * 变更后的候选回复记录。
   */
  swipe: SwipeRecord;
}

/**
 * 描述消息候选回复被删除时事件发布携带的数据结构。
 */
export interface SwipeDeletedPayload {
  /**
   * 所属聊天标识。
   */
  chatId: string;
  /**
   * 所属消息标识。
   */
  messageId: string;
  /**
   * 被删除的候选回复索引。
   */
  swipeIndex: number;
}
