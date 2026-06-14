/**
 * thumbnail 模块导出核心能力和类型。
 *
 * 提供缩略图运行时管理（ThumbnailRuntime）以及相关模型类型，
 * 包括创建参数、维度配置、索引数据和事件载荷。
 */
export { ThumbnailRuntime } from './ThumbnailRuntime';
export type {
  ThumbnailCreateParams,
  ThumbnailDimensions,
  ThumbnailGeneratedPayload,
  ThumbnailIndexData,
  ThumbnailInvalidatedPayload,
  ThumbnailRecord,
} from './ThumbnailModels';
