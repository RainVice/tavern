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
 */
export class PresetRuntime {
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
   * presets 列表，由当前实例内部维护。
   */
  private presets: Map<string, PresetRecord> = new Map<string, PresetRecord>();
  /**
   * bindings 列表，由当前实例内部维护。
   */
  private bindings: Map<string, PresetBindingRecord> = new Map<string, PresetBindingRecord>();

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
   * 从 SDK 内部文件存储恢复预设和绑定关系。
   */
  async loadFromStore(): Promise<void> {
    const store = new JsonStore<PresetStorageSnapshot>(this.requireFiles(), this.storagePath());
    const snapshot = await store.read(this.defaultStorageSnapshot());
    this.presets.clear();
    this.bindings.clear();
    for (let index = 0; index < snapshot.presets.length; index += 1) {
      const preset = this.clonePreset(snapshot.presets[index]);
      this.presets.set(preset.id, preset);
    }
    for (let index = 0; index < snapshot.bindings.length; index += 1) {
      const binding = this.cloneBinding(snapshot.bindings[index]);
      this.bindings.set(this.bindingKey(binding.ownerType, binding.ownerId, binding.presetKind), binding);
    }
  }

  /**
   * 把当前预设和绑定关系写入 SDK 内部文件存储。
   */
  async saveToStore(): Promise<void> {
    const presets = this.clonePresets(Array.from(this.presets.values()));
    const bindings = this.cloneBindings(Array.from(this.bindings.values()));
    const snapshot: PresetStorageSnapshot = {
      schemaVersion: 1,
      presets: presets,
      bindings: bindings,
    };
    await new JsonStore<PresetStorageSnapshot>(this.requireFiles(), this.storagePath()).write(snapshot);
  }

  /**
   * 创建新的预设记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
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
   * 更新指定预设，写回存储并按需发布变更事件。
   * @param presetId 目标预设标识。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
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
   * 读取指定预设，不存在时抛出错误。
   * @param presetId 目标预设标识。
   * @returns 更新或读取后的记录副本。
   */
  getPreset(presetId: string): PresetRecord {
    return this.clonePreset(this.requirePreset(presetId));
  }

  /**
   * 读取Presets列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param kind 记录类型。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 删除指定预设，并清理相关索引或资源引用。
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
   * 把预设对象绑定到指定作用域，后续读取会按该绑定解析。

   * @param ownerId 目标所有者标识。

   * @param presetId 目标预设标识。
   */
  bindPreset(ownerType: string, ownerId: string, presetKind: string, presetId: string): PresetBindingRecord {
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
    this.bindings.set(this.bindingKey(ownerType, ownerId, presetKind), this.cloneBinding(binding));
    const payloadBinding = this.cloneBinding(binding);
    const payload: PresetBoundPayload = {
      binding: payloadBinding,
    };
    this.events.publish<PresetBoundPayload>('preset.bound', payload);
    return this.cloneBinding(binding);
  }

  /**
   * 读取指定Binding，不存在时抛出错误。

   * @param ownerId 目标所有者标识。

   * @returns 更新或读取后的记录副本。
   */
  getBinding(ownerType: string, ownerId: string, presetKind: string): PresetBindingRecord {
    const binding = this.bindings.get(this.bindingKey(ownerType, ownerId, presetKind));
    if (binding === undefined) {
      throw new Error(`Preset binding not found: ${ownerType}/${ownerId}/${presetKind}`);
    }
    return this.cloneBinding(binding);
  }

  /**
   * 读取Bindings列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @param ownerId 目标所有者标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listBindings(ownerType: string, ownerId: string): Array<PresetBindingRecord> {
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
   * 导出预设，用于备份、迁移或与 SillyTavern 数据互通。
   * @param presetId 目标预设标识。
   * @returns 可持久化或可传输的导出内容。
   */
  exportPreset(presetId: string): PresetExportData {
    const preset = this.clonePreset(this.requirePreset(presetId));
    const data: PresetExportData = {
      preset: preset,
    };
    return data;
  }

  /**
   * 从外部数据导入Preset 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   * @param newId 目标新记录标识。
   * @returns 更新或读取后的记录副本。
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
   * 执行 migratePreset 的内部处理步骤，供当前模块复用。
   * @param presetId 目标预设标识。


   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  migratePreset(presetId: string, targetVersion: number, fields: Array<PresetField>): PresetRecord {
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
   * 读取必须存在的Preset 值，缺失时抛出错误。
   * @param presetId 目标预设标识。
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
   * 复制Preset 值，避免外部修改内部状态。
   * @param record 记录副本。
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
   * 复制Presets 列表，避免外部修改内部状态。
   * @param records 记录副本列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private clonePresets(records: Array<PresetRecord>): Array<PresetRecord> {
    const result = new Array<PresetRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.clonePreset(records[index]));
    }
    return result;
  }

  /**
   * 复制Binding 值，避免外部修改内部状态。
   */
  private cloneBinding(binding: PresetBindingRecord): PresetBindingRecord {
    return {
      ownerType: binding.ownerType,
      ownerId: binding.ownerId,
      presetKind: binding.presetKind,
      presetId: binding.presetId,
    };
  }

  private cloneBindings(bindings: Array<PresetBindingRecord>): Array<PresetBindingRecord> {
    const cloned = new Array<PresetBindingRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      cloned.push(this.cloneBinding(bindings[index]));
    }
    return cloned;
  }

  /**
   * 复制Fields 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 移除预设绑定，用于解除注册、绑定或索引关系。
   * @param presetId 目标预设标识。
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
   * 把预设对象绑定到指定作用域，后续读取会按该绑定解析。

   * @param ownerId 目标所有者标识。
   */
  private bindingKey(ownerType: string, ownerId: string, presetKind: string): string {
    return `${ownerType}:${ownerId}:${presetKind}`;
  }

  /**
   * 发布预设事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。

   */
  private publishPresetEvent(eventName: string, preset: PresetRecord): void {
    const payloadPreset = this.clonePreset(preset);
    const payload: PresetEventPayload = {
      preset: payloadPreset,
    };
    this.events.publish<PresetEventPayload>(eventName, payload);
  }
}
