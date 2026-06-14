/**
 * 网络策略配置选项，控制策略开关、白名单及日志行为。
 * 用于 NetworkPolicyRuntime 在评估每个网络请求时决定如何判决--允许或阻断。
 */
export interface NetworkPolicyOptions {
  /**
   * 是否启用网络策略拦截，关闭时所有请求放行。
   * 用于在 evaluateHost 入口处跳过策略评估，直接返回允许判决。
   */
  enabled: boolean;
  /**
   * 私网地址白名单列表，命中白名单的私有地址仍允许访问。
   * 用于在 evaluateHost 中匹配私有 IP 是否在白名单内，避免误拦合法内网服务。
   */
  whitelist: Array<string>;
  /**
   * 是否允许访问未解析出的主机（DNS 解析失败）。
   * 用于在 evaluateHost 中处理 address 为空时的判决方向。
   */
  allowUnresolvedHosts: boolean;
  /**
   * 是否发布允许访问的事件。
   * 为 true 时 evaluateHost 在允许判决后发布 network.request.allowed 事件。
   */
  logAllowed?: boolean;
  /**
   * 是否发布拦截事件。
   * 为 true 时 evaluateHost 在阻断判决后发布 network.request.blocked 事件。
   */
  logBlocked?: boolean;
}

/**
 * 网络策略判决结果，包含目标主机、地址、是否允许及匹配规则信息。
 * 由 evaluateHost 返回给调用方，用于指示该网络请求是否应被放行。
 */
export interface NetworkPolicyDecision {
  /**
   * 被评估的目标主机名，由调用方传入 evaluateHost 的 host 参数。
   */
  host: string;
  /**
   * DNS 解析后的 IP 地址，由调用方传入 evaluateHost 的 address 参数。
   */
  address: string;
  /**
   * 是否允许访问，由 evaluateHost 根据策略配置判决得出。
   */
  allowed: boolean;
  /**
   * 判决的原因描述，如 disabled、public-address、private-address 等。
   */
  reason: string;
  /**
   * 命中的白名单或策略规则，空字符串表示未命中任何规则。
   */
  matchedRule: string;
}

/**
 * 网络请求允许通过时发布的事件载荷。
 * 在 evaluateHost 允许判决后且 logAllowed 为 true 时通过事件总线发布。
 */
export interface NetworkPolicyAllowedPayload {
  /**
   * 被允许的目标主机名。
   */
  host: string;
  /**
   * 解析后的 IP 地址。
   */
  address: string;
  /**
   * 允许的原因描述。
   */
  reason: string;
  /**
   * 命中的策略规则。
   */
  matchedRule: string;
}

/**
 * 网络请求被拦截时发布的事件载荷。
 * 在 evaluateHost 阻断判决后且 logBlocked 为 true 时通过事件总线发布。
 */
export interface NetworkPolicyBlockedPayload {
  /**
   * 被拦截的目标主机名。
   */
  host: string;
  /**
   * 解析后的 IP 地址。
   */
  address: string;
  /**
   * 拦截的原因描述。
   */
  reason: string;
  /**
   * 命中的策略规则。
   */
  matchedRule: string;
}
