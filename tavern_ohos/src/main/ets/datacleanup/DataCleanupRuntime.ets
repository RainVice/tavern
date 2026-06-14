import { EventBus } from '../runtime/EventBus';
import type { CleanupCompletedPayload, CleanupReport, CleanupResult, CleanupStats } from './DataCleanupModels';

/**
 * 提供数据清理相关的无 UI 运行时能力，负责收集清理项、执行清理并发布结果。
 * 调用方通常是定时清理任务或用户触发的手动清理流程，通过本类收集系统中各模块上报的孤立文件和损坏索引并集中处理。
 */
export class DataCleanupRuntime {
  /** 事件总线，用于发布清理完成事件，通知订阅方（如 UI）刷新清理结果。 */
  private events: EventBus;
  /** 收集到的孤立文件路径列表，由外部模块通过 registerOrphanFile 上报，在 runCleanup 中被消费并清空。 */
  private orphanFiles: Array<string> = new Array();
  /** 收集到的损坏索引文件路径列表，由外部模块通过 registerCorruptIndex 上报，在 runCleanup 中被消费并清空。 */
  private corruptIndexes: Array<string> = new Array();

  /**
   * 初始化当前运行时实例。
   * @param events 用于发布清理事件的事件总线实例，供调用方在构造时传入。
   */
  constructor(events: EventBus) { this.events = events; }

  /**
   * 添加一个孤立文件路径到待清理列表。供外部模块（如文件系统扫描器）在发现未被索引引用的文件时调用。
   * @param path 孤立文件在文件系统中的路径，将在 runCleanup 时纳入清理报告。
   */
  registerOrphanFile(path: string): void { this.orphanFiles.push(path); }
  /**
   * 添加一个损坏索引文件路径到待清理列表。供外部模块（如索引校验器）在发现内容损坏的索引时调用。
   * @param path 损坏索引文件在文件系统中的路径，将在 runCleanup 时纳入清理报告。
   */
  registerCorruptIndex(path: string): void { this.corruptIndexes.push(path); }

  /**
   * 执行数据清理：生成报告，清空注册列表，发布清理完成事件。由触发清理的调用方（定时任务或用户操作）在清理项收集完毕后调用。
   * @returns 包含清理详细结果和成功状态的 CleanupResult。
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
   * 获取当前待清理数据的统计摘要，不修改状态。供 UI 在清理操作前展示预览信息。
   * @returns 包含孤立文件和损坏索引数量的统计信息。
   */
  getStats(): CleanupStats {
    const stats: CleanupStats = { orphans: this.orphanFiles.length, corrupt: this.corruptIndexes.length };
    return stats;
  }
}
