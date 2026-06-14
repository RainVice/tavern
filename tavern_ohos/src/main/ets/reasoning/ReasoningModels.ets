/**
 * 标识指定消息的一条推理增量记录，包含当前累积的推理快照及相关元数据。
 */
export interface ReasoningRecord {
  /** 关联的消息 ID。 */
  messageId: string;
  /** 累积的推理内容文本。 */
  snapshot: string;
  /** 元数据 JSON 字符串，存储推理来源、配置等附加信息。 */
  metadataJson: string;
  /** 推理来源签名，用于标识产生该推理内容的模型或规则。 */
  signature: string;
  /** 控制对应推理内容在界面中是否可见。 */
  visible: boolean;
  /** 控制该推理内容是否作为上下文包含在对话提示词中。 */
  includeInPrompt: boolean;
  /** 记录创建的时间戳。 */
  createdAt: number;
  /** 记录最近一次更新的时间戳。 */
  updatedAt: number;
}

/**
 * 推理内容增量更新事件携带的数据，包含完整记录和本次增量文本。
 */
export interface ReasoningDeltaPayload {
  /** 受影响的推理记录副本。 */
  reasoning: ReasoningRecord;
  /** 本次累积的增量文本。 */
  delta: string;
}

/**
 * 推理内容全量更新事件携带的数据，包含更新后的完整记录副本。
 */
export interface ReasoningUpdatedPayload {
  /** 更新后的推理记录副本。 */
  reasoning: ReasoningRecord;
}
