// 翻译方向
export type TranslationDirection = 'input' | 'output';

// 翻译语言对
export interface TranslationLanguagePair {
  /**
   * source Language 值，由当前实例内部维护。
   */
  sourceLanguage: string;
  /**
   * target Language 值，由当前实例内部维护。
   */
  targetLanguage: string;
}

// 翻译状态
export type TranslationTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// 翻译条目
export interface TranslationEntry {
  /**
   * 条目标识。
   */
  entryId: string;
  /**
   * direction 值，由当前实例内部维护。
   */
  direction: TranslationDirection;
  /**
   * language Pair 值，由当前实例内部维护。
   */
  languagePair: TranslationLanguagePair;
  /**
   * source Text 值，由当前实例内部维护。
   */
  sourceText: string;
  /**
   * translated Text 值，由当前实例内部维护。
   */
  translatedText: string;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: TranslationTaskStatus;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

// 翻译策略配置
export interface TranslationStrategy {
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * direction 值，由当前实例内部维护。
   */
  direction: TranslationDirection;
  /**
   * source Language 值，由当前实例内部维护。
   */
  sourceLanguage: string;
  /**
   * target Language 值，由当前实例内部维护。
   */
  targetLanguage: string;
  /**
   * preserve Original 值，由当前实例内部维护。
   */
  preserveOriginal: boolean;
  /**
   * 作用域。
   */
  scope: TranslationScope;
}

// 翻译作用域
export type TranslationScope = 'message_input' | 'message_output' | 'prompt' | 'tts' | 'databank';

// 翻译缓存条目
export interface TranslationCacheEntry {
  /**
   * source Text 值，由当前实例内部维护。
   */
  sourceText: string;
  /**
   * source Language 值，由当前实例内部维护。
   */
  sourceLanguage: string;
  /**
   * target Language 值，由当前实例内部维护。
   */
  targetLanguage: string;
  /**
   * translated Text 值，由当前实例内部维护。
   */
  translatedText: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * hit Count 值，由当前实例内部维护。
   */
  hitCount: number;
}

// 翻译任务
export interface TranslationTask {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * entry 标识列表。
   */
  entryIds: Array<string>;
  /**
   * strategy 值，由当前实例内部维护。
   */
  strategy: TranslationStrategy;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: TranslationTaskStatus;
  /**
   * progress 列表，由当前实例内部维护。
   */
  progress: number;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

// 翻译结果
export interface TranslationResult {
  /**
   * source Text 值，由当前实例内部维护。
   */
  sourceText: string;
  /**
   * translated Text 值，由当前实例内部维护。
   */
  translatedText: string;
  /**
   * from Cache 值，由当前实例内部维护。
   */
  fromCache: boolean;
}

/**
 * 描述翻译模块在运行时交换的数据结构。
 */
export interface TranslationCacheStats {
  /**
   * size 值，由当前实例内部维护。
   */
  size: number;
  /**
   * max Size 值，由当前实例内部维护。
   */
  maxSize: number;
}

// 事件 payload
export interface TranslationStartedPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TranslationTask;
}

/**
 * 描述翻译事件发布时携带的数据结构。
 */
export interface TranslationProgressPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TranslationTask;
}

/**
 * 描述翻译事件发布时携带的数据结构。
 */
export interface TranslationCompletedPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TranslationTask;
}

/**
 * 描述翻译事件发布时携带的数据结构。
 */
export interface TranslationFailedPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TranslationTask;
}

/**
 * 描述翻译事件发布时携带的数据结构。
 */
export interface TranslationCancelledPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TranslationTask;
}

/**
 * 描述翻译事件发布时携带的数据结构。
 */
export interface TranslationCacheHitPayload {
  /**
   * 条目记录，由当前实例内部维护。
   */
  entry: TranslationCacheEntry;
}

/**
 * 描述翻译事件发布时携带的数据结构。
 */
export interface TranslationStrategyUpdatedPayload {
  /**
   * strategy 值，由当前实例内部维护。
   */
  strategy: TranslationStrategy;
}

/**
 * 描述翻译模块在运行时交换的数据结构。
 */
export interface TranslationExportData {
  /**
   * strategies 列表，由当前实例内部维护。
   */
  strategies: Array<TranslationStrategy>;
  /**
   * 条目列表，由当前实例内部维护。
   */
  entries: Array<TranslationEntry>;
  /**
   * cache 值，由当前实例内部维护。
   */
  cache: Array<TranslationCacheEntry>;
}
