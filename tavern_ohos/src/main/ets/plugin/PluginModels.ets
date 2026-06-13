/**
 * 描述插件模块在运行时交换的数据结构。
 */
export interface PluginManifest {
  /**
   * 名称。
   */
  name: string;
  /**
   * version 值，由当前实例内部维护。
   */
  version: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * author 值，由当前实例内部维护。
   */
  author: string;
  /**
   * permissions 列表，由当前实例内部维护。
   */
  permissions: Array<string>;
}

/**
 * 描述插件持久化或内存索引中的一条记录。
 */
export interface PluginRecord {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * manifest 值，由当前实例内部维护。
   */
  manifest: PluginManifest;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * installed At 值，由当前实例内部维护。
   */
  installedAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述插件模块在运行时交换的数据结构。
 */
export interface PluginContext {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * data Dir 值，由当前实例内部维护。
   */
  dataDir: string;
}

/**
 * 描述插件模块在运行时交换的数据结构。
 */
export interface PluginHookRegistration {
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
 * 描述插件操作完成后返回给调用方的结果。
 */
export interface HookResult {
  /**
   * allowed 值，由当前实例内部维护。
   */
  allowed: boolean;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
}

/**
 * 描述插件模块在运行时交换的数据结构。
 */
export interface PluginCommandRegistration {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * command 名称。
   */
  commandName: string;
  /**
   * aliases 列表，由当前实例内部维护。
   */
  aliases: Array<string>;
  /**
   * help Text 值，由当前实例内部维护。
   */
  helpText: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
}

/**
 * 描述插件模块在运行时交换的数据结构。
 */
export interface PluginToolRegistration {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * tool 名称。
   */
  toolName: string;
  /**
   * display 名称。
   */
  displayName: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * parameters JSON 字符串。
   */
  parametersJson: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: string;
  /**
   * stealth 值，由当前实例内部维护。
   */
  stealth: boolean;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
}

/**
 * 描述插件模块在运行时交换的数据结构。
 */
export interface PluginMacroRegistration {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * macro 名称。
   */
  macroName: string;
  /**
   * handler 名称。
   */
  handlerName: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
}

/**
 * 描述插件模块在运行时交换的数据结构。
 */
export interface PluginPromptInjection {
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
 * 描述插件持久化或内存索引中的一条记录。
 */
export interface PluginSettingEntry {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * 字段值。
   */
  value: string;
}

/**
 * 描述插件事件发布时携带的数据结构。
 */
export interface PluginRegisteredPayload {
  /**
   * plugin 值，由当前实例内部维护。
   */
  plugin: PluginRecord;
}

/**
 * 描述插件事件发布时携带的数据结构。
 */
export interface PluginEnabledPayload {
  /**
   * plugin 值，由当前实例内部维护。
   */
  plugin: PluginRecord;
}

/**
 * 描述插件事件发布时携带的数据结构。
 */
export interface PluginDisabledPayload {
  /**
   * plugin 值，由当前实例内部维护。
   */
  plugin: PluginRecord;
}

/**
 * 描述插件事件发布时携带的数据结构。
 */
export interface PluginUninstalledPayload {
  /**
   * plugin 值，由当前实例内部维护。
   */
  plugin: PluginRecord;
}

/**
 * 描述插件事件发布时携带的数据结构。
 */
export interface PluginHookAppliedPayload {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * hook Point 值，由当前实例内部维护。
   */
  hookPoint: string;
  /**
   * 处理结果。
   */
  result: HookResult;
}

/**
 * 描述插件事件发布时携带的数据结构。
 */
export interface PluginErrorPayload {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * 消息数据。
   */
  message: string;
}

/**
 * 描述插件事件发布时携带的数据结构。
 */
export interface PluginPromptInjectedPayload {
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
}

/**
 * 描述插件模块在运行时交换的数据结构。
 */
export interface PluginExportData {
  /**
   * manifest 值，由当前实例内部维护。
   */
  manifest: PluginManifest;
  /**
   * settings 列表，由当前实例内部维护。
   */
  settings: Array<PluginSettingEntry>;
  /**
   * prompt Injections 列表，由当前实例内部维护。
   */
  promptInjections: Array<PluginPromptInjection>;
}
