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
   * 事件总线。
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
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 执行 configure 的内部处理步骤，供当前模块复用。
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
   * 读取Settings 列表，不存在时通常抛出错误或返回空值。
   * @returns 更新或读取后的记录副本。
   */
  getSettings(): ProxySettings {
    return this.cloneSettings(this.settings);
  }

  /**
   * 根据当前上下文解析目标对象，返回实际可用值。
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
   * 检查Bypass是否满足当前规则。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 判断Valid Url 值是否满足条件。
   * @param value 要保存或比较的字段值。
   * @returns 条件命中时返回 true，否则返回 false。
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
   * 解析或导入主机数据，转换为当前 SDK 可使用的结构。
   * @param value 要保存或比较的字段值。
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
   * 解析或导入Hostname数据，转换为当前 SDK 可使用的结构。
   * @param host 目标主机名。
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
