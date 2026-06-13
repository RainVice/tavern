export interface ProxySettings {
  enabled: boolean;
  url: string;
  bypass: Array<string>;
  enableKeepAlive: boolean;
  privateRequestFilterEnabled: boolean;
}

export interface ProxyResolutionRecord {
  targetUrl: string;
  mode: string;
  proxyUrl: string;
  bypassed: boolean;
  keepAlive: boolean;
  reason: string;
  warning: string;
}

export interface ProxyConfiguredPayload {
  settings: ProxySettings;
}

export interface ProxyResolvedPayload {
  resolution: ProxyResolutionRecord;
}
