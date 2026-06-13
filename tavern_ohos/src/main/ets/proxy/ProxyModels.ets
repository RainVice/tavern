/**
 * 描述代理配置模块在运行时交换的数据结构。
 */
export interface ProxySettings {
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * url 值，由当前实例内部维护。
   */
  url: string;
  /**
   * bypass 列表，由当前实例内部维护。
   */
  bypass: Array<string>;
  /**
   * enable Keep Alive 值，由当前实例内部维护。
   */
  enableKeepAlive: boolean;
  /**
   * private Request Filter Enabled 值，由当前实例内部维护。
   */
  privateRequestFilterEnabled: boolean;
}

/**
 * 描述代理配置持久化或内存索引中的一条记录。
 */
export interface ProxyResolutionRecord {
  /**
   * target Url 值，由当前实例内部维护。
   */
  targetUrl: string;
  /**
   * mode 值，由当前实例内部维护。
   */
  mode: string;
  /**
   * proxy Url 值，由当前实例内部维护。
   */
  proxyUrl: string;
  /**
   * bypassed 值，由当前实例内部维护。
   */
  bypassed: boolean;
  /**
   * keep Alive 值，由当前实例内部维护。
   */
  keepAlive: boolean;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
  /**
   * warning 值，由当前实例内部维护。
   */
  warning: string;
}

/**
 * 描述代理配置事件发布时携带的数据结构。
 */
export interface ProxyConfiguredPayload {
  /**
   * settings 列表，由当前实例内部维护。
   */
  settings: ProxySettings;
}

/**
 * 描述代理配置事件发布时携带的数据结构。
 */
export interface ProxyResolvedPayload {
  /**
   * resolution 值，由当前实例内部维护。
   */
  resolution: ProxyResolutionRecord;
}
