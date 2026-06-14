/**
 * tag 模块导出核心能力和类型。
 *
 * 提供标签运行时管理（TagRuntime）以及相关模型类型，
 * 包括创建参数、记录结构、导入结果和事件载荷。
 */
export { TagRuntime } from './TagRuntime';
export type {
  TagCreateParams,
  TagEventPayload,
  TagImportResult,
  TagMapEventPayload,
  TagRecord,
} from './TagModels';
