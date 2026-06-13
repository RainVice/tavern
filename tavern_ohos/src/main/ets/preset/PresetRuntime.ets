import { EventBus } from '../runtime/EventBus';
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

export class PresetRuntime {
  private events: EventBus;
  private presets: Map<string, PresetRecord> = new Map<string, PresetRecord>();
  private bindings: Map<string, PresetBindingRecord> = new Map<string, PresetBindingRecord>();

  constructor(events: EventBus) {
    this.events = events;
  }

  createPreset(params: PresetCreateParams): PresetRecord {
    if (this.presets.has(params.id)) {
      throw new Error(`Preset already exists: ${params.id}`);
    }
    const record: PresetRecord = {
      id: params.id,
      name: params.name,
      kind: params.kind,
      enabled: params.enabled,
      version: params.version,
      fields: this.cloneFields(params.fields),
      migratedFrom: params.migratedFrom,
    };
    this.presets.set(record.id, this.clonePreset(record));
    this.publishPresetEvent('preset.created', record);
    return this.clonePreset(record);
  }

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

  getPreset(presetId: string): PresetRecord {
    return this.clonePreset(this.requirePreset(presetId));
  }

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
    const payload: PresetBoundPayload = {
      binding: this.cloneBinding(binding),
    };
    this.events.publish<PresetBoundPayload>('preset.bound', payload);
    return this.cloneBinding(binding);
  }

  getBinding(ownerType: string, ownerId: string, presetKind: string): PresetBindingRecord {
    const binding = this.bindings.get(this.bindingKey(ownerType, ownerId, presetKind));
    if (binding === undefined) {
      throw new Error(`Preset binding not found: ${ownerType}/${ownerId}/${presetKind}`);
    }
    return this.cloneBinding(binding);
  }

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

  exportPreset(presetId: string): PresetExportData {
    const data: PresetExportData = {
      preset: this.clonePreset(this.requirePreset(presetId)),
    };
    return data;
  }

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

  migratePreset(presetId: string, targetVersion: number, fields: Array<PresetField>): PresetRecord {
    const record = this.requirePreset(presetId);
    const fromVersion = record.version;
    record.version = targetVersion;
    record.fields = this.cloneFields(fields);
    record.migratedFrom = `${fromVersion}`;
    const payload: PresetMigratedPayload = {
      preset: this.clonePreset(record),
      fromVersion: fromVersion,
      toVersion: targetVersion,
    };
    this.events.publish<PresetMigratedPayload>('preset.migrated', payload);
    this.publishPresetEvent('preset.updated', record);
    return this.clonePreset(record);
  }

  private requirePreset(presetId: string): PresetRecord {
    const record = this.presets.get(presetId);
    if (record === undefined) {
      throw new Error(`Preset not found: ${presetId}`);
    }
    return record;
  }

  private clonePreset(record: PresetRecord): PresetRecord {
    const cloned: PresetRecord = {
      id: record.id,
      name: record.name,
      kind: record.kind,
      enabled: record.enabled,
      version: record.version,
      fields: this.cloneFields(record.fields),
      migratedFrom: record.migratedFrom,
    };
    return cloned;
  }

  private clonePresets(records: Array<PresetRecord>): Array<PresetRecord> {
    const result = new Array<PresetRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.clonePreset(records[index]));
    }
    return result;
  }

  private cloneBinding(binding: PresetBindingRecord): PresetBindingRecord {
    return {
      ownerType: binding.ownerType,
      ownerId: binding.ownerId,
      presetKind: binding.presetKind,
      presetId: binding.presetId,
    };
  }

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

  private removeBindingsForPreset(presetId: string): void {
    const keys = Array.from(this.bindings.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const binding = this.bindings.get(keys[index]);
      if (binding !== undefined && binding.presetId === presetId) {
        this.bindings.delete(keys[index]);
      }
    }
  }

  private bindingKey(ownerType: string, ownerId: string, presetKind: string): string {
    return `${ownerType}:${ownerId}:${presetKind}`;
  }

  private publishPresetEvent(eventName: string, preset: PresetRecord): void {
    const payload: PresetEventPayload = {
      preset: this.clonePreset(preset),
    };
    this.events.publish<PresetEventPayload>(eventName, payload);
  }
}
