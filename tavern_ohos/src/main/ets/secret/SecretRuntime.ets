import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  SecretAccessOptions,
  SecretCreateParams,
  SecretDeletedPayload,
  SecretEventPayload,
  SecretExportRecord,
  SecretRecord,
  SecretRotatedPayload,
  SecretStateRecord,
  SecretValueRecord,
} from './SecretModels';

interface SecretStorageSnapshot {
  schemaVersion: number;
  records: Array<SecretRecord>;
  values: Array<SecretValueRecord>;
}

/**
 * 提供密钥引用相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class SecretRuntime {
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
   * 记录副本列表，由当前实例内部维护。
   */
  private records: Map<string, SecretRecord> = new Map<string, SecretRecord>();
  /**
   * values 列表，由当前实例内部维护。
   */
  private values: Map<string, SecretValueRecord> = new Map<string, SecretValueRecord>();

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
   * 从 SDK 内部文件存储恢复密钥记录和值。
   */
  async loadFromStore(): Promise<void> {
    const store = new JsonStore<SecretStorageSnapshot>(this.requireFiles(), this.storagePath());
    const snapshot = await store.read(this.defaultStorageSnapshot());
    this.records.clear();
    this.values.clear();
    for (let index = 0; index < snapshot.records.length; index += 1) {
      const record = this.cloneRecord(snapshot.records[index]);
      this.records.set(record.secretRef, record);
    }
    for (let index = 0; index < snapshot.values.length; index += 1) {
      const value = this.cloneValue(snapshot.values[index]);
      this.values.set(value.secretRef, value);
    }
  }

  /**
   * 把当前密钥记录和值写入 SDK 内部文件存储。
   */
  async saveToStore(): Promise<void> {
    const records = this.cloneRecords(Array.from(this.records.values()));
    const values = this.cloneValues(Array.from(this.values.values()));
    const snapshot: SecretStorageSnapshot = {
      schemaVersion: 1,
      records: records,
      values: values,
    };
    await new JsonStore<SecretStorageSnapshot>(this.requireFiles(), this.storagePath()).write(snapshot);
  }

  /**
   * 创建新的密钥记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  createSecret(params: SecretCreateParams): SecretRecord {
    const now = Date.now();
    // 密钥引用。
    const secretRef = this.makeSecretRef(params.providerId, params.id);
    if (this.records.has(secretRef)) {
      throw new Error(`Secret already exists: ${secretRef}`);
    }
    if (params.active) {
      this.deactivateProviderScope(params.providerId, params.scope, params.scopeId);
    }
    const record: SecretRecord = {
      id: params.id,
      secretRef: secretRef,
      providerId: params.providerId,
      scope: params.scope,
      scopeId: params.scopeId,
      label: params.label,
      active: params.active,
      createdAt: now,
      updatedAt: now,
    };
    const valueRecord: SecretValueRecord = {
      secretRef: secretRef,
      value: params.value,
    };
    this.records.set(secretRef, this.cloneRecord(record));
    this.values.set(secretRef, valueRecord);
    this.publishSecretEvent('secret.created', record);
    return this.cloneRecord(record);
  }

  /**
   * 更新指定密钥，写回存储并按需发布变更事件。
   * @param secretRef 密钥引用。
   * @param label 展示标签。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  updateSecret(secretRef: string, label: string, active: boolean): SecretRecord {
    const record = this.requireRecord(secretRef);
    if (active) {
      this.deactivateProviderScope(record.providerId, record.scope, record.scopeId);
    }
    record.label = label;
    record.active = active;
    record.updatedAt = Date.now();
    this.publishSecretEvent('secret.updated', record);
    return this.cloneRecord(record);
  }

  /**
   * 删除指定密钥，并清理相关索引或资源引用。
   * @param secretRef 密钥引用。
   */
  deleteSecret(secretRef: string): void {
    const record = this.requireRecord(secretRef);
    this.records.delete(secretRef);
    this.values.delete(secretRef);
    const payload: SecretDeletedPayload = {
      secretRef: secretRef,
      providerId: record.providerId,
    };
    this.events.publish<SecretDeletedPayload>('secret.deleted', payload);
  }

  /**
   * 执行 rotateSecret 的内部处理步骤，供当前模块复用。
   * @param providerId 目标模型服务标识。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param id 唯一标识。
   * @param value 要保存或比较的字段值。
   * @param label 展示标签。
   */
  rotateSecret(
    providerId: string,
    scope: string,
    scopeId: string,
    id: string,
    value: string,
    label: string,
  ): SecretRecord {
    const previousSecretRef = this.findActiveSecretRef(providerId, scope, scopeId);
    // 调用参数。
    const params: SecretCreateParams = {
      id: id,
      providerId: providerId,
      scope: scope,
      scopeId: scopeId,
      label: label,
      value: value,
      active: true,
    };
    const record = this.createSecret(params);
    const payloadSecret = this.cloneRecord(record);
    const payload: SecretRotatedPayload = {
      secret: payloadSecret,
      previousSecretRef: previousSecretRef,
    };
    this.events.publish<SecretRotatedPayload>('secret.rotated', payload);
    return this.cloneRecord(record);
  }

  /**
   * 读取Secret 值，并转换为运行时使用的数据结构。
   * @param secretRef 密钥引用。
   * @param options 控制本次调用行为的选项。
   */
  readSecret(secretRef: string, options: SecretAccessOptions): string {
    if (!this.canRead(options)) {
      return '';
    }
    const value = this.values.get(secretRef);
    if (value === undefined) {
      return '';
    }
    return value.value;
  }

  /**
   * 读取Active Secret 值，并转换为运行时使用的数据结构。
   * @param providerId 目标模型服务标识。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param options 控制本次调用行为的选项。
   */
  readActiveSecret(providerId: string, scope: string, scopeId: string, options: SecretAccessOptions): string {
    // 密钥引用。
    const secretRef = this.findActiveSecretRef(providerId, scope, scopeId);
    if (secretRef.length === 0) {
      return '';
    }
    return this.readSecret(secretRef, options);
  }

  /**
   * 读取SecretStates列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param providerId 目标模型服务标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listSecretStates(providerId: string): Array<SecretStateRecord> {
    const result = new Array<SecretStateRecord>();
    const records = Array.from(this.records.values());
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      if (providerId.length === 0 || record.providerId === providerId) {
        result.push(this.toState(record));
      }
    }
    return result;
  }

  /**
   * 导出密钥索引，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  exportIndex(): Array<SecretExportRecord> {
    const result = new Array<SecretExportRecord>();
    const records = Array.from(this.records.values());
    for (let index = 0; index < records.length; index += 1) {
      const state = this.toState(records[index]);
      const exported: SecretExportRecord = {
        id: state.id,
        secretRef: state.secretRef,
        providerId: state.providerId,
        scope: state.scope,
        scopeId: state.scopeId,
        label: state.label,
        maskedValue: state.maskedValue,
        active: state.active,
        updatedAt: state.updatedAt,
      };
      result.push(exported);
    }
    return result;
  }

  /**
   * 执行 maskValue 的内部处理步骤，供当前模块复用。
   * @param value 要保存或比较的字段值。
   */
  maskValue(value: string): string {
    const threshold = 10;
    const exposedChars = 3;
    if (value.length === 0) {
      return '';
    }
    if (value.length <= threshold) {
      return '**********';
    }
    const visibleEnd = value.substring(value.length - exposedChars);
    return `*******${visibleEnd}`;
  }

  /**
   * 读取必须存在的Record 值，缺失时抛出错误。
   * @param secretRef 密钥引用。
   */
  private requireRecord(secretRef: string): SecretRecord {
    const record = this.records.get(secretRef);
    if (record === undefined) {
      throw new Error(`Secret not found: ${secretRef}`);
    }
    return record;
  }

  private requireFiles(): TavernFileStore {
    if (this.files === undefined) {
      throw new Error('SecretRuntime storage is not configured.');
    }
    return this.files;
  }

  private storagePath(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/secrets/index.json`;
  }

  private defaultStorageSnapshot(): SecretStorageSnapshot {
    return {
      schemaVersion: 1,
      records: new Array<SecretRecord>(),
      values: new Array<SecretValueRecord>(),
    };
  }

  /**
   * 检查Read是否满足当前规则。
   * @param options 控制本次调用行为的选项。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  private canRead(options: SecretAccessOptions): boolean {
    for (let index = 0; index < options.permissions.length; index += 1) {
      if (options.permissions[index] === 'secret:read') {
        return true;
      }
    }
    return false;
  }

  /**
   * 把密钥记录转换为可展示的脱敏状态。
   * @param record 记录副本。
   */
  private toState(record: SecretRecord): SecretStateRecord {
    const value = this.values.get(record.secretRef);
    const rawValue = value === undefined ? '' : value.value;
    const maskedValue = this.maskValue(rawValue);
    const state: SecretStateRecord = {
      id: record.id,
      secretRef: record.secretRef,
      providerId: record.providerId,
      scope: record.scope,
      scopeId: record.scopeId,
      label: record.label,
      maskedValue: maskedValue,
      active: record.active,
      updatedAt: record.updatedAt,
    };
    return state;
  }

  /**
   * 更新模型服务Scope状态，必要时写回存储并发布对应事件。
   * @param providerId 目标模型服务标识。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   */
  private deactivateProviderScope(providerId: string, scope: string, scopeId: string): void {
    const records = Array.from(this.records.values());
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      if (record.providerId === providerId && record.scope === scope && record.scopeId === scopeId) {
        record.active = false;
        record.updatedAt = Date.now();
      }
    }
  }

  /**
   * 在当前集合中查找Active Secret Ref 值，未命中时返回空值或默认位置。
   * @param providerId 目标模型服务标识。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   */
  private findActiveSecretRef(providerId: string, scope: string, scopeId: string): string {
    const records = Array.from(this.records.values());
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      if (record.providerId === providerId && record.scope === scope && record.scopeId === scopeId && record.active) {
        return record.secretRef;
      }
    }
    return '';
  }
  private makeSecretRef(providerId: string, id: string): string {
    return `secret:${providerId}:${id}`;
  }

  /**
   * 发布密钥引用事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。

   */
  private publishSecretEvent(eventName: string, secret: SecretRecord): void {
    const payloadSecret = this.cloneRecord(secret);
    const payload: SecretEventPayload = {
      secret: payloadSecret,
    };
    this.events.publish<SecretEventPayload>(eventName, payload);
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private cloneRecord(record: SecretRecord): SecretRecord {
    return {
      id: record.id,
      secretRef: record.secretRef,
      providerId: record.providerId,
      scope: record.scope,
      scopeId: record.scopeId,
      label: record.label,
      active: record.active,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  private cloneRecords(records: Array<SecretRecord>): Array<SecretRecord> {
    const cloned = new Array<SecretRecord>();
    for (let index = 0; index < records.length; index += 1) {
      cloned.push(this.cloneRecord(records[index]));
    }
    return cloned;
  }

  private cloneValue(value: SecretValueRecord): SecretValueRecord {
    return {
      secretRef: value.secretRef,
      value: value.value,
    };
  }

  private cloneValues(values: Array<SecretValueRecord>): Array<SecretValueRecord> {
    const cloned = new Array<SecretValueRecord>();
    for (let index = 0; index < values.length; index += 1) {
      cloned.push(this.cloneValue(values[index]));
    }
    return cloned;
  }
}
