// 翻译方向
export type TranslationDirection = 'input' | 'output';

// 翻译语言对
export interface TranslationLanguagePair {
  sourceLanguage: string;
  targetLanguage: string;
}

// 翻译状态
export type TranslationTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// 翻译条目
export interface TranslationEntry {
  entryId: string;
  direction: TranslationDirection;
  languagePair: TranslationLanguagePair;
  sourceText: string;
  translatedText: string;
  status: TranslationTaskStatus;
  error: string;
  createdAt: number;
  updatedAt: number;
}

// 翻译策略配置
export interface TranslationStrategy {
  enabled: boolean;
  direction: TranslationDirection;
  sourceLanguage: string;
  targetLanguage: string;
  preserveOriginal: boolean;
  scope: TranslationScope;
}

// 翻译作用域
export type TranslationScope = 'message_input' | 'message_output' | 'prompt' | 'tts' | 'databank';

// 翻译缓存条目
export interface TranslationCacheEntry {
  sourceText: string;
  sourceLanguage: string;
  targetLanguage: string;
  translatedText: string;
  createdAt: number;
  hitCount: number;
}

// 翻译任务
export interface TranslationTask {
  taskId: string;
  entryIds: Array<string>;
  strategy: TranslationStrategy;
  status: TranslationTaskStatus;
  progress: number;
  error: string;
  createdAt: number;
  updatedAt: number;
}

// 翻译结果
export interface TranslationResult {
  sourceText: string;
  translatedText: string;
  fromCache: boolean;
}

export interface TranslationCacheStats {
  size: number;
  maxSize: number;
}

// 事件 payload
export interface TranslationStartedPayload {
  task: TranslationTask;
}

export interface TranslationProgressPayload {
  task: TranslationTask;
}

export interface TranslationCompletedPayload {
  task: TranslationTask;
}

export interface TranslationFailedPayload {
  task: TranslationTask;
}

export interface TranslationCancelledPayload {
  task: TranslationTask;
}

export interface TranslationCacheHitPayload {
  entry: TranslationCacheEntry;
}

export interface TranslationStrategyUpdatedPayload {
  strategy: TranslationStrategy;
}

export interface TranslationExportData {
  strategies: Array<TranslationStrategy>;
  entries: Array<TranslationEntry>;
  cache: Array<TranslationCacheEntry>;
}
