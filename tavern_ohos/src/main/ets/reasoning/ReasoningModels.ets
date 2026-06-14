/**
 * 描述推理内容持久化或内存索引中的一条记录。
 */
export interface ReasoningRecord {
  /**
   * 关联的消息标识，用于将推理内容与具体 LLM 回复消息绑定。
   */
  messageId: string;
  /**
   * 推理内容的当前快照文本，随流式更新逐步累积——来自 LLM 流式输出的 reasoning_content 字段。
   */
  snapshot: string;
  /**
   * 关联的元数据 JSON 字符串，携带推理过程的额外属性（如模型返回的 usage 信息）。
   */
  metadataJson: string;
  /**
   * 推理签名，用于验证或标识推理内容来源——可能包含模型签名或数字证明。
   */
  signature: string;
  /**
   * 推理内容在 UI 中是否可见，用于控制用户是否能看到模型的思考过程。
   */
  visible: boolean;
  /**
   * 是否将该推理内容包含在发送给 LLM 的提示词中，用于多轮对话中传递前一轮的推理链。
   */
  includeInPrompt: boolean;
  /**
   * 推理记录创建时间戳（毫秒），用于排序和记录创建时机。
   */
  createdAt: number;
  /**
   * 推理记录最后更新时间戳（毫秒），用于追踪最后一次 delta 追加或编辑的时间。
   */
  updatedAt: number;
}

/**
 * 描述推理内容事件发布时携带的数据结构。
 */
export interface ReasoningDeltaPayload {
  /**
   * 增量更新后的推理记录副本，用于通知监听方（如 UI 渲染层）推理内容已追加新的片段。
   */
  reasoning: ReasoningRecord;
  /**
   * 本次新增的推理内容片段（delta），由 LLM 流式响应中的推理内容片段累积而来。
   */
  delta: string;
}

/**
 * 描述推理内容事件发布时携带的数据结构。
 */
export interface ReasoningUpdatedPayload {
  /**
   * 更新后的推理记录副本，用于通知监听方推理记录的元数据、可见性等属性已变更。
   */
  reasoning: ReasoningRecord;
}
