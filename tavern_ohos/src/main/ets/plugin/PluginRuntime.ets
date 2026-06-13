import { EventBus } from '../runtime/EventBus';
import type {
  HookResult,
  PluginDisabledPayload,
  PluginEnabledPayload,
  PluginExportData,
  PluginHookAppliedPayload,
  PluginHookRegistration,
  PluginManifest,
  PluginPromptInjectedPayload,
  PluginPromptInjection,
  PluginRecord,
  PluginRegisteredPayload,
  PluginSettingEntry,
  PluginUninstalledPayload,
} from './PluginModels';

interface HookEntry {
  pluginId: string;
  hookPoint: string;
  priority: number;
}

interface PromptInjectionEntry {
  pluginId: string;
  hookPoint: string;
  content: string;
  position: string;
  priority: number;
}

export class PluginRuntime {
  private events: EventBus;
  private plugins: Map<string, PluginRecord> = new Map<string, PluginRecord>();
  private hooks: Map<string, Array<HookEntry>> = new Map<string, Array<HookEntry>>();
  private settings: Map<string, Map<string, string>> = new Map<string, Map<string, string>>();
  private promptInjections: Array<PromptInjectionEntry> = new Array<PromptInjectionEntry>();
  private installCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

  installPlugin(manifest: PluginManifest): PluginRecord {
    if (this.findByManifestName(manifest.name) !== undefined) {
      throw new Error(`Plugin "${manifest.name}" is already installed.`);
    }
    this.installCounter += 1;
    const pluginId = `plugin-${this.installCounter}`;
    const now = Date.now();
    const plugin: PluginRecord = {
      pluginId: pluginId,
      manifest: this.cloneManifest(manifest),
      enabled: false,
      installedAt: now,
      updatedAt: now,
    };
    this.plugins.set(pluginId, this.clonePlugin(plugin));
    this.settings.set(pluginId, new Map<string, string>());
    const payload: PluginRegisteredPayload = {
      plugin: this.clonePlugin(plugin),
    };
    this.events.publish<PluginRegisteredPayload>('plugin.registered', payload);
    return this.clonePlugin(plugin);
  }

  uninstallPlugin(pluginId: string): void {
    const plugin = this.requirePlugin(pluginId);
    this.settings.delete(pluginId);
    this.removePluginHooks(pluginId);
    this.removePluginPromptInjections(pluginId);
    this.plugins.delete(pluginId);
    const payload: PluginUninstalledPayload = {
      plugin: this.clonePlugin(plugin),
    };
    this.events.publish<PluginUninstalledPayload>('plugin.uninstalled', payload);
  }

  enablePlugin(pluginId: string): void {
    const plugin = this.requirePlugin(pluginId);
    plugin.enabled = true;
    plugin.updatedAt = Date.now();
    const payload: PluginEnabledPayload = {
      plugin: this.clonePlugin(plugin),
    };
    this.events.publish<PluginEnabledPayload>('plugin.enabled', payload);
  }

  disablePlugin(pluginId: string): void {
    const plugin = this.requirePlugin(pluginId);
    plugin.enabled = false;
    plugin.updatedAt = Date.now();
    const payload: PluginDisabledPayload = {
      plugin: this.clonePlugin(plugin),
    };
    this.events.publish<PluginDisabledPayload>('plugin.disabled', payload);
  }

  getPlugin(pluginId: string): PluginRecord {
    return this.clonePlugin(this.requirePlugin(pluginId));
  }

  listPlugins(): Array<PluginRecord> {
    const result = new Array<PluginRecord>();
    const values = Array.from(this.plugins.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.clonePlugin(values[index]));
    }
    return result;
  }

  registerHook(pluginId: string, hookPoint: string, priority: number): void {
    this.requirePlugin(pluginId);
    const entry: HookEntry = {
      pluginId: pluginId,
      hookPoint: hookPoint,
      priority: priority,
    };
    let list = this.hooks.get(hookPoint);
    if (list === undefined) {
      list = new Array<HookEntry>();
      this.hooks.set(hookPoint, list);
    }
    list.push(entry);
    list.sort((left: HookEntry, right: HookEntry) => left.priority - right.priority);
  }

  unregisterHook(pluginId: string, hookPoint: string): void {
    const list = this.hooks.get(hookPoint);
    if (list === undefined) {
      return;
    }
    const remaining = new Array<HookEntry>();
    for (let index = 0; index < list.length; index += 1) {
      if (list[index].pluginId !== pluginId) {
        remaining.push(list[index]);
      }
    }
    this.hooks.set(hookPoint, remaining);
  }

  dispatchHook(hookPoint: string): HookResult {
    const list = this.hooks.get(hookPoint);
    if (list === undefined || list.length === 0) {
      return { allowed: true, reason: '' };
    }
    for (let index = 0; index < list.length; index += 1) {
      const entry = list[index];
      const plugin = this.plugins.get(entry.pluginId);
      if (plugin === undefined || !plugin.enabled) {
        continue;
      }
      let result: HookResult;
      try {
        result = { allowed: true, reason: '' };
      } catch (error) {
        result = { allowed: false, reason: String(error) };
      }
      const applied: PluginHookAppliedPayload = {
        pluginId: entry.pluginId,
        hookPoint: hookPoint,
        result: this.cloneHookResult(result),
      };
      this.events.publish<PluginHookAppliedPayload>('plugin.hook.applied', applied);
      if (!result.allowed) {
        return this.cloneHookResult(result);
      }
    }
    return { allowed: true, reason: '' };
  }

  setPluginSetting(pluginId: string, key: string, value: string): PluginSettingEntry {
    this.requirePlugin(pluginId);
    let pluginSettings = this.settings.get(pluginId);
    if (pluginSettings === undefined) {
      pluginSettings = new Map<string, string>();
      this.settings.set(pluginId, pluginSettings);
    }
    pluginSettings.set(key, value);
    return {
      pluginId: pluginId,
      key: key,
      value: value,
    };
  }

  getPluginSetting(pluginId: string, key: string): string {
    this.requirePlugin(pluginId);
    const pluginSettings = this.settings.get(pluginId);
    if (pluginSettings === undefined) {
      return '';
    }
    const value = pluginSettings.get(key);
    return value === undefined ? '' : value;
  }

  listPluginSettings(pluginId: string): Array<PluginSettingEntry> {
    this.requirePlugin(pluginId);
    const result = new Array<PluginSettingEntry>();
    const pluginSettings = this.settings.get(pluginId);
    if (pluginSettings !== undefined) {
      const keys = Array.from(pluginSettings.keys());
      for (let index = 0; index < keys.length; index += 1) {
        const key = keys[index];
        const value = pluginSettings.get(key);
        result.push({
          pluginId: pluginId,
          key: key,
          value: value === undefined ? '' : value,
        });
      }
    }
    return result;
  }

  addPromptInjection(
    pluginId: string,
    hookPoint: string,
    content: string,
    position: string,
    priority: number,
  ): void {
    this.requirePlugin(pluginId);
    const injection: PromptInjectionEntry = {
      pluginId: pluginId,
      hookPoint: hookPoint,
      content: content,
      position: position,
      priority: priority,
    };
    this.promptInjections.push(injection);
    this.promptInjections.sort(
      (left: PromptInjectionEntry, right: PromptInjectionEntry) => left.priority - right.priority,
    );
    const payload: PluginPromptInjectedPayload = {
      pluginId: pluginId,
      hookPoint: hookPoint,
      content: content,
      position: position,
    };
    this.events.publish<PluginPromptInjectedPayload>('plugin.prompt.injected', payload);
  }

  removePluginPromptInjections(pluginId: string): void {
    const remaining = new Array<PromptInjectionEntry>();
    for (let index = 0; index < this.promptInjections.length; index += 1) {
      if (this.promptInjections[index].pluginId !== pluginId) {
        remaining.push(this.promptInjections[index]);
      }
    }
    this.promptInjections = remaining;
  }

  getPromptInjections(hookPoint: string): Array<PluginPromptInjection> {
    const result = new Array<PluginPromptInjection>();
    for (let index = 0; index < this.promptInjections.length; index += 1) {
      const injection = this.promptInjections[index];
      const plugin = this.plugins.get(injection.pluginId);
      if (plugin === undefined || !plugin.enabled) {
        continue;
      }
      if (injection.hookPoint === hookPoint) {
        result.push({
          pluginId: injection.pluginId,
          hookPoint: injection.hookPoint,
          content: injection.content,
          position: injection.position,
          priority: injection.priority,
        });
      }
    }
    return result;
  }

  listHooks(pluginId: string): Array<PluginHookRegistration> {
    this.requirePlugin(pluginId);
    const result = new Array<PluginHookRegistration>();
    const hookPoints = Array.from(this.hooks.keys());
    for (let hi = 0; hi < hookPoints.length; hi += 1) {
      const list = this.hooks.get(hookPoints[hi]);
      if (list !== undefined) {
        for (let ei = 0; ei < list.length; ei += 1) {
          if (list[ei].pluginId === pluginId) {
            result.push({
              hookPoint: list[ei].hookPoint,
              priority: list[ei].priority,
            });
          }
        }
      }
    }
    return result;
  }

  exportPlugin(pluginId: string): PluginExportData {
    const plugin = this.requirePlugin(pluginId);
    const settings = this.listPluginSettings(pluginId);
    return {
      manifest: this.cloneManifest(plugin.manifest),
      settings: this.cloneSettings(settings),
      promptInjections: this.listPromptInjectionsForPlugin(pluginId),
    };
  }

  importPlugin(data: PluginExportData): PluginRecord {
    const plugin = this.installPlugin(data.manifest);
    for (let index = 0; index < data.settings.length; index += 1) {
      this.setPluginSetting(plugin.pluginId, data.settings[index].key, data.settings[index].value);
    }
    for (let index = 0; index < data.promptInjections.length; index += 1) {
      this.addPromptInjection(
        plugin.pluginId,
        data.promptInjections[index].hookPoint,
        data.promptInjections[index].content,
        data.promptInjections[index].position,
        data.promptInjections[index].priority,
      );
    }
    return plugin;
  }

  private removePluginHooks(pluginId: string): void {
    const hookPoints = Array.from(this.hooks.keys());
    for (let hi = 0; hi < hookPoints.length; hi += 1) {
      const list = this.hooks.get(hookPoints[hi]);
      if (list !== undefined) {
        const remaining = new Array<HookEntry>();
        for (let ei = 0; ei < list.length; ei += 1) {
          if (list[ei].pluginId !== pluginId) {
            remaining.push(list[ei]);
          }
        }
        this.hooks.set(hookPoints[hi], remaining);
      }
    }
  }

  private listPromptInjectionsForPlugin(pluginId: string): Array<PluginPromptInjection> {
    const result = new Array<PluginPromptInjection>();
    for (let index = 0; index < this.promptInjections.length; index += 1) {
      const injection = this.promptInjections[index];
      if (injection.pluginId === pluginId) {
        result.push({
          pluginId: injection.pluginId,
          hookPoint: injection.hookPoint,
          content: injection.content,
          position: injection.position,
          priority: injection.priority,
        });
      }
    }
    return result;
  }

  private findByManifestName(name: string): PluginRecord | undefined {
    const values = Array.from(this.plugins.values());
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].manifest.name === name) {
        return values[index];
      }
    }
    return undefined;
  }

  private requirePlugin(pluginId: string): PluginRecord {
    const plugin = this.plugins.get(pluginId);
    if (plugin === undefined) {
      throw new Error(`Plugin not found: ${pluginId}`);
    }
    return plugin;
  }

  private cloneManifest(manifest: PluginManifest): PluginManifest {
    return {
      name: manifest.name,
      version: manifest.version,
      description: manifest.description,
      author: manifest.author,
      permissions: manifest.permissions.slice(),
    };
  }

  private clonePlugin(plugin: PluginRecord): PluginRecord {
    return {
      pluginId: plugin.pluginId,
      manifest: this.cloneManifest(plugin.manifest),
      enabled: plugin.enabled,
      installedAt: plugin.installedAt,
      updatedAt: plugin.updatedAt,
    };
  }

  private cloneSetting(entry: PluginSettingEntry): PluginSettingEntry {
    return {
      pluginId: entry.pluginId,
      key: entry.key,
      value: entry.value,
    };
  }

  private cloneSettings(settings: Array<PluginSettingEntry>): Array<PluginSettingEntry> {
    const result = new Array<PluginSettingEntry>();
    for (let index = 0; index < settings.length; index += 1) {
      result.push(this.cloneSetting(settings[index]));
    }
    return result;
  }

  private cloneHookResult(result: HookResult): HookResult {
    return {
      allowed: result.allowed,
      reason: result.reason,
    };
  }
}
