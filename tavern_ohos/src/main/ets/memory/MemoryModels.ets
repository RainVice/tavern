/**
 * 描述聊天记忆持久化或内存索引中的一条记录。
 * 由 MemoryRuntime.createEntry 创建并存储于 entries 映射中，
 * 用于构建 AI 提示词注入文本（buildPromptInjection），
 * 或通过 exportData 导出以进行备份和数据迁移。
 */
export interface MemoryEntry {
  /**
   * 条目标识，格式为 "memory-{自增数字}"，由 createEntry 自动生成，用于后续的查询和删除操作。
   */
  entryId: string; chatId: string; summary: string; keyPoints: Array<string>;
  /**
   * 生成该记忆依据的原始消息列表，用于追溯记忆的来源或重新生成摘要。
   */
  originalMessages: Array<string>; tokenEstimate: number; createdAt: number; updatedAt: number;
}
/**
 * 描述调用聊天记忆能力时需要传入的参数。
 * 由外部调用方（如 UI 层或自动记忆提取流程）传递给记忆提取接口，
 * 用于指定从哪个聊天提取记忆以及提取的参数限制。
 */
export interface MemoryExtractParams {
  /**
   * 聊天标识，指定从哪个聊天会话中提取记忆，用于 Scope 记忆条目的过滤。
   */
  chatId: string; maxTokens: number; recentMessageCount: number;
}
/**
 * 描述聊天记忆操作完成后返回给调用方的结果。
 * 由记忆提取流程返回，调用方可根据 result 中的 entry 构建提示词注入文本，
* 或根据 truncatedMessages 了解哪些消息被截断。
 */
export interface MemoryExtractResult {
  /**
   * 提取到的聊天记忆条目，包含摘要、关键点和原始消息等完整信息，用于构建提示词注入或持久化存储。
   */
  entry: MemoryEntry; truncatedMessages: Array<string>;
}
/**
 * 描述聊天记忆事件发布时携带的数据结构。
 * MemoryRuntime 在 createEntry 完成后通过事件总线发布 memory.extracted 事件时使用此 payload，
 * 其他模块（如 UI 层自动保存）可通过监听该事件获取新生成的记忆条目。
 */
export interface MemoryExtractedPayload {
  /**
   * 已提取的记忆条目数据，包含摘要和关键点，供事件订阅者用于展示或持久化。
   */
  entry: MemoryEntry;
}
/**
 * 描述聊天记忆模块在运行时交换的数据结构。
 * 由 MemoryRuntime.exportData 返回，包含所有记忆条目，
 * 用于备份、与 SillyTavern 数据互通或跨设备迁移。
 */
export interface MemoryExportData {
  /**
   * 导出包含的所有记忆条目，每条记录了 chatId、摘要、关键点等完整信息，供导入方（importData）重建记忆状态。
   */
  entries: Array<MemoryEntry>;
}
