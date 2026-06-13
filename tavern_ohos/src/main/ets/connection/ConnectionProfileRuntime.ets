import { EventBus } from '../runtime/EventBus';
import type {
  ConnectionActiveProfilePayload,
  ConnectionActiveProfileRecord,
  ConnectionHeaderRecord,
  ConnectionProfileCreateParams,
  ConnectionProfileDeletedPayload,
  ConnectionProfileEventPayload,
  ConnectionProfileRecord,
  ConnectionProfileUpdatedPayload,
  ConnectionProviderRequest,
  ConnectionResolvedProfile,
} from './ConnectionProfileModels';

export class ConnectionProfileRuntime {
  private events: EventBus;
  private profiles: Map<string, ConnectionProfileRecord> = new Map<string, ConnectionProfileRecord>();
  private activeProfiles: Map<string, ConnectionActiveProfileRecord> = new Map<string, ConnectionActiveProfileRecord>();

  constructor(events: EventBus) {
    this.events = events;
  }

  createProfile(params: ConnectionProfileCreateParams): ConnectionProfileRecord {
    if (this.profiles.has(params.id)) {
      throw new Error(`Connection profile already exists: ${params.id}`);
    }
    const record = this.toRecord(params, Date.now());
    this.profiles.set(record.id, this.cloneProfile(record));
    const payload: ConnectionProfileEventPayload = {
      profile: this.cloneProfile(record),
    };
    this.events.publish<ConnectionProfileEventPayload>('connectionProfile.created', payload);
    return this.cloneProfile(record);
  }

  updateProfile(profileId: string, params: ConnectionProfileCreateParams): ConnectionProfileRecord {
    const existing = this.requireProfile(profileId);
    const record = this.toRecord(params, Date.now());
    record.id = existing.id;
    this.profiles.set(record.id, this.cloneProfile(record));
    const payload: ConnectionProfileUpdatedPayload = {
      profile: this.cloneProfile(record),
    };
    this.events.publish<ConnectionProfileUpdatedPayload>('connectionProfile.updated', payload);
    return this.cloneProfile(record);
  }

  getProfile(profileId: string): ConnectionProfileRecord {
    return this.cloneProfile(this.requireProfile(profileId));
  }

  listProfiles(apiType: string): Array<ConnectionProfileRecord> {
    const records = Array.from(this.profiles.values());
    if (apiType.length === 0) {
      return this.cloneProfiles(records);
    }
    const result = new Array<ConnectionProfileRecord>();
    for (let index = 0; index < records.length; index += 1) {
      if (records[index].apiType === apiType) {
        result.push(this.cloneProfile(records[index]));
      }
    }
    return result;
  }

  deleteProfile(profileId: string): void {
    this.requireProfile(profileId);
    this.profiles.delete(profileId);
    this.removeActiveBindings(profileId);
    const payload: ConnectionProfileDeletedPayload = {
      profileId: profileId,
    };
    this.events.publish<ConnectionProfileDeletedPayload>('connectionProfile.deleted', payload);
  }

  setActiveProfile(scope: string, scopeId: string, profileId: string): ConnectionActiveProfileRecord {
    this.requireProfile(profileId);
    const binding: ConnectionActiveProfileRecord = {
      scope: scope,
      scopeId: scopeId,
      profileId: profileId,
      updatedAt: Date.now(),
    };
    this.activeProfiles.set(this.bindingKey(scope, scopeId), this.cloneBinding(binding));
    const payload: ConnectionActiveProfilePayload = {
      binding: this.cloneBinding(binding),
    };
    this.events.publish<ConnectionActiveProfilePayload>('connectionProfile.activeChanged', payload);
    return this.cloneBinding(binding);
  }

  resolveActiveProfile(scope: string, scopeId: string): ConnectionResolvedProfile {
    const binding = this.activeProfiles.get(this.bindingKey(scope, scopeId));
    if (binding === undefined) {
      throw new Error(`Active connection profile not found: ${scope}/${scopeId}`);
    }
    const profile = this.requireProfile(binding.profileId);
    const resolved: ConnectionResolvedProfile = {
      binding: this.cloneBinding(binding),
      profile: this.cloneProfile(profile),
      secretRef: profile.secretRef,
    };
    return resolved;
  }

  toProviderRequest(profileId: string): ConnectionProviderRequest {
    const profile = this.requireProfile(profileId);
    const request: ConnectionProviderRequest = {
      apiType: profile.apiType,
      model: profile.model,
      serverUrl: profile.serverUrl,
      secretRef: profile.secretRef,
      generationPresetId: profile.generationPresetId,
      systemPromptPresetId: profile.systemPromptPresetId,
      contextTemplateId: profile.contextTemplateId,
      instructTemplateId: profile.instructTemplateId,
      tokenizer: profile.tokenizer,
      stopStrings: profile.stopStrings.slice(),
      reasoningFormat: profile.reasoningFormat,
      toolCallingEnabled: profile.toolCallingEnabled,
      proxyUrl: profile.proxyUrl,
      additionalHeaders: this.cloneHeadersMasked(profile.additionalHeaders),
    };
    return request;
  }

  private toRecord(params: ConnectionProfileCreateParams, updatedAt: number): ConnectionProfileRecord {
    const record: ConnectionProfileRecord = {
      id: params.id,
      name: params.name,
      apiType: params.apiType,
      model: params.model,
      serverUrl: params.serverUrl,
      secretRef: params.secretRef,
      generationPresetId: params.generationPresetId,
      systemPromptPresetId: params.systemPromptPresetId,
      contextTemplateId: params.contextTemplateId,
      instructTemplateId: params.instructTemplateId,
      tokenizer: params.tokenizer,
      stopStrings: params.stopStrings.slice(),
      reasoningFormat: params.reasoningFormat,
      toolCallingEnabled: params.toolCallingEnabled,
      proxyUrl: params.proxyUrl,
      additionalHeaders: this.cloneHeaders(params.additionalHeaders),
      enabled: params.enabled,
      updatedAt: updatedAt,
    };
    return record;
  }

  private requireProfile(profileId: string): ConnectionProfileRecord {
    const profile = this.profiles.get(profileId);
    if (profile === undefined) {
      throw new Error(`Connection profile not found: ${profileId}`);
    }
    return profile;
  }

  private cloneProfile(profile: ConnectionProfileRecord): ConnectionProfileRecord {
    return {
      id: profile.id,
      name: profile.name,
      apiType: profile.apiType,
      model: profile.model,
      serverUrl: profile.serverUrl,
      secretRef: profile.secretRef,
      generationPresetId: profile.generationPresetId,
      systemPromptPresetId: profile.systemPromptPresetId,
      contextTemplateId: profile.contextTemplateId,
      instructTemplateId: profile.instructTemplateId,
      tokenizer: profile.tokenizer,
      stopStrings: profile.stopStrings.slice(),
      reasoningFormat: profile.reasoningFormat,
      toolCallingEnabled: profile.toolCallingEnabled,
      proxyUrl: profile.proxyUrl,
      additionalHeaders: this.cloneHeaders(profile.additionalHeaders),
      enabled: profile.enabled,
      updatedAt: profile.updatedAt,
    };
  }

  private cloneProfiles(profiles: Array<ConnectionProfileRecord>): Array<ConnectionProfileRecord> {
    const result = new Array<ConnectionProfileRecord>();
    for (let index = 0; index < profiles.length; index += 1) {
      result.push(this.cloneProfile(profiles[index]));
    }
    return result;
  }

  private cloneBinding(binding: ConnectionActiveProfileRecord): ConnectionActiveProfileRecord {
    return {
      scope: binding.scope,
      scopeId: binding.scopeId,
      profileId: binding.profileId,
      updatedAt: binding.updatedAt,
    };
  }

  private cloneHeaders(headers: Array<ConnectionHeaderRecord>): Array<ConnectionHeaderRecord> {
    const result = new Array<ConnectionHeaderRecord>();
    for (let index = 0; index < headers.length; index += 1) {
      const header: ConnectionHeaderRecord = {
        name: headers[index].name,
        value: headers[index].value,
        secret: headers[index].secret,
      };
      result.push(header);
    }
    return result;
  }

  private cloneHeadersMasked(headers: Array<ConnectionHeaderRecord>): Array<ConnectionHeaderRecord> {
    const result = new Array<ConnectionHeaderRecord>();
    for (let index = 0; index < headers.length; index += 1) {
      const value = headers[index].secret ? 'redacted' : headers[index].value;
      const header: ConnectionHeaderRecord = {
        name: headers[index].name,
        value: value,
        secret: headers[index].secret,
      };
      result.push(header);
    }
    return result;
  }

  private removeActiveBindings(profileId: string): void {
    const keys = Array.from(this.activeProfiles.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const binding = this.activeProfiles.get(keys[index]);
      if (binding !== undefined && binding.profileId === profileId) {
        this.activeProfiles.delete(keys[index]);
      }
    }
  }

  private bindingKey(scope: string, scopeId: string): string {
    return `${scope}:${scopeId}`;
  }
}
