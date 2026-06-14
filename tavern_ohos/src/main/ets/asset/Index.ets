/**
 * 资源文件模块。
 * 导出 AssetRuntime 类及所有相关类型，提供资源文件的创建（导入）、读取、重命名、删除等全生命周期管理能力，
 * 维护内存索引并持久化到磁盘，通过事件总线发布变更通知，
 * 适用于角色头像、聊天背景、主题、音频等资源文件的管理和存储场景。
 */
export { AssetRuntime } from './AssetRuntime';
export type {
  AssetCreateParams,
  AssetDeletedPayload,
  AssetImportedPayload,
  AssetIndexData,
  AssetRecord,
  AssetRenamedPayload,
} from './AssetModels';
