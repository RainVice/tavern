/**
 * 描述聊天记忆持久化或内存索引中的一条记录。
 */
export interface MemoryEntry {
  /**
   * 条目标识。
   */
  entryId: string; chatId: string; summary: string; keyPoints: Array<string>;
  /**
   * original Messages 列表，由当前实例内部维护。
   */
  originalMessages: Array<string>; tokenEstimate: number; createdAt: number; updatedAt: number;
}
/**
 * 描述调用聊天记忆能力时需要传入的参数。
 */
export interface MemoryExtractParams {
  /**
   * 聊天标识。
   */
  chatId: string; maxTokens: number; recentMessageCount: number;
}
/**
 * 描述聊天记忆操作完成后返回给调用方的结果。
 */
export interface MemoryExtractResult {
  /**
   * 条目记录，由当前实例内部维护。
   */
  entry: MemoryEntry; truncatedMessages: Array<string>;
}
/**
 * 描述聊天记忆事件发布时携带的数据结构。
 */
export interface MemoryExtractedPayload {
  /**
   * 条目数据。
   */
  entry: MemoryEntry;
}
/**
 * 描述聊天记忆模块在运行时交换的数据结构。
 */
export interface MemoryExportData {
  /**
   * 条目列表。
   */
  entries: Array<MemoryEntry>;
}
