/**
 * 网络策略模块导出。
 * NetworkPolicyRuntime：提供 DNS 级别的网络请求策略评估（私网地址拦截、白名单放行、未解析主机策略）及事件发布能力。
 * 调用方（如 HTTP 客户端）在发起网络请求前通过此模块判决是否允许连接目标主机。
 * NetworkPolicyModels：定义网络策略选项、判决结果及其事件载荷的类型。
 * 类型用于描述策略配置、判决输出和事件通知格式。
 */
export { NetworkPolicyRuntime } from './NetworkPolicyRuntime';
export type {
  NetworkPolicyAllowedPayload,
  NetworkPolicyBlockedPayload,
  NetworkPolicyDecision,
  NetworkPolicyOptions,
} from './NetworkPolicyModels';
