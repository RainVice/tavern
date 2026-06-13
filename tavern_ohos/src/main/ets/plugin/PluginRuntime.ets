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

/**
 * 描述插件持久化或内存索引中的一条记录。
 */
interface HookEntry {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * hook Point 值，由当前实例内部维护。
   */
  hookPoint: string;
  /**
   * priority 值，由当前实例内部维护。
   */
  priority: number;
}

/**
 * 描述插件持久化或内存索引中的一条记录。
 */
interface PromptInjectionEntry {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * hook Point 值，由当前实例内部维护。
   */
  hookPoint: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * position 值，由当前实例内部维护。
   */
  position: string;
  /**
   * priority 值，由当前实例内部维护。
   */
  priority: number;
}

/**
 * 提供插件相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class PluginRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * plugins 列表，由当前实例内部维护。
   */
  private plugins: Map<string, PluginRecord> = new Map<string, PluginRecord>();
  /**
   * hooks 列表，由当前实例内部维护。
   */
  private hooks: Map<string, Array<HookEntry>> = new Map<string, Array<HookEntry>>();
  /**
   * settings 列表，由当前实例内部维护。
   */
  private settings: Map<string, Map<string, string>> = new Map<string, Map<string, string>>();
  /**
   * prompt Injections 列表，由当前实例内部维护。
   */
  private promptInjections: Array<PromptInjectionEntry> = new Array<PromptInjectionEntry>();
  /**
   * install Counter 值，由当前实例内部维护。
   */
  private installCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 执行 installPlugin 的内部处理步骤，供当前模块复用。
   */
  installPlugin(manifest: PluginManifest): PluginRecord {
    if (this.findByManifestName(manifest.name) !== undefined) {
      throw new Error(`Plugin "${manifest.name}" is already installed.`);
    }
    this.installCounter += 1;
    // plugin 标识。
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

  /**
   * 执行 uninstallPlugin 的内部处理步骤，供当前模块复用。
   * @param pluginId 插件标识。
   */
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

  /**
   * 执行 enablePlugin 的内部处理步骤，供当前模块复用。
   * @param pluginId 插件标识。
   */
  enablePlugin(pluginId: string): void {
    const plugin = this.requirePlugin(pluginId);
    plugin.enabled = true;
    plugin.updatedAt = Date.now();
    const payload: PluginEnabledPayload = {
      plugin: this.clonePlugin(plugin),
    };
    this.events.publish<PluginEnabledPayload>('plugin.enabled', payload);
  }

  /**
   * 执行 disablePlugin 的内部处理步骤，供当前模块复用。
   * @param pluginId 插件标识。
   */
  disablePlugin(pluginId: string): void {
    const plugin = this.requirePlugin(pluginId);
    plugin.enabled = false;
    plugin.updatedAt = Date.now();
    const payload: PluginDisabledPayload = {
      plugin: this.clonePlugin(plugin),
    };
    this.events.publish<PluginDisabledPayload>('plugin.disabled', payload);
  }

  /**
   * 读取指定Plugin，不存在时抛出错误。
   * @param pluginId 插件标识。
   * @returns 更新或读取后的记录副本。
   */
  getPlugin(pluginId: string): PluginRecord {
    return this.clonePlugin(this.requirePlugin(pluginId));
  }

  /**
   * 读取Plugins列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listPlugins(): Array<PluginRecord> {
    const result = new Array<PluginRecord>();
    const values = Array.from(this.plugins.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.clonePlugin(values[index]));
    }
    return result;
  }

  /**
   * 注册Hook 值，使其可被后续运行时流程使用。
   * @param pluginId 插件标识。


   */
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

  /**
   * 取消注册Hook 值，避免后续流程继续调用。
   * @param pluginId 插件标识。

   */
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

  /**
   * 执行 dispatchHook 的内部处理步骤，供当前模块复用。
   */
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

  /**
   * 设置插件设置，用于切换运行时状态或保存配置。
   * @param pluginId 插件标识。
   * @param key 键名。
   * @param value 要保存或比较的字段值。
   */
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

  /**
   * 读取指定设置项，不存在时抛出错误。
   * @param pluginId 插件标识。
   * @param key 键名。
   * @returns 更新或读取后的记录副本。
   */
  getPluginSetting(pluginId: string, key: string): string {
    this.requirePlugin(pluginId);
    const pluginSettings = this.settings.get(pluginId);
    if (pluginSettings === undefined) {
      return '';
    }
    const value = pluginSettings.get(key);
    return value === undefined ? '' : value;
  }

  /**
   * 读取PluginSettings列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param pluginId 插件标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listPluginSettings(pluginId: string): Array<PluginSettingEntry> {
    this.requirePlugin(pluginId);
    const result = new Array<PluginSettingEntry>();
    const pluginSettings = this.settings.get(pluginId);
    if (pluginSettings !== undefined) {
      const keys = Array.from(pluginSettings.keys());
      for (let index = 0; index < keys.length; index += 1) {
        // 键名。
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

  /**
   * 创建或写入提示词Injection，完成持久化后返回可供调用方使用的结果。
   * @param pluginId 插件标识。

   * @param content 要写入或追加的文本内容。
   */
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

  /**
   * 移除插件提示词注入列表，用于解除注册、绑定或索引关系。
   * @param pluginId 插件标识。
   */
  removePluginPromptInjections(pluginId: string): void {
    const remaining = new Array<PromptInjectionEntry>();
    for (let index = 0; index < this.promptInjections.length; index += 1) {
      if (this.promptInjections[index].pluginId !== pluginId) {
        remaining.push(this.promptInjections[index]);
      }
    }
    this.promptInjections = remaining;
  }

  /**
   * 读取Prompt Injections 列表，不存在时通常抛出错误或返回空值。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 读取Hooks列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param pluginId 插件标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listHooks(pluginId: string): Array<PluginHookRegistration> {
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

  /**
   * 导出插件，用于备份、迁移或与 SillyTavern 数据互通。
   * @param pluginId 插件标识。
   * @returns 可持久化或可传输的导出内容。
   */
  exportPlugin(pluginId: string): PluginExportData {
    const plugin = this.requirePlugin(pluginId);
    const settings = this.listPluginSettings(pluginId);
    return {
      manifest: this.cloneManifest(plugin.manifest),
      settings: this.cloneSettings(settings),
      promptInjections: this.listPromptInjectionsForPlugin(pluginId),
    };
  }

  /**
   * 从外部数据导入Plugin 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 移除插件 Hook 列表，用于解除注册、绑定或索引关系。
   * @param pluginId 插件标识。
   */
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

  /**
   * 读取提示词InjectionsForPlugin列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param pluginId 插件标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 在当前集合中查找By Manifest 名称，未命中时返回空值或默认位置。
   * @param name 显示名称或注册名称。
   */
  private findByManifestName(name: string): PluginRecord | undefined {
    const values = Array.from(this.plugins.values());
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].manifest.name === name) {
        return values[index];
      }
    }
    return undefined;
  }

  /**
   * 读取必须存在的Plugin 值，缺失时抛出错误。
   * @param pluginId 插件标识。
   */
  private requirePlugin(pluginId: string): PluginRecord {
    const plugin = this.plugins.get(pluginId);
    if (plugin === undefined) {
      throw new Error(`Plugin not found: ${pluginId}`);
    }
    return plugin;
  }

  /**
   * 复制Manifest 值，避免外部修改内部状态。
   */
  private cloneManifest(manifest: PluginManifest): PluginManifest {
    return {
      name: manifest.name,
      version: manifest.version,
      description: manifest.description,
      author: manifest.author,
      permissions: manifest.permissions.slice(),
    };
  }

  /**
   * 复制Plugin 值，避免外部修改内部状态。
   */
  private clonePlugin(plugin: PluginRecord): PluginRecord {
    return {
      pluginId: plugin.pluginId,
      manifest: this.cloneManifest(plugin.manifest),
      enabled: plugin.enabled,
      installedAt: plugin.installedAt,
      updatedAt: plugin.updatedAt,
    };
  }

  /**
   * 复制Setting 值，避免外部修改内部状态。
   * @param entry 条目记录。
   */
  private cloneSetting(entry: PluginSettingEntry): PluginSettingEntry {
    return {
      pluginId: entry.pluginId,
      key: entry.key,
      value: entry.value,
    };
  }

  /**
   * 复制Settings 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneSettings(settings: Array<PluginSettingEntry>): Array<PluginSettingEntry> {
    const result = new Array<PluginSettingEntry>();
    for (let index = 0; index < settings.length; index += 1) {
      result.push(this.cloneSetting(settings[index]));
    }
    return result;
  }

  /**
   * 复制Hook Result 值，避免外部修改内部状态。
   * @param result 返回结果。
   */
  private cloneHookResult(result: HookResult): HookResult {
    return {
      allowed: result.allowed,
      reason: result.reason,
    };
  }
}
