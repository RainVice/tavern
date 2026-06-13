export interface ConnectionHeaderRecord {
  name: string;
  value: string;
  secret: boolean;
}

export interface ConnectionProfileCreateParams {
  id: string;
  name: string;
  apiType: string;
  model: string;
  serverUrl: string;
  secretRef: string;
  generationPresetId: string;
  systemPromptPresetId: string;
  contextTemplateId: string;
  instructTemplateId: string;
  tokenizer: string;
  stopStrings: Array<string>;
  reasoningFormat: string;
  toolCallingEnabled: boolean;
  proxyUrl: string;
  additionalHeaders: Array<ConnectionHeaderRecord>;
  enabled: boolean;
}

export interface ConnectionProfileRecord {
  id: string;
  name: string;
  apiType: string;
  model: string;
  serverUrl: string;
  secretRef: string;
  generationPresetId: string;
  systemPromptPresetId: string;
  contextTemplateId: string;
  instructTemplateId: string;
  tokenizer: string;
  stopStrings: Array<string>;
  reasoningFormat: string;
  toolCallingEnabled: boolean;
  proxyUrl: string;
  additionalHeaders: Array<ConnectionHeaderRecord>;
  enabled: boolean;
  updatedAt: number;
}

export interface ConnectionActiveProfileRecord {
  scope: string;
  scopeId: string;
  profileId: string;
  updatedAt: number;
}

export interface ConnectionResolvedProfile {
  binding: ConnectionActiveProfileRecord;
  profile: ConnectionProfileRecord;
  secretRef: string;
}

export interface ConnectionProviderRequest {
  apiType: string;
  model: string;
  serverUrl: string;
  secretRef: string;
  generationPresetId: string;
  systemPromptPresetId: string;
  contextTemplateId: string;
  instructTemplateId: string;
  tokenizer: string;
  stopStrings: Array<string>;
  reasoningFormat: string;
  toolCallingEnabled: boolean;
  proxyUrl: string;
  additionalHeaders: Array<ConnectionHeaderRecord>;
}

export interface ConnectionProfileEventPayload {
  profile: ConnectionProfileRecord;
}

export interface ConnectionProfileUpdatedPayload {
  profile: ConnectionProfileRecord;
}

export interface ConnectionProfileDeletedPayload {
  profileId: string;
}

export interface ConnectionActiveProfilePayload {
  binding: ConnectionActiveProfileRecord;
}
