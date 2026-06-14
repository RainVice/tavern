/**
 * 表示聊天记忆中单条持久化记录，包含摘要、关键点和原始消息等内容。
 */
export interface MemoryEntry {
  /** 条目标识。 */
  entryId: string;
  /** 关联的聊天会话标识。 */
  chatId: string;
  /** 对话内容摘要。 */
  summary: string;
  /** 提取的关键点列表。 */
  keyPoints: Array<string>;
  /** 生成该记忆依据的原始消息列表。 */
  originalMessages: Array<string>;
  /** 令牌数估算值。 */
  tokenEstimate: number;
  /** 创建时间戳（毫秒）。 */
  createdAt: number;
  /** 最后更新时间戳（毫秒）。 */
  updatedAt: number;
}
/**
 * 调用聊天记忆提取能力时需要传入的参数。
 */
export interface MemoryExtractParams {
  /** 目标聊天会话标识。 */
  chatId: string;
  /** 单次提取允许的最大令牌数。 */
  maxTokens: number;
  /** 提取时参考的最近消息条数。 */
  recentMessageCount: number;
}
/**
 * 聊天记忆提取操作完成后返回给调用方的结果。
 */
export interface MemoryExtractResult {
  /** 提取生成的记忆条目。 */
  entry: MemoryEntry;
  /** 因长度限制被截断的消息列表。 */
  truncatedMessages: Array<string>;
}
/**
 * 聊天记忆事件发布时携带的数据载荷。
 */
export interface MemoryExtractedPayload {
  /** 事件关联的记忆条目。 */
  entry: MemoryEntry;
}
/**
 * 聊天记忆模块在运行时导出或交换的数据结构。
 */
export interface MemoryExportData {
  /** 导出的条目列表。 */
  entries: Array<MemoryEntry>;
}
