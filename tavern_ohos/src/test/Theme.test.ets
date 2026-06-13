import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  InMemoryFileStore,
  ThemeRuntime,
  type RuntimeEvent,
  type TavernFileStore,
  type ThemeActivatedPayload,
  type ThemeExportData,
  type ThemeRecord,
  type ThemeSaveParams,
} from '../../Index';

export default function themeUnitTest() {
  describe('theme runtime', () => {
    it('saves theme files and lists themes by name', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new ThemeRuntime(files, new EventBus());
      const saved: ThemeRecord = await runtime.saveTheme(makeTheme('dark', '{"fontScale":1}'));
      await runtime.saveTheme(makeTheme('light', '{"fontScale":1.1}'));
      const content = await files.readText('tavern-data/users/default/assets/themes/dark.json');
      const themes = await runtime.listThemes();

      expect(saved.name).assertEqual('dark');
      expect(content).assertEqual('{"fontScale":1}');
      expect(themes.length).assertEqual(2);
      expect(themes[0].name).assertEqual('dark');
    });

    it('activates themes and stores current background state', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ThemeRuntime(files, bus);
      const activated = new Array<string>();
      bus.subscribe<ThemeActivatedPayload>('theme.activated', (event: RuntimeEvent<ThemeActivatedPayload>) => {
        activated.push(`${event.payload.themeName}:${event.payload.theme.name}`);
      });
      await runtime.saveTheme(makeTheme('dark', '{"fontScale":1}'));
      const theme = await runtime.activateTheme('dark');
      await runtime.setActiveBackground('forest.jpg');
      const state = await files.readText('tavern-data/users/default/settings/theme-state.json');

      expect(theme.active).assertTrue();
      expect(runtime.getActiveThemeName()).assertEqual('dark');
      expect(runtime.getActiveBackground()).assertEqual('forest.jpg');
      expect(state.indexOf('forest.jpg') >= 0).assertTrue();
      expect(activated[0]).assertEqual('dark:dark');
    });

    it('exports imports and deletes themes', 0, async () => {
      // 来源类型。
      const source = new ThemeRuntime(new InMemoryFileStore(), new EventBus());
      await source.saveTheme(makeTheme('dark', '{"fontScale":1}'));
      await source.saveTheme(makeTheme('light', '{"fontScale":1.1}'));
      await source.activateTheme('light');
      const exported: ThemeExportData = await source.exportThemes();
      const target = new ThemeRuntime(new InMemoryFileStore(), new EventBus());
      await target.importThemes(exported, true);
      await target.deleteTheme('dark');
      const imported = await target.listThemes();

      expect(target.getActiveThemeName()).assertEqual('light');
      expect(imported.length).assertEqual(1);
      expect(imported[0].name).assertEqual('light');
    });

    it('净化主题文件路径且导入时不信任外部 path', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new ThemeRuntime(files, new EventBus());
      const saved = await runtime.saveTheme(makeTheme('../dark', '{"fontScale":1}'));
      const safeContent = await files.readText('tavern-data/users/default/assets/themes/..~2fdark.json');
      const escapedExists = await files.exists('tavern-data/users/default/assets/dark.json');

      expect(saved.name).assertEqual('../dark');
      expect(saved.path).assertEqual('tavern-data/users/default/assets/themes/..~2fdark.json');
      expect(safeContent).assertEqual('{"fontScale":1}');
      expect(escapedExists).assertFalse();
      const exported: ThemeExportData = await runtime.exportThemes();
      exported.themes[0].path = '../escape.json';
      exported.state.activeThemeName = 'missing-theme';
      const targetFiles: TavernFileStore = new InMemoryFileStore();
      const target = new ThemeRuntime(targetFiles, new EventBus());
      await target.importThemes(exported, true);
      const importedContent = await targetFiles.readText('tavern-data/users/default/assets/themes/..~2fdark.json');
      const importedEscapedExists = await targetFiles.exists('tavern-data/users/default/assets/escape.json');

      expect(importedContent).assertEqual('{"fontScale":1}');
      expect(importedEscapedExists).assertFalse();
      expect(target.getActiveThemeName()).assertEqual('');
    });
  });
}

/**
 * 封装单元测试中的 makeTheme 步骤，供公开方法复用。
 * @param name 显示名称或注册名称。
 * @param contentJson content JSON 字符串。
 */
function makeTheme(name: string, contentJson: string): ThemeSaveParams {
  return {
    name: name,
    contentJson: contentJson,
    metadataJson: '{"source":"test"}',
  };
}
