import { EventBus } from '../runtime/EventBus';
import type { PresetKind } from '../contracts/PublicContracts';
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
   * 预设记录映射表。
   */
  private presets: Map<string, PresetRecord> = new Map<string, PresetRecord>();
  /**
   * 绑定关系记录映射表。
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
   * @param params 创建参数，包含 id、name、kind、fields 等预设属性。
   * @returns 新创建的预设记录副本。
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
   * @param params 更新参数，包含 name、enabled、version、fields 等属性。
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
   * 读取指定预设，不存在时抛出错误。
   * @param presetId 目标预设标识。
   * @returns 预设记录副本。
   */
  getPreset(presetId: string): PresetRecord {
    return this.clonePreset(this.requirePreset(presetId));
  }

  /**
   * 读取 Presets 列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param kind 按预设类型过滤；传入空字符串时返回所有预设。
   * @returns 绑定记录列表副本
   */
  listPresets(kind: PresetKind): Array<PresetRecord> {
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
   * @param ownerType 所有者类型。
   * @param ownerId 目标所有者标识。
   * @param presetKind 预设类型。
   * @param presetId 目标预设标识。
   * @returns 新的绑定关系记录。
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
   * 读取指定 Binding，不存在时抛出错误。
   * @param ownerType 所有者类型。
   * @param ownerId 目标所有者标识。
   * @param presetKind 预设类型。
   * @returns 绑定关系记录副本。
   */
  getBinding(ownerType: string, ownerId: string, presetKind: string): PresetBindingRecord {
    const binding = this.bindings.get(this.bindingKey(ownerType, ownerId, presetKind));
    if (binding === undefined) {
      throw new Error(`Preset binding not found: ${ownerType}/${ownerId}/${presetKind}`);
    }
    return this.cloneBinding(binding);
  }

  /**
   * 读取 Bindings 列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param ownerType 所有者类型。
   * @param ownerId 目标所有者标识。
   * @returns 符合条件的绑定关系记录列表副本，调用方可安全读取。
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
   * 从外部数据导入 Preset，转换为当前运行时的数据结构并写入存储。
   * @param data 导入或恢复使用的序列化数据。
   * @param newId 导入后赋予的新记录标识。
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
   * 迁移预设至目标版本，更新 version 和 fields 并发布迁移事件。
   * @param presetId 目标预设标识。
   * @param targetVersion 迁移的目标版本号。
   * @param fields 迁移后的字段列表。
   * @returns 迁移后的预设记录副本。
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
   * 读取必须存在的 Preset，缺失时抛出错误。
   * @param presetId 目标预设标识。
   * @returns 已存在的预设记录引用（非副本，直接操作内部状态）。
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
   * 复制 Preset 记录，避免外部修改内部状态。
   * @param record 待复制的预设记录。
   * @returns 全新副本。
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
   * 复制 Presets 列表，避免外部修改内部状态。
   * @param records 待复制的预设记录列表。
   * @returns 全新副本列表。
   */
  private clonePresets(records: Array<PresetRecord>): Array<PresetRecord> {
    const result = new Array<PresetRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.clonePreset(records[index]));
    }
    return result;
  }

  /**
   * 复制 Binding 记录，避免外部修改内部状态。
   * @param binding 待复制的绑定关系记录。
   * @returns 全新副本。
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
   * 复制 Fields 列表，避免外部修改内部状态。
   * @param fields 待复制的字段列表。
   * @returns 全新副本列表。
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
   * 移除指定预设的所有绑定关系，用于预设被删除时清理绑定索引。
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
   * 生成绑定关系在 Map 中的唯一键。
   * @param ownerType 所有者类型。
   * @param ownerId 所有者标识。
   * @param presetKind 预设类型。
   * @returns 形如 "ownerType:ownerId:presetKind" 的键。
   */
  private bindingKey(ownerType: string, ownerId: string, presetKind: string): string {
    return `${ownerType}:${ownerId}:${presetKind}`;
  }

  /**
   * 发布预设事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要发布的事件名，如 "preset.created"。
   * @param preset 参与事件的预设记录。
   */
  private publishPresetEvent(eventName: string, preset: PresetRecord): void {
    const payloadPreset = this.clonePreset(preset);
    const payload: PresetEventPayload = {
      preset: payloadPreset,
    };
    this.events.publish<PresetEventPayload>(eventName, payload);
  }
}
