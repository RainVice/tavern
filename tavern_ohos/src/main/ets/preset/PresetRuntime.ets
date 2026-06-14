import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  PresetBindingRecord,
  PresetBoundPayload,
  PresetCreateParams,
  PresetDeletedPayload,
  PresetEventPayload,
  PresetExportData,
  PresetField,
  PresetMigratedPayload,
  PresetRecord,
  PresetUpdateParams,
} from './PresetModels';

interface PresetStorageSnapshot {
  schemaVersion: number;
  presets: Array<PresetRecord>;
  bindings: Array<PresetBindingRecord>;
}

/**
 * 提供预设相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 调用方（如模型调用客户端、UI 配置界面）通过此运行时管理预设的创建、编辑、绑定和版本迁移。
 */
export class PresetRuntime {
  /**
   * 事件总线，用于在预设创建、更新、删除、绑定、迁移时发布事件。
   */
  private events: EventBus;
  /**
   * 文件存储适配器；未传入时仅使用内存态，不进行持久化。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 数据持久化的根路径，决定了预设数据在文件系统中的存储位置。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 当前用户的标识，用于在文件系统中隔离不同用户的预设数据。
   */
  private userId: string = 'default';
  /**
   * 预设记录的内存索引，键为预设 ID。
   * 用于所有预设 CRUD 操作和绑定解析。
   */
  private presets: Map<string, PresetRecord> = new Map<string, PresetRecord>();
  /**
   * 预设绑定记录的内存索引，键为 ownerType:ownerId:presetKind。
   * 用于 bindPreset 和 getBinding 中的作用域解析。
   */
  private bindings: Map<string, PresetBindingRecord> = new Map<string, PresetBindingRecord>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例，用于发送预设生命周期事件。
   * @param files 可选的文件存储适配器，提供后将支持持久化。
   * @param rootPath 数据持久化根路径。
   * @param userId 当前用户标识。
   */
  constructor(
    events: EventBus,
    files?: TavernFileStore,
    rootPath: string = 'tavern-data',
    userId: string = 'default',
  ) {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从文件存储中恢复预设记录和绑定关系。
   * 调用方在应用启动时调用，确保运行时与持久化数据一致。
   */
  async loadFromStore(): Promise<void> {
    const store = new JsonStore<PresetStorageSnapshot>(
      this.requireFiles(),
      this.storagePath(),
    );
    const snapshot = await store.read(this.defaultStorageSnapshot());
    this.presets.clear();
    this.bindings.clear();
    for (let index = 0; index < snapshot.presets.length; index += 1) {
      const preset = this.clonePreset(snapshot.presets[index]);
      this.presets.set(preset.id, preset);
    }
    for (let index = 0; index < snapshot.bindings.length; index += 1) {
      const binding = this.cloneBinding(snapshot.bindings[index]);
      this.bindings.set(
        this.bindingKey(binding.ownerType, binding.ownerId, binding.presetKind),
        binding,
      );
    }
  }

  /**
   * 将当前内存中的预设记录和绑定关系写入文件存储。
   * 调用方在预设管理操作（创建、更新、删除、绑定）完成后调用。
   */
  async saveToStore(): Promise<void> {
    const presets = this.clonePresets(Array.from(this.presets.values()));
    const bindings = this.cloneBindings(Array.from(this.bindings.values()));
    const snapshot: PresetStorageSnapshot = {
      schemaVersion: 1,
      presets: presets,
      bindings: bindings,
    };
    await new JsonStore<PresetStorageSnapshot>(
      this.requireFiles(),
      this.storagePath(),
    ).write(snapshot);
  }

  /**
   * 创建新的预设记录，存入内存并发布创建事件。
   * 调用方（如 UI 界面）在用户创建新预设时调用。
   * @param params 创建预设的参数。
   * @returns 创建的预设记录副本。
   */
  createPreset(params: PresetCreateParams): PresetRecord {
    if (this.presets.has(params.id)) {
      throw new Error(`Preset already exists: ${params.id}`);
    }
    const fields = this.cloneFields(params.fields);
    const record: PresetRecord = {
      id: params.id,
      name: params.name,
      kind: params.kind,
      enabled: params.enabled,
      version: params.version,
      fields: fields,
      migratedFrom: params.migratedFrom,
    };
    this.presets.set(record.id, this.clonePreset(record));
    this.publishPresetEvent('preset.created', record);
    return this.clonePreset(record);
  }

  /**
   * 更新指定预设的字段，存入内存并发布更新事件。
   * 调用方（如 UI 界面）在用户编辑预设时调用。
   * @param presetId 目标预设标识。
   * @param params 更新后的参数字段，将替换目标预设的完整数据。
   * @returns 更新后的预设记录副本。
   */
  updatePreset(presetId: string, params: PresetUpdateParams): PresetRecord {
    const record = this.requirePreset(presetId);
    record.name = params.name;
    record.enabled = params.enabled;
    record.version = params.version;
    record.fields = this.cloneFields(params.fields);
    record.migratedFrom = params.migratedFrom;
    this.publishPresetEvent('preset.updated', record);
    return this.clonePreset(record);
  }

  /**
   * 按 ID 读取预设记录，不存在时抛出异常。
   * @param presetId 目标预设标识。
   * @returns 预设记录副本。
   */
  getPreset(presetId: string): PresetRecord {
    return this.clonePreset(this.requirePreset(presetId));
  }

  /**
   * 按种类过滤并返回预设记录副本列表。
   * 调用方（如 UI 界面或模型调用客户端）在按预设种类筛选时使用。
   * @param kind 预设种类标识，为空时返回全部。
   * @returns 预设记录列表副本。
   */
  listPresets(kind: string): Array<PresetRecord> {
    const records = Array.from(this.presets.values());
    if (kind.length === 0) {
      return this.clonePresets(records);
    }
    const filtered = new Array<PresetRecord>();
    for (let index = 0; index < records.length; index += 1) {
      if (records[index].kind === kind) {
        filtered.push(this.clonePreset(records[index]));
      }
    }
    return filtered;
  }

  /**
   * 删除指定预设，清理相关绑定并发布删除事件。
   * 调用方（如 UI 界面）在用户删除预设时调用。
   * @param presetId 目标预设标识。
   */
  deletePreset(presetId: string): void {
    const record = this.requirePreset(presetId);
    this.presets.delete(presetId);
    this.removeBindingsForPreset(presetId);
    const payload: PresetDeletedPayload = {
      presetId: presetId,
      kind: record.kind,
    };
    this.events.publish<PresetDeletedPayload>('preset.deleted', payload);
  }

  /**
   * 将预设绑定到指定作用域，后续可通过作用域解析出对应预设。
   * 调用方（如角色或聊天配置界面）在需要为特定作用域指定预设时调用。
   * @param ownerType 所有者类型（如 character、chat）。
   * @param ownerId 所有者标识。
   * @param presetKind 预设种类。
   * @param presetId 预设标识。
   * @returns 创建的绑定记录副本。
   */
  bindPreset(
    ownerType: string,
    ownerId: string,
    presetKind: string,
    presetId: string,
  ): PresetBindingRecord {
    const preset = this.requirePreset(presetId);
    if (preset.kind !== presetKind) {
      throw new Error(`Preset kind mismatch: ${presetKind}`);
    }
    const binding: PresetBindingRecord = {
      ownerType: ownerType,
      ownerId: ownerId,
      presetKind: presetKind,
      presetId: presetId,
    };
    this.bindings.set(
      this.bindingKey(ownerType, ownerId, presetKind),
      this.cloneBinding(binding),
    );
    const payloadBinding = this.cloneBinding(binding);
    const payload: PresetBoundPayload = {
      binding: payloadBinding,
    };
    this.events.publish<PresetBoundPayload>('preset.bound', payload);
    return this.cloneBinding(binding);
  }

  /**
   * 按所有者信息读取绑定记录，不存在时抛出异常。
   * @param ownerType 所有者类型。
   * @param ownerId 所有者标识。
   * @param presetKind 预设种类。
   * @returns 绑定记录副本。
   */
  getBinding(
    ownerType: string,
    ownerId: string,
    presetKind: string,
  ): PresetBindingRecord {
    const binding = this.bindings.get(
      this.bindingKey(ownerType, ownerId, presetKind),
    );
    if (binding === undefined) {
      throw new Error(
        `Preset binding not found: ${ownerType}/${ownerId}/${presetKind}`,
      );
    }
    return this.cloneBinding(binding);
  }

  /**
   * 返回指定所有者的所有绑定记录副本列表。
   * @param ownerType 所有者类型。
   * @param ownerId 所有者标识。
   * @returns 绑定记录列表。
   */
  listBindings(
    ownerType: string,
    ownerId: string,
  ): Array<PresetBindingRecord> {
    const result = new Array<PresetBindingRecord>();
    const records = Array.from(this.bindings.values());
    for (let index = 0; index < records.length; index += 1) {
      const binding = records[index];
      if (binding.ownerType === ownerType && binding.ownerId === ownerId) {
        result.push(this.cloneBinding(binding));
      }
    }
    return result;
  }

  /**
   * 导出指定预设，用于备份或与外部工具互通。
   * @param presetId 目标预设标识。
   * @returns 预设导出数据。
   */
  exportPreset(presetId: string): PresetExportData {
    const preset = this.clonePreset(this.requirePreset(presetId));
    const data: PresetExportData = {
      preset: preset,
    };
    return data;
  }

  /**
   * 从外部数据导入预设，分配新的 ID 并写入内存。
   * 调用方在从备份恢复或迁移预设时使用。
   * @param data 导入的预设数据。
   * @param newId 导入后使用的新标识，避免与现有预设 ID 冲突。
   * @returns 导入后的预设记录副本。
   */
  importPreset(data: PresetExportData, newId: string): PresetRecord {
    if (this.presets.has(newId)) {
      throw new Error(`Preset already exists: ${newId}`);
    }
    const imported = this.clonePreset(data.preset);
    imported.id = newId;
    this.presets.set(imported.id, imported);
    this.publishPresetEvent('preset.imported', imported);
    return this.clonePreset(imported);
  }

  /**
   * 将预设从当前版本迁移到目标版本，更新字段和版本号并发布迁移事件。
   * 调用方在预设格式发生变更时调用，支持数据结构升级的平滑过渡。
   * @param presetId 目标预设标识。
   * @param targetVersion 迁移目标版本号。
   * @param fields 迁移后的字段列表，适配新版本的数据结构。
   * @returns 迁移后的预设记录副本。
   */
  migratePreset(
    presetId: string,
    targetVersion: number,
    fields: Array<PresetField>,
  ): PresetRecord {
    const record = this.requirePreset(presetId);
    const fromVersion = record.version;
    record.version = targetVersion;
    record.fields = this.cloneFields(fields);
    record.migratedFrom = `${fromVersion}`;
    const payloadPreset = this.clonePreset(record);
    const payload: PresetMigratedPayload = {
      preset: payloadPreset,
      fromVersion: fromVersion,
      toVersion: targetVersion,
    };
    this.events.publish<PresetMigratedPayload>('preset.migrated', payload);
    this.publishPresetEvent('preset.updated', record);
    return this.clonePreset(record);
  }

  /**
   * 按 ID 查找预设，不存在时抛出异常。
   * 由 getPreset、updatePreset、deletePreset、bindPreset、exportPreset、migratePreset 等内部调用。
   * @param presetId 目标预设标识。
   * @returns 匹配的预设记录引用。
   */
  private requirePreset(presetId: string): PresetRecord {
    const record = this.presets.get(presetId);
    if (record === undefined) {
      throw new Error(`Preset not found: ${presetId}`);
    }
    return record;
  }

  private requireFiles(): TavernFileStore {
    if (this.files === undefined) {
      throw new Error('PresetRuntime storage is not configured.');
    }
    return this.files;
  }

  private storagePath(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/presets/index.json`;
  }

  private defaultStorageSnapshot(): PresetStorageSnapshot {
    return {
      schemaVersion: 1,
      presets: new Array<PresetRecord>(),
      bindings: new Array<PresetBindingRecord>(),
    };
  }

  /**
   * 深拷贝 PresetRecord。
   */
  private clonePreset(record: PresetRecord): PresetRecord {
    const fields = this.cloneFields(record.fields);
    const cloned: PresetRecord = {
      id: record.id,
      name: record.name,
      kind: record.kind,
      enabled: record.enabled,
      version: record.version,
      fields: fields,
      migratedFrom: record.migratedFrom,
    };
    return cloned;
  }

  /**
   * 深拷贝 PresetRecord 列表。
   * @returns 预设记录列表副本。
   */
  private clonePresets(
    records: Array<PresetRecord>,
  ): Array<PresetRecord> {
    const result = new Array<PresetRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.clonePreset(records[index]));
    }
    return result;
  }

  /**
   * 深拷贝 PresetBindingRecord。
   */
  private cloneBinding(binding: PresetBindingRecord): PresetBindingRecord {
    return {
      ownerType: binding.ownerType,
      ownerId: binding.ownerId,
      presetKind: binding.presetKind,
      presetId: binding.presetId,
    };
  }

  private cloneBindings(
    bindings: Array<PresetBindingRecord>,
  ): Array<PresetBindingRecord> {
    const cloned = new Array<PresetBindingRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      cloned.push(this.cloneBinding(bindings[index]));
    }
    return cloned;
  }

  /**
   * 深拷贝 PresetField 列表。
   * @returns 字段列表副本。
   */
  private cloneFields(fields: Array<PresetField>): Array<PresetField> {
    const cloned = new Array<PresetField>();
    for (let index = 0; index < fields.length; index += 1) {
      const field: PresetField = {
        name: fields[index].name,
        value: fields[index].value,
        valueType: fields[index].valueType,
      };
      cloned.push(field);
    }
    return cloned;
  }

  /**
   * 删除与指定预设相关的所有绑定记录。
   * 在 deletePreset 中调用，确保预设删除后其绑定关系也被清理。
   * @param presetId 预设标识。
   */
  private removeBindingsForPreset(presetId: string): void {
    const keys = Array.from(this.bindings.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const binding = this.bindings.get(keys[index]);
      if (binding !== undefined && binding.presetId === presetId) {
        this.bindings.delete(keys[index]);
      }
    }
  }

  /**
   * 生成绑定记录键：ownerType:ownerId:presetKind。
   * 用于 bindings Map 的键生成。
   */
  private bindingKey(
    ownerType: string,
    ownerId: string,
    presetKind: string,
  ): string {
    return `${ownerType}:${ownerId}:${presetKind}`;
  }

  /**
   * 发布预设事件，携带预设记录副本。
   * 在 createPreset、updatePreset、importPreset 中调用。
   * @param eventName 事件名称。
   * @param preset 关联的预设记录。
   */
  private publishPresetEvent(eventName: string, preset: PresetRecord): void {
    const payloadPreset = this.clonePreset(preset);
    const payload: PresetEventPayload = {
      preset: payloadPreset,
    };
    this.events.publish<PresetEventPayload>(eventName, payload);
  }
}
