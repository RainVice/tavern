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
 * 在对话流程中由 ProviderRuntime 调用以获取 API 密钥（readActiveSecret / readSecret），
 * 由 UI 层调用以管理密钥（createSecret / updateSecret / deleteSecret / rotateSecret）。
 */
export class SecretRuntime {
  private events: EventBus;
  private files: TavernFileStore | undefined = undefined;
  private rootPath: string = 'tavern-data';
  private userId: string = 'default';
  private records: Map<string, SecretRecord> = new Map<string, SecretRecord>();
  private values: Map<string, SecretValueRecord> = new Map<string, SecretValueRecord>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例，用于发布密钥创建、更新、删除、轮换等事件。
   * @param files 文件存储适配器，非必选；传入时支持 saveToStore / loadFromStore 持久化，未传入时仅使用内存态。
   * @param rootPath 数据根路径，默认为 "tavern-data"，用于拼接文件存储路径。
   * @param userId 用户标识，默认为 "default"，用于拼接文件存储路径以隔离多用户数据。
   */
  constructor(events: EventBus, files?: TavernFileStore, rootPath: string = 'tavern-data', userId: string = 'default') {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从 SDK 内部文件存储恢复密钥记录和值。
   * 由宿主在应用启动时调用，从持久化文件中加载之前保存的密钥索引和明文值。
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
   * 由宿主在密钥发生变更后调用（如 createSecret / updateSecret / deleteSecret 后），
   * 持久化当前内存中的全部密钥索引和明文值。
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
   * 创建新密钥，写入内存索引，若 active 为 true 则停用同作用域下其他密钥。
   * 由 UI 层在用户添加新 API 密钥时调用，创建后通过 "secret.created" 事件通知宿主。
   * @param params 密钥创建参数，包含标识、provider、作用域、标签、值和激活状态，来自 UI 表单输入。
   * @returns 新创建密钥记录的副本。
   */
  createSecret(params: SecretCreateParams): SecretRecord {
    const now = Date.now();
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
   * 更新密钥的标签和激活状态，若 active 更改为 true 则停用同作用域下其他密钥。
   * 由 UI 层在用户编辑密钥信息时调用，更新后通过 "secret.updated" 事件通知宿主。
   * @param secretRef 要更新的密钥引用标识，由用户选择的具体目标密钥决定。
   * @param label 新的显示标签，由用户在 UI 编辑框中输入。
   * @param active 新的激活状态，由用户在 UI 开关控件中选择。
   * @returns 更新后的密钥记录副本。
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
   * 删除指定密钥及其明文值，并从内存中移除，发布删除事件。
   * 由 UI 层在用户删除密钥时调用。
   * @param secretRef 要删除的密钥引用标识，由用户选择的具体目标密钥决定。
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
   * 轮换密钥：停用旧密钥并用新密钥替换，发布轮换事件。
   * 由 UI 层或自动安全策略在需要刷新密钥时调用（如检测到密钥泄露或定期更换）。
   * 新密钥自动激活，旧密钥被停用但保留在索引中供审计。
   * @param providerId provider 唯一标识，用于定位当前激活的旧密钥。
   * @param scope 密钥作用域，用于定位当前激活的旧密钥。
   * @param scopeId 作用域下的具体对象标识，用于定位当前激活的旧密钥。
   * @param id 新密钥的唯一标识，由调用方提供以区别于旧密钥。
   * @param value 新密钥的明文值，替换旧密钥的鉴权令牌。
   * @param label 新密钥的显示标签，用于在 UI 中标识新密钥的用途。
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
   * 读取指定密钥引用的明文值，需通过访问权限检查。
   * 由 ProviderRuntime 在构建 API 鉴权请求时调用，读取指定密钥的明文以设置 Authorization header。
   * @param secretRef 要读取的密钥引用标识，通常来自 readActiveSecret 或其他查找结果。
   * @param options 访问权限选项，包含调用方权限列表，需包含 "secret:read" 权限。
   * @returns 密钥明文值；无权访问或不存在时返回空字符串。
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
   * 读取指定作用域下处于激活状态的密钥明文值。
   * 由 ProviderRuntime 在构建 API 请求时调用，自动查找当前作用域的活跃密钥。
   * 按 providerId + scope + scopeId 查找激活密钥，然后通过 readSecret 获取明文值。
   * @param providerId provider 标识，用于定位具体 provider 在指定作用域下的密钥。
   * @param scope 密钥作用域（如 "global"），用于进一步限定查找范围。
   * @param scopeId 作用域下的具体对象标识，用于精确定位。
   * @param options 访问权限选项，传递到 readSecret 进行权限校验。
   * @returns 激活密钥的明文值；未找到或无权访问时返回空字符串。
   */
  readActiveSecret(providerId: string, scope: string, scopeId: string, options: SecretAccessOptions): string {
    const secretRef = this.findActiveSecretRef(providerId, scope, scopeId);
    if (secretRef.length === 0) {
      return '';
    }
    return this.readSecret(secretRef, options);
  }

  /**
   * 获取指定 provider 下所有密钥的脱敏状态记录列表。
   * 由 UI 层在密钥管理界面初始化或刷新时调用，获取脱敏后的密钥列表以安全展示在 UI 上。
   * @param providerId 要查询的 provider 标识；传入空字符串则返回所有 provider 的密钥。
   * @returns 脱敏密钥状态记录列表副本。
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
   * 导出密钥索引记录（不含明文值），用于备份或迁移。
   * 由宿主在触发密钥导出操作时调用，返回脱敏后的密钥元信息列表。
   * @returns 密钥导出记录列表副本，包含脱敏值。
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
   * 对密钥明文进行脱敏处理：短密钥完全遮蔽，长密钥仅保留末尾 3 位。
   * 由 toState 在生成 SecretStateRecord 和 SecretExportRecord 时调用，用于前端安全展示。
   * @param value 密钥明文，来自 values 映射中的 SecretValueRecord.value。
   * @returns 脱敏后的字符串。
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
   * 查找指定密钥引用对应的记录，不存在时抛出异常。
   * @param secretRef 密钥引用标识。
   * @returns 匹配的密钥记录。
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
   * 检查调用方权限列表中是否包含 "secret:read" 权限。
   * @param options 访问权限选项。
   * @returns 包含 "secret:read" 权限时返回 true。
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
   * 将密钥记录转换为对外展示的脱敏状态记录，遮蔽明文值。
   * @param record 原始密钥记录。
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
   * 停用指定 provider 和作用域下的所有密钥，用于新密钥激活时。
   * @param providerId provider 标识。
   * @param scope 作用域。
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
   * 查找指定作用域下的激活密钥引用，未找到时返回空字符串。
   * @param providerId provider 标识。
   * @param scope 作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 激活密钥的引用标识；不存在时返回空字符串。
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
   * 发布密钥相关事件，通知宿主或其他 Runtime。
   * @param eventName 事件名称（如 "secret.created"、"secret.updated"）。
   * @param secret 发生变化的密钥记录。
  private publishSecretEvent(eventName: string, secret: SecretRecord): void {
    const payloadSecret = this.cloneRecord(secret);
    const payload: SecretEventPayload = {
      secret: payloadSecret,
    };
    this.events.publish<SecretEventPayload>(eventName, payload);
  }

  /**
   * 深拷贝密钥记录，防止外部修改内部状态。
   * @param record 待拷贝的密钥记录。
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
