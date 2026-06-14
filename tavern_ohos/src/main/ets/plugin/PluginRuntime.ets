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
 * 插件 Hook 的内存条目。
 */
interface HookEntry {
  /**
   * 注册该 Hook 的插件标识，用于在 dispatchHook 时定位和执行插件逻辑。
   */
  pluginId: string;
  /**
   * Hook 点名称，用于在 dispatchHook 时匹配要执行的 Hook。
   */
  hookPoint: string;
  /**
   * 执行优先级，数值越小越先执行，用于控制多个插件在同一 Hook 点的执行顺序。
   */
  priority: number;
}

/**
 * 插件 Prompt 注入的内存条目。
 */
interface PromptInjectionEntry {
  /**
   * 注入来源的插件标识，用于在清理或查询时定位注入来源。
   */
  pluginId: string;
  /**
   * 注入目标的 Hook 点名称。
   */
  hookPoint: string;
  /**
   * 注入的提示词内容。
   */
  content: string;
  /**
   * 注入位置（如 before、after、replace）。
   */
  position: string;
  /**
   * 执行优先级，用于排序多个插件的注入顺序。
   */
  priority: number;
}

/**
 * 提供插件相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 调用方（如插件管理器、Hook 分发器、Prompt 合成器）通过此运行时管理插件生命周期、
 * 注册和执行 Hook、管理 Prompt 注入及插件设置。
 */
export class PluginRuntime {
  /**
   * 事件总线，用于在插件安装、启用、禁用、卸载、Hook 执行等阶段发布事件。
   */
  private events: EventBus;
  /**
   * 插件记录的内存索引，键为 pluginId。
   * 用于所有插件 CRUD 操作及 Hook/Prompt 注入/设置管理。
   */
  private plugins: Map<string, PluginRecord> = new Map<string, PluginRecord>();
  /**
   * Hook 注册表，按 hookPoint 分组，按优先级排序。
   * 用于 dispatchHook 时快速定位并顺序执行某 Hook 点的所有插件回调。
   */
  private hooks: Map<string, Array<HookEntry>> = new Map<string, Array<HookEntry>>();
  /**
   * 插件设置的内存索引，外层键为 pluginId，内层键为设置 key。
   * 用于 setPluginSetting/getPluginSetting/listPluginSettings。
   */
  private settings: Map<string, Map<string, string>> = new Map<string, Map<string, string>>();
  /**
   * Prompt 注入条目列表，按优先级排序。
   * 用于在 getPromptInjections 中按 Hook 点过滤出已启用插件的注入内容。
   */
  private promptInjections: Array<PromptInjectionEntry> = new Array<PromptInjectionEntry>();
  /**
   * 安装计数器，用于在 installPlugin 中生成唯一 pluginId。
   */
  private installCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例，用于后续插件生命周期事件发布。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 安装新插件，检查名称唯一性，分配 pluginId 并发布注册事件。
   * 调用方（如插件管理界面）在用户安装插件时调用。
   * @param manifest 插件清单信息，包含名称、版本、描述、作者和所需权限。
   * @returns 创建的插件记录副本。
   */
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

  /**
   * 卸载插件，清理其 Hook、Prompt 注入和设置数据。
   * 调用方（如插件管理界面）在用户卸载插件时调用。
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
   * 启用指定插件，记录更新时间并发布事件。
   * 调用方（如插件管理界面）在用户启用插件时调用。
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
   * 禁用指定插件，记录更新时间并发布事件。
   * 调用方（如插件管理界面）在用户禁用插件时调用。
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
   * 按 ID 读取插件记录，不存在时抛出异常。
   * @param pluginId 插件标识。
   * @returns 插件记录副本。
   */
  getPlugin(pluginId: string): PluginRecord {
    return this.clonePlugin(this.requirePlugin(pluginId));
  }

  /**
   * 返回当前所有插件记录的副本列表。
   * @returns 插件记录列表副本。
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
   * 注册插件到指定 Hook 点，按优先级排序。
   * 调用方（如插件初始化流程）在插件设置 Hook 回调时调用。
   * @param pluginId 插件标识。
   * @param hookPoint Hook 点名称，决定该 Hook 在什么阶段被触发。
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
    list.sort(
      (left: HookEntry, right: HookEntry) => left.priority - right.priority,
    );
  }

  /**
   * 取消插件在指定 Hook 点的注册。
   * 在 uninstallPlugin 或插件动态取消注册时调用。
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
   * 调度指定 Hook 点的所有已启用插件，按优先级依次执行并收集返回结果。
   * 调用方（如 Prompt 合成器、命令调度器）在特定流程节点触发时调用，各插件按优先级执行。
   * 如果任一插件返回 allowed: false，则立即中断并返回拒绝结果。
   * @param hookPoint Hook 点名称。
   * @returns Hook 执行结果，若插件拒绝则立即返回拒绝结果。
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
      this.events.publish<PluginHookAppliedPayload>(
        'plugin.hook.applied',
        applied,
      );
      if (!result.allowed) {
        return this.cloneHookResult(result);
      }
    }
    return { allowed: true, reason: '' };
  }

  /**
   * 设置插件设置的键值对。
   * 调用方（如插件运行时代码或配置界面）在保存插件配置时调用。
   * @param pluginId 插件标识。
   * @param key 设置键名。
   * @param value 设置值。
   * @returns 创建的设置条目。
   */
  setPluginSetting(
    pluginId: string,
    key: string,
    value: string,
  ): PluginSettingEntry {
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
   * 按键名读取插件设置，不存在时返回空字符串。
   * @param pluginId 插件标识。
   * @param key 设置键名。
   * @returns 设置值，未设置时返回空字符串。
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
   * 返回指定插件的所有设置条目列表副本。
   * @param pluginId 插件标识。
   * @returns 设置条目列表。
   */
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

  /**
   * 添加插件的 Prompt 注入条目，按优先级排序并发布注入事件。
   * 调用方（如插件初始化流程）在注册 Prompt 注入时调用。
   * @param pluginId 插件标识。
   * @param hookPoint 注入目标的 Hook 点。
   * @param content 注入的提示词内容。
   * @param position 注入位置（如 before、after、replace）。
   * @param priority 优先级，决定多个注入的执行顺序。
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
      (left: PromptInjectionEntry, right: PromptInjectionEntry) =>
        left.priority - right.priority,
    );
    const payload: PluginPromptInjectedPayload = {
      pluginId: pluginId,
      hookPoint: hookPoint,
      content: content,
      position: position,
    };
    this.events.publish<PluginPromptInjectedPayload>(
      'plugin.prompt.injected',
      payload,
    );
  }

  /**
   * 移除指定插件的所有 Prompt 注入条目。
   * 在 uninstallPlugin 中调用，确保插件卸载后其注入数据也被清理。
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
   * 返回指定 Hook 点的已启用插件的 Prompt 注入列表副本。
   * 调用方（如 Prompt 合成器）在构建最终提示词时调用，用于获取应注入的提示词内容。
   * @param hookPoint Hook 点名称。
   * @returns Prompt 注入条目列表。
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
   * 返回指定插件注册的所有 Hook 列表。
   * @param pluginId 插件标识。
   * @returns Hook 注册信息列表。
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
   * 导出插件（含清单、设置和 Prompt 注入），用于备份或与外部工具互通。
   * @param pluginId 插件标识。
   * @returns 插件导出数据。
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
   * 从外部数据导入插件，依次安装、恢复设置和 Prompt 注入。
   * 调用方在从备份恢复或迁移插件时使用。
   * @param data 插件导出数据，包含清单、设置和 Prompt 注入。
   * @returns 导入后的插件记录。
   */
  importPlugin(data: PluginExportData): PluginRecord {
    const plugin = this.installPlugin(data.manifest);
    for (let index = 0; index < data.settings.length; index += 1) {
      this.setPluginSetting(
        plugin.pluginId,
        data.settings[index].key,
        data.settings[index].value,
      );
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
   * 移除指定插件在所有 Hook 点的注册记录。
   * 在 uninstallPlugin 中调用，确保插件卸载后其 Hook 注册也被清理。
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
   * 返回指定插件的 Prompt 注入条目列表。
   * 在 exportPlugin 中调用，用于导出插件的 Prompt 注入数据。
   * @param pluginId 插件标识。
   * @returns Prompt 注入条目列表副本。
   */
  private listPromptInjectionsForPlugin(
    pluginId: string,
  ): Array<PluginPromptInjection> {
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
   * 按清单名称查找已安装的插件。
   * 在 installPlugin 中用于检查插件名称唯一性。
   * @param name 插件名称。
   * @returns 匹配的插件记录，未找到返回 undefined。
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
   * 按 ID 查找插件，不存在时抛出异常。
   * 由 getPlugin、enablePlugin、disablePlugin、registerHook、setPluginSetting 等内部调用。
   * @param pluginId 插件标识。
   * @returns 匹配的插件记录引用。
   */
  private requirePlugin(pluginId: string): PluginRecord {
    const plugin = this.plugins.get(pluginId);
    if (plugin === undefined) {
      throw new Error(`Plugin not found: ${pluginId}`);
    }
    return plugin;
  }

  /**
   * 深拷贝 PluginManifest。
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
   * 深拷贝 PluginRecord。
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
   * 深拷贝 PluginSettingEntry。
   */
  private cloneSetting(entry: PluginSettingEntry): PluginSettingEntry {
    return {
      pluginId: entry.pluginId,
      key: entry.key,
      value: entry.value,
    };
  }

  /**
   * 深拷贝 PluginSettingEntry 列表。
   * @returns 设置条目列表副本。
   */
  private cloneSettings(
    settings: Array<PluginSettingEntry>,
  ): Array<PluginSettingEntry> {
    const result = new Array<PluginSettingEntry>();
    for (let index = 0; index < settings.length; index += 1) {
      result.push(this.cloneSetting(settings[index]));
    }
    return result;
  }

  /**
   * 深拷贝 HookResult。
   */
  private cloneHookResult(result: HookResult): HookResult {
    return {
      allowed: result.allowed,
      reason: result.reason,
    };
  }
}
