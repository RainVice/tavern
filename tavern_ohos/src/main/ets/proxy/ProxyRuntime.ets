import { EventBus } from '../runtime/EventBus';
import type {
  ProxyConfiguredPayload,
  ProxyResolutionRecord,
  ProxyResolvedPayload,
  ProxySettings,
} from './ProxyModels';

export class ProxyRuntime {
  private events: EventBus;
  private settings: ProxySettings = {
    enabled: false,
    url: '',
    bypass: new Array<string>(),
    enableKeepAlive: false,
    privateRequestFilterEnabled: false,
  };

  constructor(events: EventBus) {
    this.events = events;
  }

  configure(settings: ProxySettings): ProxySettings {
    this.settings = this.cloneSettings(settings);
    const payload: ProxyConfiguredPayload = {
      settings: this.cloneSettings(this.settings),
    };
    this.events.publish<ProxyConfiguredPayload>('proxy.configured', payload);
    return this.cloneSettings(this.settings);
  }

  getSettings(): ProxySettings {
    return this.cloneSettings(this.settings);
  }

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

  private isValidUrl(value: string): boolean {
    const schemeIndex = value.indexOf('://');
    if (schemeIndex <= 0) {
      return false;
    }
    const host = this.extractHost(value);
    return host.length > 0;
  }

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

  private extractHostname(host: string): string {
    const colonIndex = host.indexOf(':');
    if (colonIndex < 0) {
      return host;
    }
    return host.substring(0, colonIndex);
  }

  private cloneSettings(settings: ProxySettings): ProxySettings {
    return {
      enabled: settings.enabled,
      url: settings.url,
      bypass: settings.bypass.slice(),
      enableKeepAlive: settings.enableKeepAlive,
      privateRequestFilterEnabled: settings.privateRequestFilterEnabled,
    };
  }

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
