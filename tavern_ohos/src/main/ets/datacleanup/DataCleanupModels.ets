/**
 * 描述数据清理模块在运行时交换的数据结构。
 */
export interface CleanupReport {
  /**
   * 在文件系统中找到但未被任何元数据引用的文件路径列表。
   */
  orphanFiles: Array<string>;
  /**
   * 索引文件已损坏、无法正常解析的路径列表。
   */
  corruptIndexes: Array<string>;
  /**
   * 因超时或资源被删除而不再有效的任务标识列表。
   */
  staleTasks: Array<string>;
  /**
   * 本次清理已移除的文件与记录总数。
   */
  totalRemoved: number;
  /**
   * 清理过程中遇到的错误信息列表。
   */
  errors: Array<string>;
}
/**
 * 描述数据清理操作完成后返回给调用方的结果。
 */
export interface CleanupResult {
  /**
   * 本次清理的详细报告。
   */
  report: CleanupReport;
  /**
   * 表示清理是否完全成功（无错误）。
   */
  success: boolean;
}
/**
 * 描述数据清理事件发布时携带的数据结构。
 */
export interface CleanupCompletedPayload {
  /**
   * 本次清理的详细报告。
   */
  report: CleanupReport;
}
/**
 * 描述数据清理运行时提供的当前状态快照。
 */
export interface CleanupStats {
  /**
   * 当前待处理的孤儿文件数量。
   */
  orphans: number;
  /**
   * 当前待处理的损坏索引数量。
   */
  corrupt: number;
}
