/**
 * 聊天记忆模块 - 提供聊天历史记忆的提取、存储和检索能力。
 * 支持记忆条目的创建、查询、删除、导出导入，并可将记忆构建为 AI 提示词注入文本。
 * 通过 MemoryRuntime 管理记忆生命周期并通过事件总线通知记忆提取事件。
 * 在 AI 回复生成前，记忆文本会被注入到提示词中以提供上下文连续性。
 */
export { MemoryRuntime } from './MemoryRuntime';
export type { MemoryEntry, MemoryExportData, MemoryExtractParams, MemoryExtractResult, MemoryExtractedPayload } from './MemoryModels';
