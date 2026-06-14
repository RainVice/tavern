/**
 * 权限审计模块导出。
 * PermissionRuntime：提供权限授予、检查、撤销、同意请求审批、文件/网络/Dangerous API 访问控制、插件崩溃隔离及审计日志等运行时能力。
 * 调用方（插件系统、文件 I/O、网络客户端等安全敏感组件）通过此模块执行权限校验和策略管理。
 * PermissionModels：定义权限授予参数、检查结果、同意请求、审计记录、策略记录及相关事件载荷的类型。
 * 类型用于描述整个权限系统的数据结构和事件通知格式。
 */
export { PermissionRuntime } from './PermissionRuntime';
export type {
  PermissionAuditRecord,
  PermissionCheckedPayload,
  PermissionCheckResult,
  PermissionConsentPayload,
  PermissionConsentRequest,
  PermissionGrantedPayload,
  PermissionGrantParams,
  PermissionGrantRecord,
  PermissionPolicyRecord,
} from './PermissionModels';
