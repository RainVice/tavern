import { EventBus } from '../runtime/EventBus';
import type {
  ConnectionApiType,
  TavernScope,
} from '../contracts/PublicContracts';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
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

interface ConnectionProfileStorageSnapshot {
  schemaVersion: number;
  profiles: Array<ConnectionProfileRecord>;
  activeProfiles: Array<ConnectionActiveProfileRecord>;
}

/**
 * 提供连接配置相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ConnectionProfileRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 文件存储适配器；未传入时仅使用内存态。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 用户标识。
   */
  private userId: string = 'default';
  /**
   * profiles 列表，由当前实例内部维护。
   */
  private profiles: Map<string, ConnectionProfileRecord> = new Map<string, ConnectionProfileRecord>();
  /**
   * active Profiles 列表，由当前实例内部维护。
   */
  private activeProfiles: Map<string, ConnectionActiveProfileRecord> = new Map<string, ConnectionActiveProfileRecord>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus, files?: TavernFileStore, rootPath: string = 'tavern-data', userId: string = 'default') {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从 SDK 内部文件存储恢复连接配置和激活绑定。
   */
  async loadFromStore(): Promise<void> {
    const store = new JsonStore<ConnectionProfileStorageSnapshot>(this.requireFiles(), this.storagePath());
    const snapshot = await store.read(this.defaultStorageSnapshot());
    this.profiles.clear();
    this.activeProfiles.clear();
    for (let index = 0; index < snapshot.profiles.length; index += 1) {
      const profile = this.cloneProfile(snapshot.profiles[index]);
      this.profiles.set(profile.id, profile);
    }
    for (let index = 0; index < snapshot.activeProfiles.length; index += 1) {
      const binding = this.cloneBinding(snapshot.activeProfiles[index]);
      this.activeProfiles.set(this.bindingKey(binding.scope, binding.scopeId), binding);
    }
  }

  /**
   * 把当前连接配置和激活绑定写入 SDK 内部文件存储。
   */
  async saveToStore(): Promise<void> {
    const profiles = this.cloneProfiles(Array.from(this.profiles.values()));
    const activeProfiles = this.cloneBindings(Array.from(this.activeProfiles.values()));
    const snapshot: ConnectionProfileStorageSnapshot = {
      schemaVersion: 1,
      profiles: profiles,
      activeProfiles: activeProfiles,
    };
    await new JsonStore<ConnectionProfileStorageSnapshot>(this.requireFiles(), this.storagePath()).write(snapshot);
  }

  /**
   * 创建新的连接配置记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  createProfile(params: ConnectionProfileCreateParams): ConnectionProfileRecord {
    if (this.profiles.has(params.id)) {
      throw new Error(`Connection profile already exists: ${params.id}`);
    }
    const record = this.toRecord(params, Date.now());
    this.profiles.set(record.id, this.cloneProfile(record));
    const payloadProfile = this.cloneProfile(record);
    const payload: ConnectionProfileEventPayload = {
      profile: payloadProfile,
    };
    this.events.publish<ConnectionProfileEventPayload>('connectionProfile.created', payload);
    return this.cloneProfile(record);
  }

  /**
   * 更新指定连接配置，写回存储并按需发布变更事件。
   * @param profileId 目标连接或预设配置标识。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  updateProfile(profileId: string, params: ConnectionProfileCreateParams): ConnectionProfileRecord {
    const existing = this.requireProfile(profileId);
    const record = this.toRecord(params, Date.now());
    record.id = existing.id;
    this.profiles.set(record.id, this.cloneProfile(record));
    const payloadProfile = this.cloneProfile(record);
    const payload: ConnectionProfileUpdatedPayload = {
      profile: payloadProfile,
    };
    this.events.publish<ConnectionProfileUpdatedPayload>('connectionProfile.updated', payload);
    return this.cloneProfile(record);
  }

  /**
   * 读取指定连接配置，不存在时抛出错误。
   * @param profileId 目标连接或预设配置标识。
   * @returns 更新或读取后的记录副本。
   */
  getProfile(profileId: string): ConnectionProfileRecord {
    return this.cloneProfile(this.requireProfile(profileId));
  }

  /**
   * 读取Profiles列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listProfiles(apiType: ConnectionApiType): Array<ConnectionProfileRecord> {
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

  /**
   * 删除指定连接配置，并清理相关索引或资源引用。
   * @param profileId 目标连接或预设配置标识。
   */
  deleteProfile(profileId: string): void {
    this.requireProfile(profileId);
    this.profiles.delete(profileId);
    this.removeActiveBindings(profileId);
    const payload: ConnectionProfileDeletedPayload = {
      profileId: profileId,
    };
    this.events.publish<ConnectionProfileDeletedPayload>('connectionProfile.deleted', payload);
  }

  /**
   * 设置当前连接配置，用于切换运行时状态或保存配置。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param profileId 目标连接或预设配置标识。
   */
  setActiveProfile(scope: TavernScope, scopeId: string, profileId: string): ConnectionActiveProfileRecord {
    this.requireProfile(profileId);
    const binding: ConnectionActiveProfileRecord = {
      scope: scope,
      scopeId: scopeId,
      profileId: profileId,
      updatedAt: Date.now(),
    };
    this.activeProfiles.set(this.bindingKey(scope, scopeId), this.cloneBinding(binding));
    const payloadBinding = this.cloneBinding(binding);
    const payload: ConnectionActiveProfilePayload = {
      binding: payloadBinding,
    };
    this.events.publish<ConnectionActiveProfilePayload>('connectionProfile.activeChanged', payload);
    return this.cloneBinding(binding);
  }

  /**
   * 根据当前上下文解析Active Profile 值，返回实际可用值。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   */
  resolveActiveProfile(scope: TavernScope, scopeId: string): ConnectionResolvedProfile {
    const binding = this.activeProfiles.get(this.bindingKey(scope, scopeId));
    if (binding === undefined) {
      throw new Error(`Active connection profile not found: ${scope}/${scopeId}`);
    }
    const profile = this.requireProfile(binding.profileId);
    const resolvedBinding = this.cloneBinding(binding);
    const resolvedProfile = this.cloneProfile(profile);
    const resolved: ConnectionResolvedProfile = {
      binding: resolvedBinding,
      profile: resolvedProfile,
      secretRef: profile.secretRef,
    };
    return resolved;
  }

  /**
   * 根据当前连接配置生成 ProviderRuntime 可使用的请求参数。
   * @param profileId 目标连接或预设配置标识。
   */
  toProviderRequest(profileId: string): ConnectionProviderRequest {
    const profile = this.requireProfile(profileId);
    const additionalHeaders = this.cloneHeadersMasked(profile.additionalHeaders);
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
      additionalHeaders: additionalHeaders,
    };
    return request;
  }

  /**
   * 把创建参数规范化为连接配置记录。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  private toRecord(params: ConnectionProfileCreateParams, updatedAt: number): ConnectionProfileRecord {
    const additionalHeaders = this.cloneHeaders(params.additionalHeaders);
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
      additionalHeaders: additionalHeaders,
      enabled: params.enabled,
      updatedAt: updatedAt,
    };
    return record;
  }

  /**
   * 读取必须存在的Profile 值，缺失时抛出错误。
   * @param profileId 目标连接或预设配置标识。
   */
  private requireProfile(profileId: string): ConnectionProfileRecord {
    const profile = this.profiles.get(profileId);
    if (profile === undefined) {
      throw new Error(`Connection profile not found: ${profileId}`);
    }
    return profile;
  }

  private requireFiles(): TavernFileStore {
    if (this.files === undefined) {
      throw new Error('ConnectionProfileRuntime storage is not configured.');
    }
    return this.files;
  }

  private storagePath(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/connection-profiles/index.json`;
  }

  private defaultStorageSnapshot(): ConnectionProfileStorageSnapshot {
    return {
      schemaVersion: 1,
      profiles: new Array<ConnectionProfileRecord>(),
      activeProfiles: new Array<ConnectionActiveProfileRecord>(),
    };
  }

  /**
   * 复制Profile 值，避免外部修改内部状态。
   */
  private cloneProfile(profile: ConnectionProfileRecord): ConnectionProfileRecord {
    const stopStrings = profile.stopStrings.slice();
    const additionalHeaders = this.cloneHeaders(profile.additionalHeaders);
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
      stopStrings: stopStrings,
      reasoningFormat: profile.reasoningFormat,
      toolCallingEnabled: profile.toolCallingEnabled,
      proxyUrl: profile.proxyUrl,
      additionalHeaders: additionalHeaders,
      enabled: profile.enabled,
      updatedAt: profile.updatedAt,
    };
  }

  /**
   * 复制Profiles 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneProfiles(profiles: Array<ConnectionProfileRecord>): Array<ConnectionProfileRecord> {
    const result = new Array<ConnectionProfileRecord>();
    for (let index = 0; index < profiles.length; index += 1) {
      result.push(this.cloneProfile(profiles[index]));
    }
    return result;
  }

  /**
   * 复制Binding 值，避免外部修改内部状态。
   */
  private cloneBinding(binding: ConnectionActiveProfileRecord): ConnectionActiveProfileRecord {
    return {
      scope: binding.scope,
      scopeId: binding.scopeId,
      profileId: binding.profileId,
      updatedAt: binding.updatedAt,
    };
  }

  private cloneBindings(bindings: Array<ConnectionActiveProfileRecord>): Array<ConnectionActiveProfileRecord> {
    const result = new Array<ConnectionActiveProfileRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      result.push(this.cloneBinding(bindings[index]));
    }
    return result;
  }

  /**
   * 复制Headers 列表，避免外部修改内部状态。
   * @param headers 请求头列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 复制Headers Masked 值，避免外部修改内部状态。
   * @param headers 请求头列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 移除当前激活绑定列表，用于解除注册、绑定或索引关系。
   * @param profileId 目标连接或预设配置标识。
   */
  private removeActiveBindings(profileId: string): void {
    const keys = Array.from(this.activeProfiles.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const binding = this.activeProfiles.get(keys[index]);
      if (binding !== undefined && binding.profileId === profileId) {
        this.activeProfiles.delete(keys[index]);
      }
    }
  }

  /**
   * 把连接配置对象绑定到指定作用域，后续读取会按该绑定解析。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   */
  private bindingKey(scope: TavernScope, scopeId: string): string {
    return `${scope}:${scopeId}`;
  }
}
