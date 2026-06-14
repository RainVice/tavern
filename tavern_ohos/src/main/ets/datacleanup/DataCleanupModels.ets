/**
 * 数据清理完成后生成的报告，列出所有发现的问题类型和数量，由 runCleanup 生成并随事件发布给订阅方。
 */
export interface CleanupReport {
  /** 发现的无对应索引的孤立文件路径列表，这些文件占用了存储空间但未被任何模块引用。 */
  orphanFiles: Array<string>;
  /** 发现的内容损坏或格式错误的索引文件路径列表，这些文件需要修复或重建。 */
  corruptIndexes: Array<string>;
  /** 发现的已过期但未清理的任务记录列表，用于标记不再需要的陈旧任务痕迹。 */
  staleTasks: Array<string>;
  /** 本次清理移除的项目总数（= orphanFiles.length + corruptIndexes.length + staleTasks.length），用于统计清理量。 */
  totalRemoved: number;
  /** 清理过程中发生的错误信息列表，用于排查清理失败的环节。 */
  errors: Array<string>;
}
/**
 * 数据清理操作的最终返回结果，由 runCleanup 返回给调用方，包含详细报告和执行状态。
 */
export interface CleanupResult {
  /** 清理操作产生的详细报告，包含发现的各类问题和移除数量。 */
  report: CleanupReport;
  /** 清理是否成功完成，供调用方判断后续是否需要重试或告警。 */
  success: boolean;
}
/**
 * 数据清理完成后发布的事件负载，由 runCleanup 触发，供 UI 或其他模块接收清理结果。
 */
export interface CleanupCompletedPayload {
  /** 清理操作产生的详细报告，包含孤立文件、损坏索引和移除数量的统计。 */
  report: CleanupReport;
}
/**
 * 当前待清理数据的统计摘要，由 getStats 返回，供 UI 预览清理工作量。
 */
export interface CleanupStats {
  /** 孤立文件的数量，用于在 UI 中展示待清理的文件概览。 */
  orphans: number;
  /** 损坏索引的数量，用于在 UI 中展示待修复的索引概览。 */
  corrupt: number;
}
