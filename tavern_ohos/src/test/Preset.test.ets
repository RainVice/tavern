import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  PresetRuntime,
  type PresetBindingRecord,
  type PresetCreateParams,
  type PresetExportData,
  type PresetField,
  type PresetMigratedPayload,
  type PresetRecord,
  type PresetUpdateParams,
  type RuntimeEvent,
} from '../../Index';

export default function presetUnitTest() {
  describe('preset runtime', () => {
    it('creates, updates, lists, and deletes presets by kind', 0, () => {
      // 运行时实例。
      const runtime = new PresetRuntime(new EventBus());
      const created = runtime.createPreset(makePreset('preset-1', 'Default', 'generation'));
      const updated = runtime.updatePreset(created.id, makeUpdate('Renamed'));
      runtime.createPreset(makePreset('preset-2', 'Context', 'context'));
      const generationPresets: Array<PresetRecord> = runtime.listPresets('generation');
      const allPresets: Array<PresetRecord> = runtime.listPresets('');

      expect(updated.name).assertEqual('Renamed');
      expect(runtime.getPreset('preset-1').fields[0].value).assertEqual('0.7');
      expect(generationPresets.length).assertEqual(1);
      expect(allPresets.length).assertEqual(2);
      runtime.deletePreset('preset-1');
      expect(runtime.listPresets('generation').length).assertEqual(0);
    });

    it('binds presets to chat, character, group, and profile owners', 0, () => {
      // 运行时实例。
      const runtime = new PresetRuntime(new EventBus());
      runtime.createPreset(makePreset('preset-3', 'Instruct', 'instruct'));
      const binding: PresetBindingRecord = runtime.bindPreset('chat', 'chat-1', 'instruct', 'preset-3');
      const found = runtime.getBinding('chat', 'chat-1', 'instruct');
      const chatBindings: Array<PresetBindingRecord> = runtime.listBindings('chat', 'chat-1');

      expect(binding.ownerId).assertEqual('chat-1');
      expect(found.presetId).assertEqual('preset-3');
      expect(chatBindings.length).assertEqual(1);
    });

    it('rejects duplicate preset ids during create and import', 0, () => {
      // 运行时实例。
      const runtime = new PresetRuntime(new EventBus());
      runtime.createPreset(makePreset('preset-duplicate', 'Original', 'generation'));
      const exported: PresetExportData = runtime.exportPreset('preset-duplicate');
      let createThrown = false;
      let importThrown = false;

      try {
        runtime.createPreset(makePreset('preset-duplicate', 'Replacement', 'generation'));
      } catch (error) {
        createThrown = true;
      }
      try {
        runtime.importPreset(exported, 'preset-duplicate');
      } catch (error) {
        importThrown = true;
      }

      expect(createThrown).assertTrue();
      expect(importThrown).assertTrue();
      expect(runtime.getPreset('preset-duplicate').name).assertEqual('Original');
    });

    it('exports, imports, and migrates presets with events', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new PresetRuntime(bus);
      const migratedIds = new Array<string>();
      bus.subscribe<PresetMigratedPayload>('preset.migrated', (event: RuntimeEvent<PresetMigratedPayload>) => {
        migratedIds.push(event.payload.preset.id);
      });
      runtime.createPreset(makePreset('preset-4', 'System', 'system'));
      const exported: PresetExportData = runtime.exportPreset('preset-4');
      const imported = runtime.importPreset(exported, 'preset-5');
      const migrated = runtime.migratePreset(imported.id, 2, [makeField('system_prompt', 'Be concise.', 'string')]);

      expect(imported.id).assertEqual('preset-5');
      expect(migrated.version).assertEqual(2);
      expect(migrated.fields[0].name).assertEqual('system_prompt');
      expect(migratedIds.length).assertEqual(1);
      expect(migratedIds[0]).assertEqual('preset-5');
    });

    it('does not expose internal preset fields or bindings', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new PresetRuntime(bus);
      bus.subscribe<PresetMigratedPayload>('preset.migrated', (event: RuntimeEvent<PresetMigratedPayload>) => {
        event.payload.preset.fields[0].value = 'event-mutated';
      });
      const created = runtime.createPreset(makePreset('preset-copy', 'Copy', 'generation'));
      created.fields[0].value = 'external';
      expect(runtime.getPreset('preset-copy').fields[0].value).assertEqual('0.7');
      const listed = runtime.listPresets('');
      listed[0].fields[0].value = 'listed';
      expect(runtime.getPreset('preset-copy').fields[0].value).assertEqual('0.7');
      const binding = runtime.bindPreset('chat', 'chat-copy', 'generation', 'preset-copy');
      binding.presetId = 'external-preset';
      const bindings = runtime.listBindings('chat', 'chat-copy');
      bindings[0].presetId = 'listed-preset';
      expect(runtime.getBinding('chat', 'chat-copy', 'generation').presetId).assertEqual('preset-copy');

      runtime.migratePreset('preset-copy', 2, [makeField('temperature', '0.8', 'number')]);
      expect(runtime.getPreset('preset-copy').fields[0].value).assertEqual('0.8');
    });
  });
}

/**
 * 封装单元测试中的 makePreset 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param name 显示名称或注册名称。
 * @param kind 记录类型。
 */
function makePreset(id: string, name: string, kind: string): PresetCreateParams {
  return {
    id: id,
    name: name,
    kind: kind,
    enabled: true,
    version: 1,
    fields: [
      makeField('temperature', '0.7', 'number'),
    ],
    migratedFrom: '',
  };
}

/**
 * 封装单元测试中的 makeUpdate 步骤，供公开方法复用。
 * @param name 显示名称或注册名称。
 */
function makeUpdate(name: string): PresetUpdateParams {
  return {
    name: name,
    enabled: true,
    version: 1,
    fields: [
      makeField('temperature', '0.7', 'number'),
    ],
    migratedFrom: '',
  };
}

/**
 * 封装单元测试中的 makeField 步骤，供公开方法复用。
 * @param name 显示名称或注册名称。
 * @param value 要保存或比较的字段值。
 */
function makeField(name: string, value: string, valueType: string): PresetField {
  return {
    name: name,
    value: value,
    valueType: valueType,
  };
}
