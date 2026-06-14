/**
 * 连接配置模块统一导出入口。
 * 导出 ConnectionProfileRuntime（连接配置管理运行时）以及所有相关的数据结构和事件载荷类型，
 * 供 UI 层的配置管理页面和 Provider 运行时通过 import { ... } from './connection' 的方式统一引用。
 */
export { ConnectionProfileRuntime } from './ConnectionProfileRuntime';
export type {
  ConnectionActiveProfilePayload,
  ConnectionActiveProfileRecord,
  ConnectionHeaderRecord,
  ConnectionProfileCreateParams,
  ConnectionProfileDeletedPayload,
  ConnectionProfileEventPayload,
  ConnectionProfileRecord,
  ConnectionProfileUpdatedPayload,
  ConnectionProviderRequest,
  ConnectionResolvedProfile,
} from './ConnectionProfileModels';
