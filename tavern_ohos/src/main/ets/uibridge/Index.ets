/**
 * uibridge 模块导出核心能力和类型。
 *
 * 提供 UI 桥接运行时管理（UIBridgeRuntime）以及相关模型类型，
 * 包括请求记录、响应结构和事件载荷。
 */
export { UIBridgeRuntime } from './UIBridgeRuntime';
export type {
  UIRequestEventPayload,
  UIRequestRecord,
  UIRequestResolvedPayload,
  UIRequestResponse,
} from './UIBridgeModels';
