import { EventBus } from '../runtime/EventBus';
import type { CleanupCompletedPayload, CleanupReport, CleanupResult, CleanupStats } from './DataCleanupModels';

/**
 * 提供数据清理相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class DataCleanupRuntime {
  /**
   * 用于发布清理完成事件的事件总线实例。
   */
  private events: EventBus; private orphanFiles: Array<string>=new Array(); private corruptIndexes: Array<string>=new Array();
  /**
   * 初始化当前运行时实例。
   * @param events 用于发布事件的事件总线。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 记录一条孤儿文件路径，供后续 runCleanup 处理。
   * @param path 被认定为孤儿的文件或目录路径。
   */
  registerOrphanFile(path: string): void { this.orphanFiles.push(path); }
  /**
   * 记录一条损坏索引路径，供后续 runCleanup 处理。
   * @param path 被认定为损坏的索引文件路径。
   */
  registerCorruptIndex(path: string): void { this.corruptIndexes.push(path); }

  /**
   * 执行数据清理：汇总已注册的孤儿文件与损坏索引，将其包装为报告发布事件后返回。
   * @returns 包含清理报告与成功状态的 CleanupResult。
   */
  runCleanup(): CleanupResult {
    const report: CleanupReport = {
      orphanFiles: this.orphanFiles.slice(), corruptIndexes: this.corruptIndexes.slice(),
      staleTasks: new Array<string>(), totalRemoved: this.orphanFiles.length + this.corruptIndexes.length,
      errors: new Array<string>(),
    };
    this.orphanFiles = new Array<string>(); this.corruptIndexes = new Array<string>();
    this.events.publish<CleanupCompletedPayload>('datacleanup.completed', { report });
    return { report, success: true };
  }

  /**
   * 获取当前待处理的孤儿文件与损坏索引数量的快照。
   * @returns 包含 orphans 和 corrupt 计数的 CleanupStats。
   */
  getStats(): CleanupStats {
    const stats: CleanupStats = { orphans: this.orphanFiles.length, corrupt: this.corruptIndexes.length };
    return stats;
  }
}
