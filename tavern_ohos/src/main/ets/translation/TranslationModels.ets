/**
 * 翻译方向：input 表示输入文本的翻译，output 表示输出文本的翻译。
 */
export type TranslationDirection = 'input' | 'output';

/**
 * 翻译语言对，包含源语言和目标语言。
 */
export interface TranslationLanguagePair {
  /**
   * 源语言代码。
   */
  sourceLanguage: string;
  /**
   * 目标语言代码。
   */
  targetLanguage: string;
}

/**
 * 翻译任务状态：pending（等待中）、running（进行中）、completed（已完成）、failed（失败）、cancelled（已取消）。
 */
export type TranslationTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

/**
 * 单条翻译条目，记录一次翻译请求的源文本、结果和状态。
 */
export interface TranslationEntry {
  /**
   * 条目唯一标识。
   */
  entryId: string;
  /**
   * 翻译方向。
   */
  direction: TranslationDirection;
  /**
   * 翻译语言对。
   */
  languagePair: TranslationLanguagePair;
  /**
   * 待翻译的源文本。
   */
  sourceText: string;
  /**
   * 翻译后的文本。
   */
  translatedText: string;
  /**
   * 翻译任务状态。
   */
  status: TranslationTaskStatus;
  /**
   * 翻译失败时的错误描述。
   */
  error: string;
  /**
   * 条目创建时间戳。
   */
  createdAt: number;
  /**
   * 条目最后更新时间戳。
   */
  updatedAt: number;
}

/**
 * 翻译策略配置，定义在特定作用域下的翻译行为。
 */
export interface TranslationStrategy {
  /**
   * 该策略是否已启用。
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
   * 是否保留原文。
   */
  preserveOriginal: boolean;
  /**
   * 策略适用的作用域。
   */
  scope: TranslationScope;
}

/**
 * 翻译作用域，决定翻译策略影响的范围。
 */
export type TranslationScope = 'message_input' | 'message_output' | 'prompt' | 'tts' | 'databank';

/**
 * 翻译缓存条目，存储已翻译过的文本对以加速后续翻译。
 */
export interface TranslationCacheEntry {
  /**
   * 源文本。
   */
  sourceText: string;
  /**
   * 源语言代码。
   */
  sourceLanguage: string;
  /**
   * 目标语言代码。
   */
  targetLanguage: string;
  /**
   * 已缓存的翻译结果。
   */
  translatedText: string;
  /**
   * 缓存条目的创建时间戳。
   */
  createdAt: number;
  /**
   * 缓存命中次数。
   */
  hitCount: number;
}

/**
 * 翻译任务，包含待翻译条目的引用和关联的策略。
 */
export interface TranslationTask {
  /**
   * 任务唯一标识。
   */
  taskId: string;
  /**
   * 该任务包含的条目标识列表。
   */
  entryIds: Array<string>;
  /**
   * 任务使用的翻译策略。
   */
  strategy: TranslationStrategy;
  /**
   * 任务状态。
   */
  status: TranslationTaskStatus;
  /**
   * 任务进度百分比（0-100）。
   */
  progress: number;
  /**
   * 任务失败时的错误描述。
   */
  error: string;
  /**
   * 任务创建时间戳。
   */
  createdAt: number;
  /**
   * 任务最后更新时间戳。
   */
  updatedAt: number;
}

/**
 * 单条文本的翻译结果。
 */
export interface TranslationResult {
  /**
   * 源文本。
   */
  sourceText: string;
  /**
   * 翻译后的文本。
   */
  translatedText: string;
  /**
   * 是否来自缓存。
   */
  fromCache: boolean;
}

/**
 * 缓存统计信息。
 */
export interface TranslationCacheStats {
  /**
   * 当前缓存中条目数量。
   */
  size: number;
  /**
   * 缓存容量的上限。
   */
  maxSize: number;
}

/**
 * 翻译任务启动事件发布时携带的负载。
 */
export interface TranslationStartedPayload {
  /**
   * 被启动的翻译任务。
   */
  task: TranslationTask;
}

/**
 * 翻译任务进度更新事件发布时携带的负载。
 */
export interface TranslationProgressPayload {
  /**
   * 进度已更新的翻译任务。
   */
  task: TranslationTask;
}

/**
 * 翻译任务完成事件发布时携带的负载。
 */
export interface TranslationCompletedPayload {
  /**
   * 已完成的翻译任务。
   */
  task: TranslationTask;
}

/**
 * 翻译任务失败事件发布时携带的负载。
 */
export interface TranslationFailedPayload {
  /**
   * 已失败的翻译任务。
   */
  task: TranslationTask;
}

/**
 * 翻译任务取消事件发布时携带的负载。
 */
export interface TranslationCancelledPayload {
  /**
   * 已取消的翻译任务。
   */
  task: TranslationTask;
}

/**
 * 缓存命中事件发布时携带的负载。
 */
export interface TranslationCacheHitPayload {
  /**
   * 被命中的缓存条目。
   */
  entry: TranslationCacheEntry;
}

/**
 * 翻译策略更新事件发布时携带的负载。
 */
export interface TranslationStrategyUpdatedPayload {
  /**
   * 更新后的翻译策略。
   */
  strategy: TranslationStrategy;
}

/**
 * 翻译数据的导出结构，包含所有策略、条目和缓存。
 */
export interface TranslationExportData {
  /**
   * 所有翻译策略列表。
   */
  strategies: Array<TranslationStrategy>;
  /**
   * 所有翻译条目列表。
   */
  entries: Array<TranslationEntry>;
  /**
   * 所有缓存条目列表。
   */
  cache: Array<TranslationCacheEntry>;
}
