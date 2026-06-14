/**
 * 描述推理内容持久化或内存索引中的一条记录。
 */
export interface ReasoningRecord {
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * snapshot 值，由当前实例内部维护。
   */
  snapshot: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * signature 值，由当前实例内部维护。
   */
  signature: string;
  /**
   * visible 值，由当前实例内部维护。
   */
  visible: boolean;
  /**
   * include In Prompt 值，由当前实例内部维护。
   */
  includeInPrompt: boolean;
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
 * 描述推理内容事件发布时携带的数据结构。
 */
export interface ReasoningDeltaPayload {
  /**
   * reasoning 值，由当前实例内部维护。
   */
  reasoning: ReasoningRecord;
  /**
   * delta 值，由当前实例内部维护。
   */
  delta: string;
}

/**
 * 描述推理内容事件发布时携带的数据结构。
 */
export interface ReasoningUpdatedPayload {
  /**
   * reasoning 值，由当前实例内部维护。
   */
  reasoning: ReasoningRecord;
}
