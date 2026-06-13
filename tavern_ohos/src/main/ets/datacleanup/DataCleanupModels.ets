/**
 * 描述数据清理模块在运行时交换的数据结构。
 */
export interface CleanupReport {
  /**
   * 孤儿文件列表。
   */
  orphanFiles: Array<string>;
  /**
   * 损坏索引列表。
   */
  corruptIndexes: Array<string>;
  /**
   * 过期任务列表。
   */
  staleTasks: Array<string>;
  /**
   * 移除总数。
   */
  totalRemoved: number;
  /**
   * 错误列表。
   */
  errors: Array<string>;
}
/**
 * 描述数据清理操作完成后返回给调用方的结果。
 */
export interface CleanupResult {
  /**
   * report 值，由当前实例内部维护。
   */
  report: CleanupReport;
  /**
   * 成功状态。
   */
  success: boolean;
}
/**
 * 描述数据清理事件发布时携带的数据结构。
 */
export interface CleanupCompletedPayload {
  /**
   * report 值，由当前实例内部维护。
   */
  report: CleanupReport;
}
/**
 * 描述数据清理模块在运行时交换的数据结构。
 */
export interface CleanupStats {
  /**
   * orphans 列表。
   */
  orphans: number;
  /**
   * corrupt 值，由当前实例内部维护。
   */
  corrupt: number;
}
