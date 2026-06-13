import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  I18nRuntime,
  type I18nBundle,
  type I18nEntry,
  type I18nLocaleChangedPayload,
  type I18nMissingPayload,
  type I18nParam,
  type RuntimeEvent,
} from '../../Index';

export default function i18nUnitTest() {
  describe('i18n runtime', () => {
    it('registers locale bundles and translates errors, commands, plugins, settings, import/export, and UI request keys', 0, () => {
      const bus = new EventBus();
      const runtime = new I18nRuntime(bus, 'en');
      const changes = new Array<string>();
      bus.subscribe<I18nLocaleChangedPayload>('i18n.locale.changed', (event: RuntimeEvent<I18nLocaleChangedPayload>) => {
        changes.push(event.payload.locale);
      });

      const bundle: I18nBundle = {
        locale: 'zh-cn',
        source: 'core',
        entries: [
          makeEntry('error.network', '网络错误：${reason}', 'error'),
          makeEntry('command.help.send', '发送消息', 'command'),
          makeEntry('plugin.name.memory', '记忆插件', 'plugin'),
          makeEntry('setting.temperature', '温度', 'setting'),
          makeEntry('export.done', '已导出 ${count} 个文件', 'import-export'),
          makeEntry('ui.confirm.delete', '删除 ${name}？', 'ui-request'),
        ],
      };
      runtime.registerBundle(bundle);
      runtime.setLocale('zh-cn');

      expect(runtime.translate('error.network', 'Network error', [makeParam('reason', '超时')])).assertEqual('网络错误：超时');
      expect(runtime.translate('command.help.send', 'Send message', new Array<I18nParam>())).assertEqual('发送消息');
      expect(runtime.translate('plugin.name.memory', 'Memory plugin', new Array<I18nParam>())).assertEqual('记忆插件');
      expect(runtime.translate('setting.temperature', 'Temperature', new Array<I18nParam>())).assertEqual('温度');
      expect(runtime.translate('export.done', 'Exported files', [makeParam('count', '3')])).assertEqual('已导出 3 个文件');
      expect(runtime.translate('ui.confirm.delete', 'Delete?', [makeParam('name', 'Alice')])).assertEqual('删除 Alice？');
      expect(changes.length).assertEqual(1);
      expect(changes[0]).assertEqual('zh-cn');
    });

    it('falls back to default locale and tracks missing keys', 0, () => {
      const bus = new EventBus();
      const runtime = new I18nRuntime(bus, 'en');
      const missing = new Array<string>();
      bus.subscribe<I18nMissingPayload>('i18n.missing', (event: RuntimeEvent<I18nMissingPayload>) => {
        missing.push(event.payload.key);
      });

      runtime.registerBundle({
        locale: 'en',
        source: 'core',
        entries: [makeEntry('setting.theme', 'Theme', 'setting')],
      });
      runtime.setLocale('fr-fr');

      expect(runtime.translate('setting.theme', 'theme fallback', new Array<I18nParam>())).assertEqual('Theme');
      expect(runtime.translate('missing.key', 'Fallback text', new Array<I18nParam>())).assertEqual('Fallback text');
      expect(missing.length).assertEqual(1);
      expect(missing[0]).assertEqual('missing.key');
      expect(runtime.listMissing('fr-fr').length).assertEqual(1);
    });

    it('adds plugin locale data without overriding core keys', 0, () => {
      const runtime = new I18nRuntime(new EventBus(), 'en');
      runtime.registerBundle({
        locale: 'en',
        source: 'core',
        entries: [makeEntry('plugin.label', 'Core label', 'plugin')],
      });
      runtime.addLocaleData('en', 'plugin-memory', [
        makeEntry('plugin.label', 'Plugin override', 'plugin'),
        makeEntry('plugin.memory.action', 'Remember ${topic}', 'plugin'),
      ]);

      expect(runtime.translate('plugin.label', '', new Array<I18nParam>())).assertEqual('Core label');
      expect(runtime.translate('plugin.memory.action', '', [makeParam('topic', 'lore')])).assertEqual('Remember lore');
    });
  });
}

function makeEntry(key: string, value: string, category: string): I18nEntry {
  return {
    key: key,
    value: value,
    category: category,
  };
}

function makeParam(name: string, value: string): I18nParam {
  return {
    name: name,
    value: value,
  };
}
