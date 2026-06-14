import { EventBus } from '../runtime/EventBus';
import type {
  ProxyConfiguredPayload,
  ProxyResolutionRecord,
  ProxyResolvedPayload,
  ProxySettings,
} from './ProxyModels';

/**
 * 提供代理配置相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ProxyRuntime {
  /**
   * 事件总线，用于发布代理配置变更和解析完成事件。
   */
  private events: EventBus;
  private settings: ProxySettings = {
    enabled: false,
    url: '',
    bypass: new Array<string>(),
    enableKeepAlive: false,
    privateRequestFilterEnabled: false,
  };

  /**
   * 初始化当前运行时实例，设置默认禁用代理配置。
   * @param events 事件总线实例，用于发布 proxy.configured 和 proxy.resolved 事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 应用代理配置，更新内部设置并发布配置变更事件。由 UI 配置页面在用户保存代理设置时调用。
   * @param settings 新的代理配置参数，将替换运行时内部配置并通知监听方。
   */
  configure(settings: ProxySettings): ProxySettings {
    this.settings = this.cloneSettings(settings);
    const payload: ProxyConfiguredPayload = {
      settings: this.cloneSettings(this.settings),
    };
    this.events.publish<ProxyConfiguredPayload>('proxy.configured', payload);
    return this.cloneSettings(this.settings);
  }

  /**
   * 获取当前代理配置的深拷贝。由网络请求模块在发送 HTTP 请求前调用以获取代理信息。
   * @returns 当前代理设置副本。
   */
  getSettings(): ProxySettings {
    return this.cloneSettings(this.settings);
  }

  /**
   * 根据当前代理配置解析目标 URL，决定直连还是走代理，并发布解析结果事件。
   * 依次检查：代理是否启用、代理 URL 是否配置、URL 格式是否合法、是否命中 bypass 规则。
   * 在网络请求发送前由 HTTP 客户端或请求调度模块调用。
   */
  resolve(targetUrl: string): ProxyResolutionRecord {
    let resolution: ProxyResolutionRecord;
    if (!this.settings.enabled) {
      resolution = this.makeResolution(targetUrl, 'direct', '', false, false, 'disabled', '');
      return this.publishResolved(resolution);
    }

    if (this.settings.url.length === 0) {
      resolution = this.makeResolution(targetUrl, 'direct', '', false, false, 'missing-proxy-url', '');
      return this.publishResolved(resolution);
    }

    if (!this.isValidUrl(this.settings.url)) {
      resolution = this.makeResolution(targetUrl, 'direct', '', false, false, 'invalid-proxy-url', '');
      return this.publishResolved(resolution);
    }

    if (this.matchesBypass(targetUrl)) {
      resolution = this.makeResolution(targetUrl, 'direct', '', true, false, 'bypass', '');
      return this.publishResolved(resolution);
    }
    const warning = this.settings.privateRequestFilterEnabled ? 'private-request-filter-bypassed' : '';
    resolution = this.makeResolution(
      targetUrl,
      'proxy',
      this.settings.url,
      false,
      this.settings.enableKeepAlive,
      'proxy-enabled',
      warning,
    );
    return this.publishResolved(resolution);
  }

  /**
   * 发布代理配置事件，把状态变化通知给宿主或其他 Runtime。
   */
  private publishResolved(resolution: ProxyResolutionRecord): ProxyResolutionRecord {
    const payload: ProxyResolvedPayload = {
      resolution: this.cloneResolution(resolution),
    };
    this.events.publish<ProxyResolvedPayload>('proxy.resolved', payload);
    return this.cloneResolution(resolution);
  }
  private makeResolution(
    targetUrl: string,
    mode: string,
    proxyUrl: string,
    bypassed: boolean,
    keepAlive: boolean,
    reason: string,
    warning: string,
  ): ProxyResolutionRecord {
    return {
      targetUrl: targetUrl,
      mode: mode,
      proxyUrl: proxyUrl,
      bypassed: bypassed,
      keepAlive: keepAlive,
      reason: reason,
      warning: warning,
    };
  }

  /**
   * 检查请求目标 URL 是否匹配 bypass 名单中的任意规则（精确匹配、通配符前缀匹配）。
   * @returns 匹配 bypass 规则时返回 true，否则返回 false。
   */
  private matchesBypass(targetUrl: string): boolean {
    const host = this.extractHost(targetUrl);
    if (host.length === 0) {
      return false;
    }
    const hostname = this.extractHostname(host);
    for (let index = 0; index < this.settings.bypass.length; index += 1) {
      const rule = this.settings.bypass[index].trim().toLowerCase();
      if (rule.length === 0) {
        continue;
      }
      if (host === rule || hostname === rule) {
        return true;
      }
      if (rule.startsWith('.') && hostname.endsWith(rule)) {
        return true;
      }
      if (rule.startsWith('*.') && hostname.endsWith(rule.substring(1))) {
        return true;
      }
    }
    return false;
  }

  /**
   * 检查字符串是否为格式合法的 URL（包含协议 scheme 且能提取出主机名）。
   * @param value 待检查的 URL 字符串。
   * @returns URL 格式合法时返回 true，否则返回 false。
   */
  private isValidUrl(value: string): boolean {
    const schemeIndex = value.indexOf('://');
    if (schemeIndex <= 0) {
      return false;
    }
    const host = this.extractHost(value);
    return host.length > 0;
  }

  /**
   * 从 URL 中提取主机部分（去除协议前缀、路径、查询参数和片段）。
   * @param value 完整的 URL 字符串。
   */
  private extractHost(value: string): string {
    const schemeIndex = value.indexOf('://');
    if (schemeIndex < 0) {
      return '';
    }
    const remainder = value.substring(schemeIndex + 3);
    if (remainder.length === 0) {
      return '';
    }
    let endIndex = remainder.length;
    const slashIndex = remainder.indexOf('/');
    if (slashIndex >= 0 && slashIndex < endIndex) {
      endIndex = slashIndex;
    }
    const queryIndex = remainder.indexOf('?');
    if (queryIndex >= 0 && queryIndex < endIndex) {
      endIndex = queryIndex;
    }
    const hashIndex = remainder.indexOf('#');
    if (hashIndex >= 0 && hashIndex < endIndex) {
      endIndex = hashIndex;
    }
    return remainder.substring(0, endIndex).toLowerCase();
  }

  /**
   * 从主机字符串中提取 hostname（去除端口号部分）。
   * @param host 包含端口号的主机字符串。
   */
  private extractHostname(host: string): string {
    const colonIndex = host.indexOf(':');
    if (colonIndex < 0) {
      return host;
    }
    return host.substring(0, colonIndex);
  }

  /**
   * 复制Settings 列表，避免外部修改内部状态。
   */
  private cloneSettings(settings: ProxySettings): ProxySettings {
    return {
      enabled: settings.enabled,
      url: settings.url,
      bypass: settings.bypass.slice(),
      enableKeepAlive: settings.enableKeepAlive,
      privateRequestFilterEnabled: settings.privateRequestFilterEnabled,
    };
  }

  /**
   * 复制Resolution 值，避免外部修改内部状态。
   */
  private cloneResolution(resolution: ProxyResolutionRecord): ProxyResolutionRecord {
    return {
      targetUrl: resolution.targetUrl,
      mode: resolution.mode,
      proxyUrl: resolution.proxyUrl,
      bypassed: resolution.bypassed,
      keepAlive: resolution.keepAlive,
      reason: resolution.reason,
      warning: resolution.warning,
    };
  }
}
