import type { RuntimePermission } from '../contracts/PublicContracts';

/**
 * 插件清单信息，声明插件的基本元数据和所需权限。
 */
export interface PluginManifest {
  /** 插件名称，用于唯一标识。 */
  name: string;
  /** 插件版本号，语义化版本。 */
  version: string;
  /** 插件功能描述文本。 */
  description: string;
  /** 插件作者名。 */
  author: string;
  /** 插件申请运行时所需权限列表。 */
  permissions: Array<RuntimePermission>;
}

/**
 * 插件记录，描述插件在持久化存储或内存索引中的状态。
 */
export interface PluginRecord {
  /** 插件标识，运行时自动生成。 */
  pluginId: string;
  /** 插件清单信息。 */
  manifest: PluginManifest;
  /** 是否已启用。 */
  enabled: boolean;
  /** 安装时的时间戳（毫秒）。 */
  installedAt: number;
  /** 最近一次更新时的时间戳（毫秒）。 */
  updatedAt: number;
}

/**
 * 插件运行时上下文，为插件实例提供其运行环境信息。
 */
export interface PluginContext {
  /** 插件标识。 */
  pluginId: string;
  /** 插件数据目录的路径。 */
  dataDir: string;
}

/**
 * 插件 Hook 注册信息，描述插件注册到哪个 Hook 点及执行优先级。
 */
export interface PluginHookRegistration {
  /** Hook 点名称。 */
  hookPoint: string;
  /** 执行优先级，数值越小越先执行。 */
  priority: number;
}

/**
 * Hook 执行结果，决定 Hook 链是否允许继续执行。
 */
export interface HookResult {
  /** 是否允许放行。 */
  allowed: boolean;
  /** 禁止放行时的原因说明。 */
  reason: string;
}

/**
 * 插件命令注册信息，描述插件对外暴露的 CLI 命令。
 */
export interface PluginCommandRegistration {
  /** 插件标识。 */
  pluginId: string;
  /** 命令名称。 */
  commandName: string;
  /** 命令别名列表。 */
  aliases: Array<string>;
  /** 命令的帮助文本。 */
  helpText: string;
  /** 执行命令所需的权限。 */
  permission: RuntimePermission;
  /** 命令是否已启用。 */
  enabled: boolean;
}

/**
 * 插件工具注册信息，描述插件对外暴露的工具函数。
 */
export interface PluginToolRegistration {
  /** 插件标识。 */
  pluginId: string;
  /** 工具名称。 */
  toolName: string;
  /** 工具展示名称。 */
  displayName: string;
  /** 工具描述文本。 */
  description: string;
  /** 工具参数的 JSON Schema 字符串。 */
  parametersJson: string;
  /** 调用工具所需的权限。 */
  permission: RuntimePermission;
  /** 是否隐藏工具不对外显示。 */
  stealth: boolean;
  /** 工具是否已启用。 */
  enabled: boolean;
}

/**
 * 插件宏注册信息，描述插件注册的宏命令。
 */
export interface PluginMacroRegistration {
  /** 插件标识。 */
  pluginId: string;
  /** 宏名称。 */
  macroName: string;
  /** 宏处理器名称。 */
  handlerName: string;
  /** 宏描述文本。 */
  description: string;
}

/**
 * 插件提示词注入声明，描述插件在指定 Hook 点注入提示词内容。
 */
export interface PluginPromptInjection {
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
 * 插件设置条目，描述插件的一项键值对配置。
 */
export interface PluginSettingEntry {
  /** 插件标识。 */
  pluginId: string;
  /** 配置键名。 */
  key: string;
  /** 配置值。 */
  value: string;
}

/**
 * 插件已注册事件的载荷。
 */
export interface PluginRegisteredPayload {
  /** 被注册的插件记录。 */
  plugin: PluginRecord;
}

/**
 * 插件已启用事件的载荷。
 */
export interface PluginEnabledPayload {
  /** 被启用的插件记录。 */
  plugin: PluginRecord;
}

/**
 * 插件已禁用事件的载荷。
 */
export interface PluginDisabledPayload {
  /** 被禁用的插件记录。 */
  plugin: PluginRecord;
}

/**
 * 插件已卸载事件的载荷。
 */
export interface PluginUninstalledPayload {
  /** 被卸载的插件记录。 */
  plugin: PluginRecord;
}

/**
 * 插件 Hook 已执行事件的载荷。
 */
export interface PluginHookAppliedPayload {
  /** 插件标识。 */
  pluginId: string;
  /** 已执行的 Hook 点名称。 */
  hookPoint: string;
  /** Hook 执行结果。 */
  result: HookResult;
}

/**
 * 插件错误事件的载荷。
 */
export interface PluginErrorPayload {
  /** 插件标识。 */
  pluginId: string;
  /** 错误消息。 */
  message: string;
}

/**
 * 插件提示词已注入事件的载荷。
 */
export interface PluginPromptInjectedPayload {
  /** 插件标识。 */
  pluginId: string;
  /** 注入点名称。 */
  hookPoint: string;
  /** 注入的提示词内容。 */
  content: string;
  /** 注入位置（如 "before"、"after"）。 */
  position: string;
}

/**
 * 插件导出数据，包含可序列化的完整插件状态，用于备份或迁移。
 */
export interface PluginExportData {
  /** 插件清单信息。 */
  manifest: PluginManifest;
  /** 插件设置条目列表。 */
  settings: Array<PluginSettingEntry>;
  /** 插件提示词注入列表。 */
  promptInjections: Array<PluginPromptInjection>;
}
