export interface ServerStartedPayload {
  source: string;
}

export interface RuntimeSignalPayload {
  signal: string;
  detail: string;
}

export interface EventCatalogEntry {
  name: string;
  upstreamName: string;
  domain: string;
  payloadFields: Array<string>;
  pluginVisible: boolean;
  uiVisible: boolean;
}

export interface EventCatalogPayload {
  entry: EventCatalogEntry;
  detail: string;
}
