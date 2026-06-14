// 翻译方向：input 表示从用户语言翻到目标语言，output 表示从目标语言翻回用户语言
export type TranslationDirection = 'input' | 'output';

// 翻译语言对
export interface TranslationLanguagePair {
  /**
   * 源语言代码（如 "zh-CN"），标识待翻译文本的原始语言。
   */
  sourceLanguage: string;
  /**
   * 目标语言代码（如 "en"），标识翻译后的目标语言。
   */
  targetLanguage: string;
}

// 翻译状态
export type TranslationTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// 翻译条目
export interface TranslationEntry {
  /**
   * 条目标识，由 createEntry 自动生成（格式为 "trans-{计数器}"）。
   */
  entryId: string;
  /**
   * 翻译方向（input / output），决定翻译流程的源语言和目标语言的解释方式。
   */
  direction: TranslationDirection;
  /**
   * 翻译语言对，包含源语言和目标语言代码。
   */
  languagePair: TranslationLanguagePair;
  /**
   * 源文本内容，待翻译的原始文本。
   */
  sourceText: string;
  /**
   * 翻译后的文本，由 completeEntry 在翻译完成后写入。
   */
  translatedText: string;
  /**
   * 翻译状态，由 createEntry(初始 pending) -> running -> completed/failed/cancelled 流转。
   */
  status: TranslationTaskStatus;
  /**
   * 错误信息，由 failEntry 在翻译失败时记录。
   */
  error: string;
  /**
   * 创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 最近更新时间戳（毫秒）。
   */
  updatedAt: number;
}

// 翻译策略配置
export interface TranslationStrategy {
  /**
   * 是否启用该策略，影响翻译流程是否会处理对应作用域的内容。
   */
  enabled: boolean;
  /**
   * 翻译方向。
   */
  direction: TranslationDirection;
  /**
   * 源语言代码。
   */
  sourceLanguage: string;
  /**
   * 目标语言代码。
   */
  targetLanguage: string;
  /**
   * 是否保留原文，影响翻译结果中是否同时包含原文和译文。
   */
  preserveOriginal: boolean;
  /**
   * 作用域（如 message_input / message_output），确定翻译策略应用于哪个业务场景。
   */
  scope: TranslationScope;
}

// 翻译作用域
export type TranslationScope = 'message_input' | 'message_output' | 'prompt' | 'tts' | 'databank';

// 翻译缓存条目
export interface TranslationCacheEntry {
  /**
   * 缓存的源文本，作为缓存键的一部分用于查找。
   */
  sourceText: string;
  /**
   * 缓存的源语言，作为缓存键的一部分。
   */
  sourceLanguage: string;
  /**
   * 缓存的目标语言，作为缓存键的一部分。
   */
  targetLanguage: string;
  /**
   * 缓存的译文，命中缓存时直接返回无需重新翻译。
   */
  translatedText: string;
  /**
   * 缓存创建时间戳。
   */
  createdAt: number;
  /**
   * 命中次数，用于缓存使用统计。
   */
  hitCount: number;
}

// 翻译任务
export interface TranslationTask {
  /**
   * 任务标识，由 createTask 自动生成（格式为 "trans-task-{计数器}"）。
   */
  taskId: string;
  /**
   * 关联的条目 ID 列表，一组需要翻译的条目。
   */
  entryIds: Array<string>;
  /**
   * 翻译策略配置，决定了翻译的语言方向和方式。
   */
  strategy: TranslationStrategy;
  /**
   * 任务状态，由 createTask(初始 pending) -> running -> completed/failed/cancelled 流转。
   */
  status: TranslationTaskStatus;
  /**
   * 进度百分比（0-100），由 updateTaskProgress 更新，供 UI 展示进度条。
   */
  progress: number;
  /**
   * 错误信息。
   */
  error: string;
  /**
   * 创建时间戳。
   */
  createdAt: number;
  /**
   * 最近更新时间戳。
   */
  updatedAt: number;
}

// 翻译结果
export interface TranslationResult {
  /**
   * 源文本。
   */
  sourceText: string;
  /**
   * 译文文本。
   */
  translatedText: string;
  /**
   * 是否来自缓存，true 表示命中缓存未实际发起翻译请求。
   */
  fromCache: boolean;
}

/**
 * 描述翻译缓存统计数据。
 */
export interface TranslationCacheStats {
  /**
   * 当前缓存条目数。
   */
  size: number;
  /**
   * 缓存最大容量。
   */
  maxSize: number;
}

// 事件 payload
export interface TranslationStartedPayload {
  /**
   * 已启动的翻译任务。
   */
  task: TranslationTask;
}

/**
 * 描述翻译进度事件发布时携带的数据结构。
 * TranslationRuntime 在 updateTaskProgress 后发布 translation.task.progress 事件。
 */
export interface TranslationProgressPayload {
  /**
   * 当前翻译任务。
   */
  task: TranslationTask;
}

/**
 * 描述翻译完成事件发布时携带的数据结构。
 * TranslationRuntime 在 completeTask 后发布 translation.task.completed 事件。
 */
export interface TranslationCompletedPayload {
  /**
   * 已完成的翻译任务。
   */
  task: TranslationTask;
}

/**
 * 描述翻译失败事件发布时携带的数据结构。
 * TranslationRuntime 在 failTask 后发布 translation.task.failed 事件。
 */
export interface TranslationFailedPayload {
  /**
   * 失败的翻译任务。
   */
  task: TranslationTask;
}

/**
 * 描述翻译取消事件发布时携带的数据结构。
 * TranslationRuntime 在 cancelTask 后发布 translation.task.cancelled 事件。
 */
export interface TranslationCancelledPayload {
  /**
   * 被取消的翻译任务。
   */
  task: TranslationTask;
}

/**
 * 描述翻译缓存命中事件发布时携带的数据结构。
 * TranslationRuntime 在 findInCache 命中缓存后发布 translation.cache.hit 事件。
 */
export interface TranslationCacheHitPayload {
  /**
   * 命中的缓存条目。
   */
  entry: TranslationCacheEntry;
}

/**
 * 描述翻译策略更新事件发布时携带的数据结构。
 * TranslationRuntime 在 setStrategy 后发布 translation.strategy.updated 事件。
 */
export interface TranslationStrategyUpdatedPayload {
  /**
   * 更新后的策略。
   */
  strategy: TranslationStrategy;
}

/**
 * 描述翻译导出数据的结构。
 * 在 exportData 和 importData 流程中使用，包含策略、条目和缓存的完整数据。
 */
export interface TranslationExportData {
  /**
   * 所有翻译策略。
   */
  strategies: Array<TranslationStrategy>;
  /**
   * 所有翻译条目。
   */
  entries: Array<TranslationEntry>;
  /**
   * 翻译缓存条目。
   */
  cache: Array<TranslationCacheEntry>;
}
