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
   * 内存中的连接配置记录映射表。
   */
  private profiles: Map<string, ConnectionProfileRecord> = new Map<string, ConnectionProfileRecord>();
  /**
   * 作用域与激活配置的绑定关系列表。
   */
  private activeProfiles: Map<string, ConnectionActiveProfileRecord> = new Map<string, ConnectionActiveProfileRecord>();

  /**
   * 初始化运行时实例，可选挂载文件存储用于持久化。
   * @param events 事件总线实例。
   * @param files 可选的文件存储适配器；不传入时仅维持内存状态。
   * @param rootPath 数据存储根路径，默认 "tavern-data"。
   * @param userId 当前用户标识，默认 "default"。
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
   * 创建新的连接配置记录，写入存储并返回副本。若标识已存在则抛出错误。
   * @param params 创建连接配置所需的参数集合。
   * @returns 新创建的连接配置记录副本。
   * @throws 当标识已存在时抛出 Error。
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
   * 更新指定连接配置，并发布变更事件。
   * @param profileId 目标连接配置标识。
   * @param params 新的配置参数集合。
   * @returns 更新后的连接配置记录副本。
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
   * @param profileId 目标连接配置标识。
   * @returns 连接配置记录副本。
   */
  getProfile(profileId: string): ConnectionProfileRecord {
    return this.cloneProfile(this.requireProfile(profileId));
  }

  /**
   * 读取指定 API 类型下的连接配置列表，返回副本。
   * @param apiType 过滤的 API 类型；传空字符串时不作过滤返回全部。
   * @returns 匹配的连接配置记录列表副本。
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
   * 删除指定连接配置，从内存中清除并移除关联的激活绑定，发布删除事件。
   * @param profileId 待删除的连接配置标识。
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
   * 将指定连接配置绑定到某一作用域，并发布激活变更事件。
   * @param scope 目标作用域类型。
   * @param scopeId 作用域下的具体对象标识。
   * @param profileId 待绑定的连接配置标识。
   * @returns 新创建的激活绑定记录副本。
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
   * 根据作用域和对象标识解析当前激活的连接配置，包含绑定、记录和密钥引用。
   * @param scope 目标作用域类型。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 解析后的完整连接配置。
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
   * 根据连接配置记录生成发送给服务提供商的请求参数，其中密钥类 Header 值会被遮盖。
   * @param profileId 目标连接配置标识。
   * @returns 可用于发起 API 请求的参数对象。
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
   * 将创建参数规范化为内部连接配置记录。
   * @param params 创建参数。
   * @param updatedAt 记录更新时间戳。
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
   * 按标识查找连接配置，不存在时抛出错误。
   * @param profileId 连接配置标识。
   */
  private requireProfile(profileId: string): ConnectionProfileRecord {
    const profile = this.profiles.get(profileId);
    if (profile === undefined) {
      throw new Error(`Connection profile not found: ${profileId}`);
    }
    return profile;
  }

  /**
   * 返回已挂载的文件存储实例，未配置时抛出错误。
   */
  private requireFiles(): TavernFileStore {
    if (this.files === undefined) {
      throw new Error('ConnectionProfileRuntime storage is not configured.');
    }
    return this.files;
  }

  /**
   * 拼接存储路径，包含用户标识以确保多用户隔离。
   */
  private storagePath(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/connection-profiles/index.json`;
  }

  /**
   * 返回空快照作为 JsonStore 的默认值。
   */
  private defaultStorageSnapshot(): ConnectionProfileStorageSnapshot {
    return {
      schemaVersion: 1,
      profiles: new Array<ConnectionProfileRecord>(),
      activeProfiles: new Array<ConnectionActiveProfileRecord>(),
    };
  }

  /**
   * 深拷贝单条连接配置记录，避免外部修改内部状态。
   * @param profile 待拷贝的连接配置记录。
   * @returns 全新的记录副本。
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
   * 批量深拷贝连接配置记录列表。
   * @param profiles 待拷贝的连接配置记录列表。
   * @returns 全新的记录列表副本。
   */
  private cloneProfiles(profiles: Array<ConnectionProfileRecord>): Array<ConnectionProfileRecord> {
    const result = new Array<ConnectionProfileRecord>();
    for (let index = 0; index < profiles.length; index += 1) {
      result.push(this.cloneProfile(profiles[index]));
    }
    return result;
  }

  /**
   * 深拷贝单条激活绑定记录。
   * @param binding 待拷贝的激活绑定记录。
   * @returns 全新的绑定记录副本。
   */
  private cloneBinding(binding: ConnectionActiveProfileRecord): ConnectionActiveProfileRecord {
    return {
      scope: binding.scope,
      scopeId: binding.scopeId,
      profileId: binding.profileId,
      updatedAt: binding.updatedAt,
    };
  }

  /**
   * 批量深拷贝激活绑定记录列表。
   * @param bindings 待拷贝的激活绑定记录列表。
   * @returns 全新的绑定记录列表副本。
   */
  private cloneBindings(bindings: Array<ConnectionActiveProfileRecord>): Array<ConnectionActiveProfileRecord> {
    const result = new Array<ConnectionActiveProfileRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      result.push(this.cloneBinding(bindings[index]));
    }
    return result;
  }

  /**
   * 深拷贝 Header 记录列表。
   * @param headers 待拷贝的 Header 记录列表。
   * @returns 全新的 Header 记录列表副本。
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
   * 深拷贝 Header 记录列表，其中 secret 为 true 的值替换为 "redacted"。
   * @param headers 待拷贝的 Header 记录列表。
   * @returns 密钥值已被遮盖的全新记录列表副本。
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
   * 移除所有引用了指定连接配置的激活绑定。
   * @param profileId 被删除的连接配置标识。
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
   * 生成作用域绑定的 Map 键，格式为 "作用域:对象标识"。
   * @param scope 目标作用域类型。
   * @param scopeId 作用域下的具体对象标识。
   */
  private bindingKey(scope: TavernScope, scopeId: string): string {
    return `${scope}:${scopeId}`;
  }
}
