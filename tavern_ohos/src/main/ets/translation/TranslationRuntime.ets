import { EventBus } from '../runtime/EventBus';
import type {
  TranslationCacheEntry,
  TranslationCacheHitPayload,
  TranslationCacheStats,
  TranslationCancelledPayload,
  TranslationCompletedPayload,
  TranslationDirection,
  TranslationEntry,
  TranslationExportData,
  TranslationFailedPayload,
  TranslationLanguagePair,
  TranslationProgressPayload,
  TranslationResult,
  TranslationScope,
  TranslationStartedPayload,
  TranslationStrategy,
  TranslationStrategyUpdatedPayload,
  TranslationTask,
  TranslationTaskStatus,
} from './TranslationModels';

// 默认最大缓存大小
const DEFAULT_MAX_CACHE_SIZE = 1000;

/**
 * 提供翻译相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class TranslationRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 条目列表，由当前实例内部维护。
   */
  private entries: Map<string, TranslationEntry> = new Map<string, TranslationEntry>();
  /**
   * tasks 列表，由当前实例内部维护。
   */
  private tasks: Map<string, TranslationTask> = new Map<string, TranslationTask>();
  /**
   * cache 值，由当前实例内部维护。
   */
  private cache: Map<string, TranslationCacheEntry> = new Map<string, TranslationCacheEntry>();
  /**
   * strategies 列表，由当前实例内部维护。
   */
  private strategies: Map<TranslationScope, TranslationStrategy> = new Map<TranslationScope, TranslationStrategy>();
  /**
   * entry Counter 值，由当前实例内部维护。
   */
  private entryCounter: number = 0;
  /**
   * task Counter 值，由当前实例内部维护。
   */
  private taskCounter: number = 0;
  /**
   * max Cache Size 值，由当前实例内部维护。
   */
  private maxCacheSize: number = DEFAULT_MAX_CACHE_SIZE;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 设置翻译策略。
   * @param strategy 策略配置。
   */
  setStrategy(strategy: TranslationStrategy): void {
    const copy = this.copyStrategy(strategy);
    this.strategies.set(copy.scope, copy);
    const payload: TranslationStrategyUpdatedPayload = { strategy: this.copyStrategy(copy) };
    this.events.publish<TranslationStrategyUpdatedPayload>('translation.strategy.updated', payload);
  }

  /**
   * 读取指定Strategy，不存在时抛出错误。
   * @param scope 绑定或查询使用的作用域。
   * @returns 更新或读取后的记录副本。
   */
  getStrategy(scope: TranslationScope): TranslationStrategy | undefined {
    const strategy = this.strategies.get(scope);
    return strategy === undefined ? undefined : this.copyStrategy(strategy);
  }

  // 列出所有策略
  listStrategies(): Array<TranslationStrategy> {
    const result = new Array<TranslationStrategy>();
    const values = Array.from(this.strategies.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyStrategy(values[index]));
    }
    return result;
  }

  /**
   * 创建新的条目记录，写入存储并返回副本。



   * @returns 更新或读取后的记录副本。
   */
  createEntry(
    direction: TranslationDirection,
    languagePair: TranslationLanguagePair,
    sourceText: string,
  ): TranslationEntry {
    this.entryCounter += 1;
    // entry 标识。
    const entryId = `trans-${this.entryCounter}`;
    const now = Date.now();
    const entry: TranslationEntry = {
      entryId: entryId,
      direction: direction,
      languagePair: {
        sourceLanguage: languagePair.sourceLanguage,
        targetLanguage: languagePair.targetLanguage,
      },
      sourceText: sourceText,
      translatedText: '',
      status: 'pending',
      error: '',
      createdAt: now,
      updatedAt: now,
    };
    this.entries.set(entryId, this.copyEntry(entry));
    return this.copyEntry(entry);
  }

  /**
   * 标记Entry 值完成，并写入最终结果。
   * @param entryId 条目标识。
   */
  completeEntry(entryId: string, translatedText: string): TranslationEntry {
    const entry = this.requireEntry(entryId);
    entry.translatedText = translatedText;
    entry.status = 'completed';
    entry.updatedAt = Date.now();
    this.addToCache(entry.sourceText, entry.languagePair.sourceLanguage, entry.languagePair.targetLanguage, translatedText);
    return this.copyEntry(entry);
  }

  /**
   * 标记Entry 值失败，并保存错误信息。
   * @param entryId 条目标识。
   * @param error 错误信息。
   */
  failEntry(entryId: string, error: string): TranslationEntry {
    const entry = this.requireEntry(entryId);
    entry.status = 'failed';
    entry.error = error;
    entry.updatedAt = Date.now();
    return this.copyEntry(entry);
  }

  /**
   * 读取指定条目，不存在时抛出错误。
   * @param entryId 条目标识。
   * @returns 更新或读取后的记录副本。
   */
  getEntry(entryId: string): TranslationEntry {
    return this.copyEntry(this.requireEntry(entryId));
  }

  /**
   * 在当前集合中查找In Cache 值，未命中时返回空值或默认位置。
   */
  findInCache(sourceText: string, sourceLanguage: string, targetLanguage: string): TranslationResult | undefined {
    // 键名。
    const key = this.cacheKey(sourceText, sourceLanguage, targetLanguage);
    const cached = this.cache.get(key);
    if (cached === undefined) {
      return undefined;
    }
    cached.hitCount += 1;
    const payload: TranslationCacheHitPayload = { entry: this.copyCacheEntry(cached) };
    this.events.publish<TranslationCacheHitPayload>('translation.cache.hit', payload);
    return {
      sourceText: cached.sourceText,
      translatedText: cached.translatedText,
      fromCache: true,
    };
  }

  /**
   * 添加到缓存。
   * @param sourceText 源文本。
   * @param sourceLanguage 源语言。
   * @param targetLanguage 目标语言。
   * @param translatedText 译文文本。
   */
  addToCache(sourceText: string, sourceLanguage: string, targetLanguage: string, translatedText: string): void {
    // 键名。
    const key = this.cacheKey(sourceText, sourceLanguage, targetLanguage);
    const entry: TranslationCacheEntry = {
      sourceText: sourceText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      translatedText: translatedText,
      createdAt: Date.now(),
      hitCount: 0,
    };
    // 如果缓存已满，移除最旧的条目
    if (this.cache.size >= this.maxCacheSize) {
      const keys = Array.from(this.cache.keys());
      const oldestKey = keys[0];
      this.cache.delete(oldestKey);
    }
    this.cache.set(key, this.copyCacheEntry(entry));
  }

  // 清除缓存
  clearCache(): void {
    this.cache.clear();
  }

  // 获取缓存统计
  cacheStats(): TranslationCacheStats {
    const stats: TranslationCacheStats = {
      size: this.cache.size,
      maxSize: this.maxCacheSize,
    };
    return stats;
  }

  /**
   * 创建新的任务记录，写入存储并返回副本。
   * @param entryIds 目标条目标识列表。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  createTask(entryIds: Array<string>, strategy: TranslationStrategy): TranslationTask {
    this.taskCounter += 1;
    // task 标识。
    const taskId = `trans-task-${this.taskCounter}`;
    const now = Date.now();
    const task: TranslationTask = {
      taskId: taskId,
      entryIds: entryIds.slice(),
      strategy: this.copyStrategy(strategy),
      status: 'pending',
      progress: 0,
      error: '',
      createdAt: now,
      updatedAt: now,
    };
    this.tasks.set(taskId, this.copyTask(task));
    const payload: TranslationStartedPayload = { task: this.copyTask(task) };
    this.events.publish<TranslationStartedPayload>('translation.task.started', payload);
    return this.copyTask(task);
  }

  /**
   * 更新Task Progress 列表，同步内部状态并按需发布变更事件。
   * @param taskId 目标任务标识。

   * @returns 更新或读取后的记录副本。
   */
  updateTaskProgress(taskId: string, progress: number): TranslationTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running';
    task.updatedAt = Date.now();
    const payload: TranslationProgressPayload = { task: this.copyTask(task) };
    this.events.publish<TranslationProgressPayload>('translation.task.progress', payload);
    return this.copyTask(task);
  }

  /**
   * 标记Task 值完成，并写入最终结果。
   * @param taskId 目标任务标识。
   */
  completeTask(taskId: string): TranslationTask {
    const task = this.requireTask(taskId);
    task.status = 'completed';
    task.progress = 100;
    task.updatedAt = Date.now();
    const payload: TranslationCompletedPayload = { task: this.copyTask(task) };
    this.events.publish<TranslationCompletedPayload>('translation.task.completed', payload);
    return this.copyTask(task);
  }

  /**
   * 标记Task 值失败，并保存错误信息。
   * @param taskId 目标任务标识。
   * @param error 错误信息。
   */
  failTask(taskId: string, error: string): TranslationTask {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    const payload: TranslationFailedPayload = { task: this.copyTask(task) };
    this.events.publish<TranslationFailedPayload>('translation.task.failed', payload);
    return this.copyTask(task);
  }

  /**
   * 取消Task 值任务，并发布取消状态。
   * @param taskId 目标任务标识。
   */
  cancelTask(taskId: string): TranslationTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled';
    task.error = '已取消';
    task.updatedAt = Date.now();
    const payload: TranslationCancelledPayload = { task: this.copyTask(task) };
    this.events.publish<TranslationCancelledPayload>('translation.task.cancelled', payload);
    return this.copyTask(task);
  }

  /**
   * 读取指定任务，不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 更新或读取后的记录副本。
   */
  getTask(taskId: string): TranslationTask {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 读取Tasks列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param status 状态值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listTasks(status?: TranslationTaskStatus): Array<TranslationTask> {
    const result = new Array<TranslationTask>();
    const values = Array.from(this.tasks.values());
    for (let index = 0; index < values.length; index += 1) {
      if (status === undefined || values[index].status === status) {
        result.push(this.copyTask(values[index]));
      }
    }
    return result;
  }

  // 列出所有条目
  listEntries(): Array<TranslationEntry> {
    const result = new Array<TranslationEntry>();
    const values = Array.from(this.entries.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyEntry(values[index]));
    }
    return result;
  }

  // 导出
  exportData(): TranslationExportData {
    return {
      strategies: this.listStrategies(),
      entries: this.listEntries(),
      cache: this.listCacheEntries(),
    };
  }

  /**
   * 导入。
   * @param data 数据内容。
   */
  importData(data: TranslationExportData): void {
    for (let index = 0; index < data.strategies.length; index += 1) {
      const strategy = this.copyStrategy(data.strategies[index]);
      this.strategies.set(strategy.scope, strategy);
    }
    for (let index = 0; index < data.entries.length; index += 1) {
      const entry = this.copyEntry(data.entries[index]);
      this.entries.set(entry.entryId, entry);
      this.entryCounter = Math.max(this.entryCounter, this.parseEntryCounter(entry.entryId));
    }
    for (let index = 0; index < data.cache.length; index += 1) {
      const entry = this.copyCacheEntry(data.cache[index]);
      // 键名。
      const key = this.cacheKey(entry.sourceText, entry.sourceLanguage, entry.targetLanguage);
      this.cache.set(key, entry);
    }
  }
  private cacheKey(sourceText: string, sourceLanguage: string, targetLanguage: string): string {
    return `${sourceLanguage}:${targetLanguage}:${sourceText}`;
  }

  /**
   * 读取必须存在的Entry 值，缺失时抛出错误。
   * @param entryId 条目标识。
   */
  private requireEntry(entryId: string): TranslationEntry {
    const entry = this.entries.get(entryId);
    if (entry === undefined) {
      throw new Error(`翻译条目未找到: ${entryId}`);
    }
    return entry;
  }

  /**
   * 读取必须存在的Task 值，缺失时抛出错误。
   * @param taskId 目标任务标识。
   */
  private requireTask(taskId: string): TranslationTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`翻译任务未找到: ${taskId}`);
    }
    return task;
  }

  /**
   * 复制Language Pair 值，避免外部修改内部状态。
   */
  private copyLanguagePair(pair: TranslationLanguagePair): TranslationLanguagePair {
    return {
      sourceLanguage: pair.sourceLanguage,
      targetLanguage: pair.targetLanguage,
    };
  }

  /**
   * 复制Strategy 值，避免外部修改内部状态。
   */
  private copyStrategy(strategy: TranslationStrategy): TranslationStrategy {
    return {
      enabled: strategy.enabled,
      direction: strategy.direction,
      sourceLanguage: strategy.sourceLanguage,
      targetLanguage: strategy.targetLanguage,
      preserveOriginal: strategy.preserveOriginal,
      scope: strategy.scope,
    };
  }

  /**
   * 复制Entry 值，避免外部修改内部状态。
   * @param entry 条目记录。
   */
  private copyEntry(entry: TranslationEntry): TranslationEntry {
    return {
      entryId: entry.entryId,
      direction: entry.direction,
      languagePair: this.copyLanguagePair(entry.languagePair),
      sourceText: entry.sourceText,
      translatedText: entry.translatedText,
      status: entry.status,
      error: entry.error,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    };
  }

  /**
   * 复制Task 值，避免外部修改内部状态。
   */
  private copyTask(task: TranslationTask): TranslationTask {
    return {
      taskId: task.taskId,
      entryIds: task.entryIds.slice(),
      strategy: this.copyStrategy(task.strategy),
      status: task.status,
      progress: task.progress,
      error: task.error,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }

  /**
   * 复制Cache Entry 值，避免外部修改内部状态。
   * @param entry 条目记录。
   */
  private copyCacheEntry(entry: TranslationCacheEntry): TranslationCacheEntry {
    return {
      sourceText: entry.sourceText,
      sourceLanguage: entry.sourceLanguage,
      targetLanguage: entry.targetLanguage,
      translatedText: entry.translatedText,
      createdAt: entry.createdAt,
      hitCount: entry.hitCount,
    };
  }

  /**
   * 读取Cache条目列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private listCacheEntries(): Array<TranslationCacheEntry> {
    const result = new Array<TranslationCacheEntry>();
    const values = Array.from(this.cache.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyCacheEntry(values[index]));
    }
    return result;
  }

  /**
   * 解析条目Counter，非法输入会返回失败标记或空结果。
   * @param entryId 条目标识。
   */
  private parseEntryCounter(entryId: string): number {
    if (!entryId.startsWith('trans-')) {
      return 0;
    }
    const parsed = Number(entryId.substring(6));
    return parsed > 0 ? parsed : 0;
  }
}
