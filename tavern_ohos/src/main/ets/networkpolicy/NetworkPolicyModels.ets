/**
 * 网络策略运行时的配置选项，控制策略开关、白名单及日志行为。
 */
export interface NetworkPolicyOptions {
  /**
   * 是否启用网络策略过滤。关闭后所有请求直接放行。
   */
  enabled: boolean;
  /**
   * 私网地址白名单列表，命中白名单的私有地址请求将被放行。
   */
  whitelist: Array<string>;
  /**
   * 是否放行 DNS 解析失败（未解析出地址）的请求。
   */
  allowUnresolvedHosts: boolean;
  /**
   * 是否在事件总线上发布「允许」事件。
   */
  logAllowed?: boolean;
  /**
   * 是否在事件总线上发布「阻断」事件。
   */
  logBlocked?: boolean;
}

/**
 * 网络策略评估结果，包含目标是否放行及其匹配的规则信息。
 */
export interface NetworkPolicyDecision {
  /**
   * 被评估的目标主机名。
   */
  host: string;
  /**
   * 解析后的 IP 地址。
   */
  address: string;
  /**
   * 是否允许访问。
   */
  allowed: boolean;
  /**
   * 决策原因描述，如 "public-address"、"whitelisted-private-address" 等。
   */
  reason: string;
  /**
   * 命中的白名单规则，无规则命中时为空字符串。
   */
  matchedRule: string;
}

/**
 * 网络策略「允许」事件发布时携带的载荷数据。
 */
export interface NetworkPolicyAllowedPayload {
  /**
   * 被评估的目标主机名。
   */
  host: string;
  /**
   * 解析后的 IP 地址。
   */
  address: string;
  /**
   * 放行的原因描述。
   */
  reason: string;
  /**
   * 命中的白名单规则，无规则命中时为空字符串。
   */
  matchedRule: string;
}

/**
 * 网络策略「阻断」事件发布时携带的载荷数据。
 */
export interface NetworkPolicyBlockedPayload {
  /**
   * 被评估的目标主机名。
   */
  host: string;
  /**
   * 解析后的 IP 地址。
   */
  address: string;
  /**
   * 阻断的原因描述。
   */
  reason: string;
  /**
   * 命中的白名单规则，无规则命中时为空字符串。
   */
  matchedRule: string;
}
