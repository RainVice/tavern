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
 * 内部 Hook 条目，记录插件注册到 Hook 点的信息。
 */
interface HookEntry {
  /** 插件标识。 */
  pluginId: string;
  /** Hook 点名称。 */
  hookPoint: string;
  /** 执行优先级，数值越小越先执行。 */
  priority: number;
}

/**
 * 内部提示词注入条目，记录插件注入的提示词信息。
 */
interface PromptInjectionEntry {
  /** 插件标识。 */
  pluginId: string;
  /** 注入点名称。 */
  hookPoint: string;
  /** 提示词文本内容。 */
  content: string;
  /** 注入位置（如 "before"、"after"）。 */
  position: string;
  /** 执行优先级，数值越小越先注入。 */
  priority: number;
}

/**
 * 提供插件相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class PluginRuntime {
  /** 事件总线，用于发布插件相关事件。 */
  private events: EventBus;
  /** 已安装的插件记录，以 pluginId 为键。 */
  private plugins: Map<string, PluginRecord> = new Map<string, PluginRecord>();
  /** 已注册的 Hook 列表，以 hookPoint 为键，按优先级排序。 */
  private hooks: Map<string, Array<HookEntry>> = new Map<string, Array<HookEntry>>();
  /** 插件设置存储，以 pluginId 为外层键、设置 key 为内层键。 */
  private settings: Map<string, Map<string, string>> = new Map<string, Map<string, string>>();
  /** 全部提示词注入条目，按优先级全局排序。 */
  private promptInjections: Array<PromptInjectionEntry> = new Array<PromptInjectionEntry>();
  /** 安装计数器，每次安装递增，用于生成 pluginId。 */
  private installCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 安装一个插件，为其生成唯一标识并持久化记录。
   * @param manifest 插件清单信息。
   * @returns 新创建的插件记录。
   * @throws 同名插件已安装时抛出错误。
   */
  installPlugin(manifest: PluginManifest): PluginRecord {
    if (this.findByManifestName(manifest.name) !== undefined) {
      throw new Error(`Plugin "${manifest.name}" is already installed.`);
    }
    this.installCounter += 1;
    // 插件标识。
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
   * 卸载指定插件，清理其相关数据并发布卸载事件。
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
   * 启用指定插件，更新状态并发布启用事件。
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
   * 禁用指定插件，更新状态并发布禁用事件。
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
   * 获取指定插件的副本。
   * @param pluginId 插件标识。
   * @returns 插件记录的副本。
   * @throws 插件不存在时抛出错误。
   */
  getPlugin(pluginId: string): PluginRecord {
    return this.clonePlugin(this.requirePlugin(pluginId));
  }

  /**
   * 列出所有已安装插件的副本列表。
   * @returns 插件记录副本列表，修改返回值不影响内部状态。
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
   * 注册一个 Hook，使其在指定 Hook 点的执行链中生效。
   * @param pluginId 插件标识。
   * @param hookPoint Hook 点名称。
   * @param priority 执行优先级，数值越小越先执行。
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
   * 取消注册指定插件在指定 Hook 点的注册项。
   * @param pluginId 插件标识。
   * @param hookPoint Hook 点名称。
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
   * 触发指定 Hook 点的执行链，返回执行结果。
   * @param hookPoint Hook 点名称。
   * @returns Hook 执行结果，决定是否允许放行。
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
   * 设置指定插件的配置项。
   * @param pluginId 插件标识。
   * @param key 配置键名。
   * @param value 配置值。
   * @returns 创建或更新后的设置条目。
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
   * 获取指定插件的指定配置项值。
   * @param pluginId 插件标识。
   * @param key 配置键名。
   * @returns 配置值，不存在时返回空字符串。
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
   * 列出指定插件的所有配置项。
   * @param pluginId 插件标识。
   * @returns 设置条目列表，修改返回值不影响内部状态。
   */
  listPluginSettings(pluginId: string): Array<PluginSettingEntry> {
    this.requirePlugin(pluginId);
    const result = new Array<PluginSettingEntry>();
    const pluginSettings = this.settings.get(pluginId);
    if (pluginSettings !== undefined) {
      const keys = Array.from(pluginSettings.keys());
      for (let index = 0; index < keys.length; index += 1) {
        // 配置键名。
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
   * 为指定插件添加一条提示词注入。
   * @param pluginId 插件标识。
   * @param hookPoint 注入点名称。
   * @param content 提示词文本内容。
   * @param position 注入位置（如 "before"、"after"）。
   * @param priority 执行优先级，数值越小越先注入。
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
   * 移除指定插件的所有提示词注入。
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
   * 获取指定 Hook 点的所有生效提示词注入。
   * @param hookPoint 注入点名称。
   * @returns 符合条件的提示词注入列表，修改返回值不影响内部状态。
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
   * 列出指定插件注册的所有 Hook 点。
   * @param pluginId 插件标识。
   * @returns Hook 注册信息列表，修改返回值不影响内部状态。
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
   * 导出插件的完整数据，用于备份或迁移。
   * @param pluginId 插件标识。
   * @returns 可序列化的插件导出数据。
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
   * 从序列化数据导入插件，并恢复其设置和提示词注入。
   * @param data 导入的插件数据。
   * @returns 导入后的插件记录。
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
   * 移除指定插件注册的所有 Hook。
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
   * 获取指定插件的所有提示词注入列表。
   * @param pluginId 插件标识。
   * @returns 提示词注入列表副本，修改返回值不影响内部状态。
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
   * 根据清单名称查找已安装的插件。
   * @param name 插件名称。
   * @returns 找到的插件记录，未找到时返回 undefined。
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
   * 获取指定插件记录，不存在时抛出错误。
   * @param pluginId 插件标识。
   * @returns 插件记录（内部引用，非副本）。
   * @throws 插件未找到时抛出错误。
   */
  private requirePlugin(pluginId: string): PluginRecord {
    const plugin = this.plugins.get(pluginId);
    if (plugin === undefined) {
      throw new Error(`Plugin not found: ${pluginId}`);
    }
    return plugin;
  }

  /**
   * 深拷贝清单信息，防止外部修改内部状态。
   * @param manifest 原清单。
   * @returns 副本。
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
   * 深拷贝插件记录，防止外部修改内部状态。
   * @param plugin 原记录。
   * @returns 副本。
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
   * 深拷贝设置条目，防止外部修改内部状态。
   * @param entry 原条目。
   * @returns 副本。
   */
  private cloneSetting(entry: PluginSettingEntry): PluginSettingEntry {
    return {
      pluginId: entry.pluginId,
      key: entry.key,
      value: entry.value,
    };
  }

  /**
   * 深拷贝设置列表，防止外部修改内部状态。
   * @param settings 原列表。
   * @returns 副本列表。
   */
  private cloneSettings(settings: Array<PluginSettingEntry>): Array<PluginSettingEntry> {
    const result = new Array<PluginSettingEntry>();
    for (let index = 0; index < settings.length; index += 1) {
      result.push(this.cloneSetting(settings[index]));
    }
    return result;
  }

  /**
   * 深拷贝 Hook 执行结果，防止外部修改内部状态。
   * @param result 原结果。
   * @returns 副本。
   */
  private cloneHookResult(result: HookResult): HookResult {
    return {
      allowed: result.allowed,
      reason: result.reason,
    };
  }
}
