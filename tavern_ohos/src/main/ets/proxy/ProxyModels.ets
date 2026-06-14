import type { ProxyResolutionMode } from '../contracts/PublicContracts';

/**
 * 描述代理配置模块在运行时交换的数据结构。
 */
export interface ProxySettings {
  /**
   * 代理开关，是否启用代理功能。
   */
  enabled: boolean;
  /**
   * 代理服务器 URL 地址。
   */
  url: string;
  /**
   * 不走代理的直连域名列表。
   */
  bypass: Array<string>;
  /**
   * 是否开启 Keep Alive 长连接。
   */
  enableKeepAlive: boolean;
  /**
   * 是否启用私有请求过滤（仅过滤私有/内网地址的请求）。
   */
  privateRequestFilterEnabled: boolean;
}

/**
 * 描述代理配置持久化或内存索引中的一条记录。
 */
export interface ProxyResolutionRecord {
  /**
   * 目标 URL，需要解析代理的目标地址。
   */
  targetUrl: string;
  /**
   * 代理解析模式，如直接连接或通过代理连接。
   */
  mode: ProxyResolutionMode;
  /**
   * 代理服务器 URL（仅当 mode 为 proxy 时有效）。
   */
  proxyUrl: string;
  /**
   * 是否被直连规则命中而跳过代理。
   */
  bypassed: boolean;
  /**
   * 是否启用 Keep Alive 长连接。
   */
  keepAlive: boolean;
  /**
   * 代理解析结果的原因描述文本。
   */
  reason: string;
  /**
   * 解析过程中产生的警告信息。
   */
  warning: string;
}

/**
 * 描述代理配置事件发布时携带的数据结构。
 */
export interface ProxyConfiguredPayload {
  /**
   * 代理配置完成后的设置快照。
   */
  settings: ProxySettings;
}

/**
 * 描述代理已解析事件发布时携带的数据结构。
 */
export interface ProxyResolvedPayload {
  /**
   * 代理解析完成后的记录结果。
   */
  resolution: ProxyResolutionRecord;
}
