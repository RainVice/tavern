import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  PluginRuntime,
  type PluginExportData,
  type PluginHookAppliedPayload,
  type PluginEnabledPayload,
  type PluginDisabledPayload,
  type PluginUninstalledPayload,
  type PluginManifest,
  type PluginPromptInjectedPayload,
  type PluginRegisteredPayload,
  type RuntimeEvent,
} from '../../Index';

function makeManifest(name: string, permissions: Array<string>): PluginManifest {
  return {
    name: name,
    version: '1.0.0',
    description: `Test plugin ${name}`,
    author: 'test',
    permissions: permissions.slice(),
  };
}

export default function pluginUnitTest() {
  describe('plugin runtime', () => {
    it('installs and lists plugins', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      const registered = new Array<string>();
      bus.subscribe<PluginRegisteredPayload>('plugin.registered', (event: RuntimeEvent<PluginRegisteredPayload>) => {
        registered.push(event.payload.plugin.pluginId);
      });

      const plugin = runtime.installPlugin(makeManifest('TestPlugin', ['network']));
      const list = runtime.listPlugins();

      expect(list.length).assertEqual(1);
      expect(list[0].pluginId).assertEqual(plugin.pluginId);
      expect(list[0].manifest.name).assertEqual('TestPlugin');
      expect(list[0].manifest.permissions[0]).assertEqual('network');
      expect(list[0].enabled).assertFalse();
      expect(registered.length).assertEqual(1);
      expect(registered[0]).assertEqual(plugin.pluginId);
    });

    it('prevents duplicate plugin installation by name', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      runtime.installPlugin(makeManifest('OnlyOne', []));
      let thrown = false;
      try {
        runtime.installPlugin(makeManifest('OnlyOne', []));
      } catch (error) {
        thrown = true;
      }
      expect(thrown).assertTrue();
    });

    it('enables and disables plugins, emitting events', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      const enabled = new Array<string>();
      const disabled = new Array<string>();
      bus.subscribe<PluginEnabledPayload>('plugin.enabled', (event: RuntimeEvent<PluginEnabledPayload>) => {
        enabled.push(event.payload.plugin.pluginId);
      });
      bus.subscribe<PluginDisabledPayload>('plugin.disabled', (event: RuntimeEvent<PluginDisabledPayload>) => {
        disabled.push(event.payload.plugin.pluginId);
      });

      const plugin = runtime.installPlugin(makeManifest('TogglePlugin', []));
      runtime.enablePlugin(plugin.pluginId);
      expect(runtime.getPlugin(plugin.pluginId).enabled).assertTrue();
      runtime.disablePlugin(plugin.pluginId);
      expect(runtime.getPlugin(plugin.pluginId).enabled).assertFalse();

      expect(enabled.length).assertEqual(1);
      expect(enabled[0]).assertEqual(plugin.pluginId);
      expect(disabled.length).assertEqual(1);
      expect(disabled[0]).assertEqual(plugin.pluginId);
    });

    it('uninstalls plugins and cleans up hooks, settings, and prompt injections', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      const uninstalled = new Array<string>();
      bus.subscribe<PluginUninstalledPayload>('plugin.uninstalled', (event: RuntimeEvent<PluginUninstalledPayload>) => {
        uninstalled.push(event.payload.plugin.pluginId);
      });

      const plugin = runtime.installPlugin(makeManifest('RemoveMe', []));
      runtime.registerHook(plugin.pluginId, 'before_generation', 0);
      runtime.setPluginSetting(plugin.pluginId, 'key1', 'value1');
      runtime.addPromptInjection(plugin.pluginId, 'before_prompt_build', 'injected', 'before', 0);
      runtime.uninstallPlugin(plugin.pluginId);

      expect(uninstalled.length).assertEqual(1);
      expect(uninstalled[0]).assertEqual(plugin.pluginId);

      let thrown = false;
      try {
        runtime.getPlugin(plugin.pluginId);
      } catch (error) {
        thrown = true;
      }
      expect(thrown).assertTrue();

      const hooks = runtime.listHooks(plugin.pluginId);
      expect(hooks.length).assertEqual(0);
    });

    it('registers hooks and dispatches them in priority order', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      const applied = new Array<PluginHookAppliedPayload>();
      bus.subscribe<PluginHookAppliedPayload>('plugin.hook.applied', (event: RuntimeEvent<PluginHookAppliedPayload>) => {
        applied.push(event.payload);
      });

      const plugin1 = runtime.installPlugin(makeManifest('P1', []));
      const plugin2 = runtime.installPlugin(makeManifest('P2', []));
      runtime.registerHook(plugin1.pluginId, 'before_generation', 10);
      runtime.registerHook(plugin2.pluginId, 'before_generation', 5);
      runtime.enablePlugin(plugin1.pluginId);
      runtime.enablePlugin(plugin2.pluginId);

      const result = runtime.dispatchHook('before_generation');

      expect(result.allowed).assertTrue();
      expect(applied.length).assertEqual(2);
      expect(applied[0].pluginId).assertEqual(plugin2.pluginId);
      expect(applied[1].pluginId).assertEqual(plugin1.pluginId);
    });

    it('skips disabled plugins during hook dispatch', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      const applied = new Array<string>();
      bus.subscribe<PluginHookAppliedPayload>('plugin.hook.applied', (event: RuntimeEvent<PluginHookAppliedPayload>) => {
        applied.push(event.payload.pluginId);
      });

      const plugin = runtime.installPlugin(makeManifest('DisabledHook', []));
      runtime.registerHook(plugin.pluginId, 'after_message', 0);
      const result = runtime.dispatchHook('after_message');

      expect(result.allowed).assertTrue();
      expect(applied.length).assertEqual(0);
    });

    it('manages plugin settings', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      const plugin = runtime.installPlugin(makeManifest('SettingsPlugin', []));

      runtime.setPluginSetting(plugin.pluginId, 'theme', 'dark');
      runtime.setPluginSetting(plugin.pluginId, 'timeout', '30000');

      expect(runtime.getPluginSetting(plugin.pluginId, 'theme')).assertEqual('dark');
      expect(runtime.getPluginSetting(plugin.pluginId, 'timeout')).assertEqual('30000');
      expect(runtime.getPluginSetting(plugin.pluginId, 'missing')).assertEqual('');

      const list = runtime.listPluginSettings(plugin.pluginId);
      expect(list.length).assertEqual(2);
    });

    it('adds prompt injections and retrieves them by hook point', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      const injected = new Array<PluginPromptInjectedPayload>();
      bus.subscribe<PluginPromptInjectedPayload>(
        'plugin.prompt.injected',
        (event: RuntimeEvent<PluginPromptInjectedPayload>) => {
          injected.push(event.payload);
        },
      );

      const plugin = runtime.installPlugin(makeManifest('PromptPlugin', []));
      runtime.enablePlugin(plugin.pluginId);
      runtime.addPromptInjection(plugin.pluginId, 'before_prompt_build', 'system_extra', 'after_system', 0);

      const injections = runtime.getPromptInjections('before_prompt_build');
      expect(injections.length).assertEqual(1);
      expect(injections[0].pluginId).assertEqual(plugin.pluginId);
      expect(injections[0].content).assertEqual('system_extra');
      expect(injections[0].position).assertEqual('after_system');
      expect(injected.length).assertEqual(1);
      expect(injected[0].content).assertEqual('system_extra');
    });

    it('does not return prompt injections from disabled plugins', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      const plugin = runtime.installPlugin(makeManifest('DisabledPromptPlugin', []));
      runtime.addPromptInjection(plugin.pluginId, 'before_prompt_build', 'hidden', 'before', 0);

      const injections = runtime.getPromptInjections('before_prompt_build');
      expect(injections.length).assertEqual(0);
    });

    it('exports and imports plugins preserving settings and injections', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      const plugin = runtime.installPlugin(makeManifest('ExportMe', ['network']));
      runtime.enablePlugin(plugin.pluginId);
      runtime.setPluginSetting(plugin.pluginId, 'key1', 'value1');
      runtime.addPromptInjection(plugin.pluginId, 'before_prompt_build', 'injected', 'before', 5);
      runtime.addPromptInjection(plugin.pluginId, 'after_prompt_build', 'after-injected', 'after', 7);
      const otherPlugin = runtime.installPlugin(makeManifest('OtherPlugin', []));
      runtime.addPromptInjection(otherPlugin.pluginId, 'after_prompt_build', 'other-injected', 'after', 1);

      const exported = runtime.exportPlugin(plugin.pluginId);
      const importRuntime = new PluginRuntime(new EventBus());
      const imported = importRuntime.importPlugin(exported);
      importRuntime.enablePlugin(imported.pluginId);

      expect(imported.manifest.name).assertEqual('ExportMe');
      expect(imported.manifest.permissions[0]).assertEqual('network');

      const savedSetting = importRuntime.getPluginSetting(imported.pluginId, 'key1');
      expect(savedSetting).assertEqual('value1');
      expect(exported.promptInjections.length).assertEqual(2);

      const beforeInjections = importRuntime.getPromptInjections('before_prompt_build');
      const afterInjections = importRuntime.getPromptInjections('after_prompt_build');
      expect(beforeInjections.length).assertEqual(1);
      expect(beforeInjections[0].content).assertEqual('injected');
      expect(afterInjections.length).assertEqual(1);
      expect(afterInjections[0].content).assertEqual('after-injected');
    });

    it('does not expose internal plugin records, manifests, or export data', 0, () => {
      const bus = new EventBus();
      const runtime = new PluginRuntime(bus);
      bus.subscribe<PluginRegisteredPayload>('plugin.registered', (event: RuntimeEvent<PluginRegisteredPayload>) => {
        event.payload.plugin.manifest.permissions.push('event-permission');
      });

      const manifest = makeManifest('CopyPlugin', ['network']);
      const plugin = runtime.installPlugin(manifest);
      manifest.permissions.push('external-source');
      plugin.manifest.permissions.push('external-record');
      expect(runtime.getPlugin(plugin.pluginId).manifest.permissions.length).assertEqual(1);

      const listed = runtime.listPlugins();
      listed[0].manifest.permissions.push('listed-permission');
      expect(runtime.getPlugin(plugin.pluginId).manifest.permissions.length).assertEqual(1);

      runtime.enablePlugin(plugin.pluginId);
      runtime.setPluginSetting(plugin.pluginId, 'key', 'value');
      runtime.addPromptInjection(plugin.pluginId, 'before_prompt_build', 'inject', 'before', 0);
      const exported: PluginExportData = runtime.exportPlugin(plugin.pluginId);
      exported.manifest.permissions.push('exported-permission');
      exported.settings[0].value = 'exported-setting';
      exported.promptInjections[0].content = 'exported-injection';

      expect(runtime.getPlugin(plugin.pluginId).manifest.permissions.length).assertEqual(1);
      expect(runtime.getPluginSetting(plugin.pluginId, 'key')).assertEqual('value');
      expect(runtime.getPromptInjections('before_prompt_build')[0].content).assertEqual('inject');
    });
  });
}
