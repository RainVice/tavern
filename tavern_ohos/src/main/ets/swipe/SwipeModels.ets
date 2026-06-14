/**
 * 描述调用消息候选回复能力时需要传入的参数。
 */
export interface SwipeCreateParams {
  /**
   * 聊天标识，用于将候选回复绑定到特定的聊天会话，在 SwipeRuntime 中作为 "chatId:messageId" 复合键的一部分。
   */
  chatId: string;
  /**
   * 消息标识，用于将候选回复关联到该消息下的不同回复变体，在 SwipeRuntime 中与 chatId 组合定位记录列表。
   */
  messageId: string;
  /**
   * 文本内容，作为候选回复的完整文本，在创建时直接写入 SwipeRecord 的 text 字段。
   */
  text: string;
}

/**
 * 描述消息候选回复持久化或内存索引中的一条记录。
 * 在消息的"重新生成/Swipe"流程中，一条消息可以有多个候选回复文本。
 */
export interface SwipeRecord {
  /**
   * 所属聊天的标识，用于在 SwipeRuntime 中与 messageId 组合为复合键定位记录列表。
   */
  chatId: string;
  /**
   * 所属消息的标识，用于确定该候选回复是哪个消息的替代版本。
   */
  messageId: string;
  /**
   * 当前候选回复在列表中的索引位置，由 SwipeRuntime 在创建或删除时重排，用于 UI 切换候选时的定位。
   */
  index: number;
  /**
   * 候选回复的文本内容，由模型生成或用户手动编辑，是切换候选回复时 UI 展示的完整文本。
   */
  text: string;
  /**
   * 是否为当前激活的候选回复，用户在 UI 上切换候选时由 switchSwipe 设置。
   */
  active: boolean;
  /**
   * 生成状态：complete / streaming / failed / interrupted，由流式生成流程驱动，供 UI 展示加载动画或错误提示。
   */
  state: string;
  /**
   * 生成失败时的错误信息，由 markFailed 记录，供日志排查和 UI 展示失败原因。
   */
  error: string;
  /**
   * 创建时间戳（毫秒），在 createSwipe 或 regenerateSwipe 时记录。
   */
  createdAt: number;
  /**
   * 最近更新时间戳（毫秒），在状态变更（编辑、切换、流式追加）时更新。
   */
  updatedAt: number;
}

/**
 * 描述消息候选回复模块在运行时交换的状态结构。
 * 提供候选回复的轻量级视图（不含完整记录的元数据），用于 UI 批量展示候选的生成进度状态。
 */
export interface SwipeStreamState {
  /**
   * 候选回复的索引位置，用于在 UI 列表中标识具体候选。
   */
  index: number;
  /**
   * 生成状态。
   */
  state: string;
  /**
   * 当前累积的文本内容。
   */
  text: string;
  /**
   * 错误信息。
   */
  error: string;
}

/**
 * 描述消息候选回复事件发布时携带的数据结构。
 * SwipeRuntime 在创建/切换/编辑/流式追加后发布 message.swipe.changed 事件，通知宿主 UI 更新候选展示。
 */
export interface SwipeChangedPayload {
  /**
   * 所属聊天的标识。
   */
  chatId: string;
  /**
   * 所属消息的标识。
   */
  messageId: string;
  /**
   * 变更的候选回复索引。
   */
  swipeIndex: number;
  /**
   * 变更后的候选回复记录。
   */
  swipe: SwipeRecord;
}

/**
 * 描述消息候选回复删除事件发布时携带的数据结构。
 * SwipeRuntime 在 deleteSwipe 后发布 message.swipe.deleted 事件，通知宿主 UI 移除对应的候选。
 */
export interface SwipeDeletedPayload {
  /**
   * 所属聊天的标识。
   */
  chatId: string;
  /**
   * 所属消息的标识。
   */
  messageId: string;
  /**
   * 被删除的候选回复索引。
   */
  swipeIndex: number;
}
