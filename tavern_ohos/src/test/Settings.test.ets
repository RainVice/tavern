import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  InMemoryFileStore,
  SettingsRuntime,
  type RuntimeEvent,
  type SettingChangedPayload,
  type SettingEntry,
  type SettingSchemaCreateParams,
  type SettingSchemaRecord,
  type SettingSnapshot,
} from '../../Index';

export default function settingsUnitTest() {
  describe('settings runtime', () => {
    it('registers schema defaults and resolves scoped settings with fallback', 0, () => {
      // 运行时实例。
      const runtime = new SettingsRuntime(new EventBus());
      runtime.registerSchema(makeSchema('theme', 'light', 'string', 1));
      runtime.setSetting('global', '', 'theme', 'dark');
      runtime.setSetting('chat', 'chat-1', 'theme', 'blue');

      expect(runtime.getSetting('global', '', 'theme')).assertEqual('dark');
      expect(runtime.getEffectiveSetting('chat', 'chat-1', 'theme')).assertEqual('blue');
      expect(runtime.getEffectiveSetting('chat', 'chat-2', 'theme')).assertEqual('dark');
      expect(runtime.getEffectiveSetting('character', 'char-1', 'theme')).assertEqual('dark');
      expect(runtime.getSetting('plugin', 'plugin-1', 'theme')).assertEqual('light');
    });

    it('emits settings.changed with old and new values', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SettingsRuntime(bus);
      const changed = new Array<string>();
      bus.subscribe<SettingChangedPayload>('settings.changed', (event: RuntimeEvent<SettingChangedPayload>) => {
        changed.push(`${event.payload.scope}:${event.payload.key}:${event.payload.oldValue}:${event.payload.newValue}`);
      });
      runtime.registerSchema(makeSchema('autosave', 'off', 'string', 1));

      runtime.setSetting('user', 'user-1', 'autosave', 'on');

      expect(changed.length).assertEqual(1);
      expect(changed[0]).assertEqual('user:autosave:off:on');
    });

    it('migrates settings and records snapshots', 0, () => {
      // 运行时实例。
      const runtime = new SettingsRuntime(new EventBus());
      runtime.registerSchema(makeSchema('old_mode', 'classic', 'string', 1));
      runtime.registerSchema(makeSchema('mode', 'classic', 'string', 2));
      runtime.setSetting('global', '', 'old_mode', 'modern');
      const snapshot: SettingSnapshot = runtime.migrateSetting('global', '', 'old_mode', 'mode', 2);

      expect(runtime.getSetting('global', '', 'mode')).assertEqual('modern');
      expect(runtime.getSetting('global', '', 'old_mode')).assertEqual('classic');
      expect(snapshot.schemaVersion).assertEqual(2);
      expect(snapshot.entries.length).assertEqual(1);
      expect(snapshot.migrationMetadata.length).assertEqual(1);
    });

    it('persists schemas, entries, and migration metadata', 0, async () => {
      // 文件存储实例。
      const files = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new SettingsRuntime(new EventBus(), files, 'tavern-data', 'default');
      runtime.registerSchema(makeSchema('persist_mode', 'classic', 'string', 1));
      runtime.registerSchema(makeSchema('persist_mode_v2', 'classic', 'string', 2));
      runtime.setSetting('global', '', 'persist_mode', 'modern');
      runtime.migrateSetting('global', '', 'persist_mode', 'persist_mode_v2', 2);
      await runtime.saveToStore();

      const restored = new SettingsRuntime(new EventBus(), files, 'tavern-data', 'default');
      await restored.loadFromStore();

      expect(await files.exists('tavern-data/users/default/settings.json')).assertTrue();
      expect(restored.getSetting('global', '', 'persist_mode_v2')).assertEqual('modern');
      expect(restored.snapshot().migrationMetadata.length).assertEqual(1);
    });

    it('does not expose internal schemas, entries, or snapshots', 0, () => {
      // 运行时实例。
      const runtime = new SettingsRuntime(new EventBus());
      const schema: SettingSchemaRecord = runtime.registerSchema(makeSchema('copy_mode', 'classic', 'string', 1));
      schema.defaultValue = 'external-default';
      expect(runtime.getSetting('global', '', 'copy_mode')).assertEqual('classic');

      // 条目记录。
      const entry: SettingEntry = runtime.setSetting('global', '', 'copy_mode', 'modern');
      entry.value = 'external-value';
      expect(runtime.getSetting('global', '', 'copy_mode')).assertEqual('modern');
      const schemas = runtime.listSchemas();
      schemas[0].defaultValue = 'listed-default';
      const entries = runtime.listEntries('global', '');
      entries[0].value = 'listed-value';
      expect(runtime.getSetting('global', '', 'copy_mode')).assertEqual('modern');
      const snapshot = runtime.snapshot();
      snapshot.entries[0].value = 'snapshot-value';
      expect(runtime.getSetting('global', '', 'copy_mode')).assertEqual('modern');
    });
  });
}

/**
 * 封装单元测试中的 makeSchema 步骤，供公开方法复用。
 * @param key 键名。
 * @param defaultValue 未输入时使用的默认值。
 */
function makeSchema(key: string, defaultValue: string, valueType: string, version: number): SettingSchemaCreateParams {
  return {
    key: key,
    defaultValue: defaultValue,
    valueType: valueType,
    schemaVersion: version,
    description: key,
  };
}
