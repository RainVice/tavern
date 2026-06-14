import { EventBus } from '../runtime/EventBus';
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
 * 提供连接配置相关的无 UI 运行时能力，负责连接配置的增删改查、作用域绑定管理和事件发布，
 * 供 API 连接管理界面、聊天会话自动解析连接等流程调用。
 */
export class ConnectionProfileRuntime {
  /**
   * 事件总线，用于发布配置创建、更新、删除和绑定变更事件。
   */
  private events: EventBus;
  /**
   * 文件存储适配器，用于持久化和恢复连接配置；未传入时仅使用内存态。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 存储连接配置的文件目录根路径。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 当前操作用户的标识。
   */
  private userId: string = 'default';
  /**
   * 所有连接配置的内存映射表，键为配置标识。
   */
  private profiles: Map<string, ConnectionProfileRecord> = new Map<string, ConnectionProfileRecord>();
  /**
   * 所有作用域绑定的内存映射表，键为 "scope:scopeId" 拼接字符串。
   */
  private activeProfiles: Map<string, ConnectionActiveProfileRecord> = new Map<string, ConnectionActiveProfileRecord>();

  /**
   * 初始化当前运行时实例，在应用启动或进入连接配置管理模块时调用。
   * @param events 事件总线，用于在配置创建、更新、删除和绑定变更后发布事件通知其他模块。
   * @param files 可选的文件存储适配器，提供后将把配置数据持久化到文件；未传入时仅使用内存态。
   * @param rootPath 可选的数据存储根路径，用于构建配置文件的存储目录。
   * @param userId 可选的用户标识，用于隔离不同用户的连接配置数据。
   */
  constructor(events: EventBus, files?: TavernFileStore, rootPath: string = 'tavern-data', userId: string = 'default') {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从 SDK 内部文件存储中恢复所有连接配置和活跃绑定到内存，在应用启动时调用以加载持久化的配置数据。
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
   * 将当前内存中的连接配置和活跃绑定持久化到 SDK 内部文件存储，在关键变更后调用以确保数据不丢失。
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
   * 创建新的连接配置记录，在用户通过配置管理界面添加新连接时调用。
   * 流程：校验 ID 唯一性 -> 规范化为记录格式 -> 写入内存映射 -> 发布 connectionProfile.created 事件。
   * @param params 包含 API 类型、模型、地址等配置的创建参数，由配置表单提交时提供。
   * @returns 创建后的连接配置副本，用于 UI 确认和列表刷新。
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
   * 更新指定连接配置，在用户修改已有连接时调用。
   * 流程：校验存在性 -> 规范化新参数（保留原 ID）-> 替换内存记录 -> 发布 connectionProfile.updated 事件。
   * @param profileId 要更新的连接配置标识，由配置管理界面选中项传入。
   * @param params 替换后的配置参数，由配置编辑表单提交时提供。
   * @returns 更新后的连接配置副本，用于 UI 刷新。
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
   * 根据标识读取指定连接配置，在需要获取配置详情时调用。
   * 不存在时抛出错误。
   * @param profileId 要读取的连接配置标识，由查询操作传入。
   * @returns 连接配置记录的副本，用于详情展示或编辑表单初始化。
   */
  getProfile(profileId: string): ConnectionProfileRecord {
    return this.cloneProfile(this.requireProfile(profileId));
  }

  /**
   * 按 API 类型筛选连接配置列表，在配置管理界面按类型过滤时调用。
   * 类型为空字符串时返回所有配置，不做筛选。
   * @param apiType API 类型筛选条件，如 'openai'、'anthropic' 等。
   * @returns 匹配的连接配置副本列表，用于 UI 展示按类型分组的配置列表。
   */
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

  /**
   * 删除指定连接配置，同时清理所有引用该配置的活跃绑定，在用户删除连接时调用。
   * 流程：校验存在性 -> 从内存映射移除 -> 清理相关绑定 -> 发布 connectionProfile.deleted 事件。
   * @param profileId 要删除的连接配置标识，由配置管理界面的删除操作传入。
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
   * 将连接配置绑定到指定作用域，在用户为特定聊天或角色设置连接时调用。
   * 绑定后可通过 resolveActiveProfile 按作用域解析对应的连接配置。
   * @param scope 绑定作用域（如 'chat'、'character'、'global'）。
   * @param scopeId 作用域下的具体对象标识（如聊天 ID 或角色 ID）。
   * @param profileId 要绑定的连接配置标识。
   * @returns 绑定后的活跃配置记录副本，用于 UI 确认绑定状态。
   */
  setActiveProfile(scope: string, scopeId: string, profileId: string): ConnectionActiveProfileRecord {
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
   * 根据作用域解析出完整的连接配置信息（包含绑定记录和配置记录），在需要发送 API 请求时由 Provider 运行时调用。
   * @param scope 绑定作用域，与 setActiveProfile 时的 scope 对应。
   * @param scopeId 作用域下的具体对象标识，与 setActiveProfile 时的 scopeId 对应。
   * @returns 完整的解析后连接配置，包含绑定记录和配置记录，用于 Provider 运行时发起 API 调用。
   */
  resolveActiveProfile(scope: string, scopeId: string): ConnectionResolvedProfile {
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
   * 根据连接配置标识生成 ProviderRuntime 可直接使用的 API 请求参数，在发送 API 请求前调用。
   * 对标记为 secret 的请求头值自动脱敏为 'redacted'。
   * @param profileId 连接配置标识，由 resolveActiveProfile 或直接查询提供。
   * @returns API 请求参数结构，包含 apiType、model、serverUrl 等字段，可直接传递给 Provider 运行时。
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
   * @param params 创建或更新时传入的参数。
   * @param updatedAt 记录的时间戳。
   * @returns 规范化后的连接配置记录。
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
   * 根据配置标识获取必须存在的连接配置，缺失时抛出错误。
   * @param profileId 连接配置标识。
   * @returns 连接配置记录。
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
   * 复制连接配置记录，避免外部修改内部状态。
   * @param profile 原始配置记录。
   * @returns 配置记录的副本。
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
   * 复制连接配置列表，避免外部修改内部状态。
   * @param profiles 原始配置列表。
   * @returns 配置列表的副本。
   */
  private cloneProfiles(profiles: Array<ConnectionProfileRecord>): Array<ConnectionProfileRecord> {
    const result = new Array<ConnectionProfileRecord>();
    for (let index = 0; index < profiles.length; index += 1) {
      result.push(this.cloneProfile(profiles[index]));
    }
    return result;
  }

  /**
   * 复制活跃绑定记录，避免外部修改内部状态。
   * @param binding 原始绑定记录。
   * @returns 绑定记录的副本。
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
   * 复制请求头列表，避免外部修改内部状态。
   * @param headers 原始请求头列表。
   * @returns 请求头列表的副本。
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
   * 复制请求头列表，同时将标记为 secret 的字段值替换为 'redacted'，用于安全导出。
   * @param headers 原始请求头列表。
   * @returns 脱敏后的请求头列表副本。
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
   * 删除所有引用了指定配置标识的活跃绑定记录。
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
   * 将作用域和作用域标识拼接为绑定映射表的键。
   * @param scope 绑定作用域。
   * @param scopeId 作用域下的对象标识。
   * @returns 拼接后的键字符串。
   */
  private bindingKey(scope: string, scopeId: string): string {
    return `${scope}:${scopeId}`;
  }
}
