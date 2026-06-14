/**
 * 预设模块导出。
 * PresetRuntime：提供预设的 CRUD、按种类过滤、作用域绑定、版本迁移升级及导出/导入运行时能力。
 * 调用方（模型调用客户端、UI 配置界面）通过此模块管理模型调用参数预设的完整生命周期。
 * PresetModels：定义预设字段、创建/更新参数、记录、绑定关系及事件载荷的类型。
 * 类型用于描述预设配置的数据结构和事件通知格式。
 */
export { PresetRuntime } from './PresetRuntime';
export type {
  PresetBindingRecord,
  PresetBoundPayload,
  PresetCreateParams,
  PresetDeletedPayload,
  PresetEventPayload,
  PresetExportData,
  PresetField,
  PresetMigratedPayload,
  PresetRecord,
  PresetUpdateParams,
} from './PresetModels';
