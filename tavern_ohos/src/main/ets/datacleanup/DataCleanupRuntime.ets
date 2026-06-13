import { EventBus } from '../runtime/EventBus';
import type { CleanupCompletedPayload, CleanupReport, CleanupResult, CleanupStats } from './DataCleanupModels';

/**
 * 提供数据清理相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class DataCleanupRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private orphanFiles: Array<string>=new Array(); private corruptIndexes: Array<string>=new Array();
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 注册Orphan File 值，使其可被后续运行时流程使用。
   * @param path 目标文件或目录路径。
   */
  registerOrphanFile(path: string): void { this.orphanFiles.push(path); }
  /**
   * 注册Corrupt Index 值，使其可被后续运行时流程使用。
   * @param path 目标文件或目录路径。
   */
  registerCorruptIndex(path: string): void { this.corruptIndexes.push(path); }

  /**
   * 执行 runCleanup 的内部处理步骤，供当前模块复用。
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
   * 读取Stats 列表，不存在时通常抛出错误或返回空值。
   * @returns 更新或读取后的记录副本。
   */
  getStats(): CleanupStats {
    const stats: CleanupStats = { orphans: this.orphanFiles.length, corrupt: this.corruptIndexes.length };
    return stats;
  }
}
