/**
 * 描述代理配置模块在运行时交换的数据结构。
 */
export interface ProxySettings {
  /**
   * 是否启用代理，用于控制对外部 LLM API 的请求是否通过代理服务器发送。
   */
  enabled: boolean;
  /**
   * 代理服务器 URL 地址，指定所有代理请求的目标服务器。
   */
  url: string;
  /**
   * 绕过代理的目标主机列表，匹配的主机直连不经过代理——用于内部地址或特定服务免代理访问。
   */
  bypass: Array<string>;
  /**
   * 是否启用 HTTP Keep-Alive 连接复用，开启后可减少与代理服务器的 TCP 握手开销。
   */
  enableKeepAlive: boolean;
  /**
   * 是否启用私有请求过滤，开启时对内部地址的请求会触发警告，用于安全审计场景。
   */
  privateRequestFilterEnabled: boolean;
}

/**
 * 描述代理配置持久化或内存索引中的一条记录。
 */
export interface ProxyResolutionRecord {
  /**
   * 目标请求 URL，代理解析针对的原始请求地址。
   */
  targetUrl: string;
  /**
   * 代理解析模式：'direct'（直连）或 'proxy'（通过代理），决定请求的实际发送路径。
   */
  mode: string;
  /**
   * 实际使用的代理服务器 URL，mode 为 proxy 时有效。
   */
  proxyUrl: string;
  /**
   * 是否因 bypass 规则绕过代理，用于记录 bypass 匹配结果供调试和审计。
   */
  bypassed: boolean;
  /**
   * 是否启用 Keep-Alive 连接复用，记录最终连接配置供 HTTP 客户端使用。
   */
  keepAlive: boolean;
  /**
   * 代理解析的原因说明（如 disabled、missing-proxy-url、bypass 等），用于日志和调试追踪。
   */
  reason: string;
  /**
   * 代理解析的警告信息，无警告时为空字符串——如私有请求过滤被绕过时的安全提示。
   */
  warning: string;
}

/**
 * 描述代理配置事件发布时携带的数据结构。
 */
export interface ProxyConfiguredPayload {
  /**
   * 配置变更后的完整代理设置副本，用于通知监听方（如 UI 或网络模块）配置已更新。
   */
  settings: ProxySettings;
}

/**
 * 描述代理配置事件发布时携带的数据结构。
 */
export interface ProxyResolvedPayload {
  /**
   * 代理解析后的完整记录副本，用于通知监听方解析完成并携带路由决策详情。
   */
  resolution: ProxyResolutionRecord;
}
