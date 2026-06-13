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

export class TranslationRuntime {
  private events: EventBus;
  private entries: Map<string, TranslationEntry> = new Map<string, TranslationEntry>();
  private tasks: Map<string, TranslationTask> = new Map<string, TranslationTask>();
  private cache: Map<string, TranslationCacheEntry> = new Map<string, TranslationCacheEntry>();
  private strategies: Map<TranslationScope, TranslationStrategy> = new Map<TranslationScope, TranslationStrategy>();
  private entryCounter: number = 0;
  private taskCounter: number = 0;
  private maxCacheSize: number = DEFAULT_MAX_CACHE_SIZE;

  constructor(events: EventBus) {
    this.events = events;
  }

  // 设置翻译策略
  setStrategy(strategy: TranslationStrategy): void {
    const copy = this.copyStrategy(strategy);
    this.strategies.set(copy.scope, copy);
    const payload: TranslationStrategyUpdatedPayload = { strategy: this.copyStrategy(copy) };
    this.events.publish<TranslationStrategyUpdatedPayload>('translation.strategy.updated', payload);
  }

  // 获取翻译策略
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

  // 创建翻译条目
  createEntry(
    direction: TranslationDirection,
    languagePair: TranslationLanguagePair,
    sourceText: string,
  ): TranslationEntry {
    this.entryCounter += 1;
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

  // 完成翻译条目
  completeEntry(entryId: string, translatedText: string): TranslationEntry {
    const entry = this.requireEntry(entryId);
    entry.translatedText = translatedText;
    entry.status = 'completed';
    entry.updatedAt = Date.now();
    this.addToCache(entry.sourceText, entry.languagePair.sourceLanguage, entry.languagePair.targetLanguage, translatedText);
    return this.copyEntry(entry);
  }

  // 条目失败
  failEntry(entryId: string, error: string): TranslationEntry {
    const entry = this.requireEntry(entryId);
    entry.status = 'failed';
    entry.error = error;
    entry.updatedAt = Date.now();
    return this.copyEntry(entry);
  }

  // 获取条目
  getEntry(entryId: string): TranslationEntry {
    return this.copyEntry(this.requireEntry(entryId));
  }

  // 从缓存查找翻译
  findInCache(sourceText: string, sourceLanguage: string, targetLanguage: string): TranslationResult | undefined {
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

  // 添加到缓存
  addToCache(sourceText: string, sourceLanguage: string, targetLanguage: string, translatedText: string): void {
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

  // 创建翻译批处理任务
  createTask(entryIds: Array<string>, strategy: TranslationStrategy): TranslationTask {
    this.taskCounter += 1;
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

  // 更新任务进度
  updateTaskProgress(taskId: string, progress: number): TranslationTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running';
    task.updatedAt = Date.now();
    const payload: TranslationProgressPayload = { task: this.copyTask(task) };
    this.events.publish<TranslationProgressPayload>('translation.task.progress', payload);
    return this.copyTask(task);
  }

  // 完成任务
  completeTask(taskId: string): TranslationTask {
    const task = this.requireTask(taskId);
    task.status = 'completed';
    task.progress = 100;
    task.updatedAt = Date.now();
    const payload: TranslationCompletedPayload = { task: this.copyTask(task) };
    this.events.publish<TranslationCompletedPayload>('translation.task.completed', payload);
    return this.copyTask(task);
  }

  // 任务失败
  failTask(taskId: string, error: string): TranslationTask {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    const payload: TranslationFailedPayload = { task: this.copyTask(task) };
    this.events.publish<TranslationFailedPayload>('translation.task.failed', payload);
    return this.copyTask(task);
  }

  // 取消任务
  cancelTask(taskId: string): TranslationTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled';
    task.error = '已取消';
    task.updatedAt = Date.now();
    const payload: TranslationCancelledPayload = { task: this.copyTask(task) };
    this.events.publish<TranslationCancelledPayload>('translation.task.cancelled', payload);
    return this.copyTask(task);
  }

  // 获取任务
  getTask(taskId: string): TranslationTask {
    return this.copyTask(this.requireTask(taskId));
  }

  // 列出任务
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

  // 导入
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
      const key = this.cacheKey(entry.sourceText, entry.sourceLanguage, entry.targetLanguage);
      this.cache.set(key, entry);
    }
  }

  private cacheKey(sourceText: string, sourceLanguage: string, targetLanguage: string): string {
    return `${sourceLanguage}:${targetLanguage}:${sourceText}`;
  }

  private requireEntry(entryId: string): TranslationEntry {
    const entry = this.entries.get(entryId);
    if (entry === undefined) {
      throw new Error(`翻译条目未找到: ${entryId}`);
    }
    return entry;
  }

  private requireTask(taskId: string): TranslationTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`翻译任务未找到: ${taskId}`);
    }
    return task;
  }

  private copyLanguagePair(pair: TranslationLanguagePair): TranslationLanguagePair {
    return {
      sourceLanguage: pair.sourceLanguage,
      targetLanguage: pair.targetLanguage,
    };
  }

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

  private listCacheEntries(): Array<TranslationCacheEntry> {
    const result = new Array<TranslationCacheEntry>();
    const values = Array.from(this.cache.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyCacheEntry(values[index]));
    }
    return result;
  }

  private parseEntryCounter(entryId: string): number {
    if (!entryId.startsWith('trans-')) {
      return 0;
    }
    const parsed = Number(entryId.substring(6));
    return parsed > 0 ? parsed : 0;
  }
}
