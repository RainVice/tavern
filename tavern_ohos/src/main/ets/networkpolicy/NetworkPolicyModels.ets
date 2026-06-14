/**
 * 描述网络策略模块在运行时交换的数据结构。
 */
export interface NetworkPolicyOptions {
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * whitelist 值，由当前实例内部维护。
   */
  whitelist: Array<string>;
  /**
   * allow Unresolved Hosts 列表，由当前实例内部维护。
   */
  allowUnresolvedHosts: boolean;
  /**
   * log Allowed 值，由当前实例内部维护。
   */
  logAllowed?: boolean;
  /**
   * log Blocked 值，由当前实例内部维护。
   */
  logBlocked?: boolean;
}

/**
 * 描述网络策略模块在运行时交换的数据结构。
 */
export interface NetworkPolicyDecision {
  /**
   * host 值，由当前实例内部维护。
   */
  host: string;
  /**
   * address 列表，由当前实例内部维护。
   */
  address: string;
  /**
   * allowed 值，由当前实例内部维护。
   */
  allowed: boolean;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
  /**
   * matched Rule 值，由当前实例内部维护。
   */
  matchedRule: string;
}

/**
 * 描述网络策略事件发布时携带的数据结构。
 */
export interface NetworkPolicyAllowedPayload {
  /**
   * host 值，由当前实例内部维护。
   */
  host: string;
  /**
   * address 列表，由当前实例内部维护。
   */
  address: string;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
  /**
   * matched Rule 值，由当前实例内部维护。
   */
  matchedRule: string;
}

/**
 * 描述网络策略事件发布时携带的数据结构。
 */
export interface NetworkPolicyBlockedPayload {
  /**
   * host 值，由当前实例内部维护。
   */
  host: string;
  /**
   * address 列表，由当前实例内部维护。
   */
  address: string;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
  /**
   * matched Rule 值，由当前实例内部维护。
   */
  matchedRule: string;
}
