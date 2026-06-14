/**
 * translation 模块导出核心能力和类型。
 *
 * 提供翻译运行时管理（TranslationRuntime）以及丰富的模型类型，
 * 包括策略配置、条目管理、任务跟踪、缓存和事件载荷。
 */
export { TranslationRuntime } from './TranslationRuntime';
export type {
  TranslationCacheEntry,
  TranslationCacheHitPayload,
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
