/**
 * 插件的清单信息，包含名称、版本、描述、作者和所需的权限列表。
 * 用于插件安装时的元数据记录，在 PluginRuntime 中存储和导出。
 */
export interface PluginManifest {
  /**
   * 插件名称，用于显示和唯一性校验，在 installPlugin 中检查是否已存在同名插件。
   */
  name: string;
  /**
   * 插件版本号，用于追踪插件版本更新。
   */
  version: string;
  /**
   * 插件描述，用于向用户说明插件的功能和用途。
   */
  description: string;
  /**
   * 插件作者，用于标识插件的创建者。
   */
  author: string;
  /**
   * 插件所需的权限列表，用于确定该插件在运行时需要哪些系统权限。
   */
  permissions: Array<string>;
}

/**
 * 插件的持久化记录，包含安装/启用状态和时间戳。
 * 由 PluginRuntime 管理，在安装、启用、禁用等操作中创建或更新。
 */
export interface PluginRecord {
  /**
   * 插件的唯一标识，格式为 plugin-{自增序号}，用于在运行时索引和定位插件。
   */
  pluginId: string;
  /**
   * 插件的清单信息，包含名称、版本、描述、作者和所需权限。
   */
  manifest: PluginManifest;
  /**
   * 插件是否启用，决定 Hook 分发、Prompt 注入等运行时行为是否包含此插件。
   */
  enabled: boolean;
  /**
   * 插件安装时的时间戳，用于记录安装时间。
   */
  installedAt: number;
  /**
   * 记录最近更新时间戳，用于追踪插件状态变更时间。
   */
  updatedAt: number;
}

/**
 * 插件的运行时上下文，提供数据目录等信息。
 * 用于向插件传递运行时的基础设施信息。
 */
export interface PluginContext {
  /**
   * 插件标识，用于在运行时区分不同插件的上下文。
   */
  pluginId: string;
  /**
   * 插件专属的数据目录路径，用于插件读写自己的持久化数据。
   */
  dataDir: string;
}

/**
 * 插件的 Hook 注册信息。
 * 用于记录插件在哪些 Hook 点注册了回调，以及执行的优先级。
 */
export interface PluginHookRegistration {
  /**
   * 关联的 Hook 点名称，用于在 dispatchHook 时定位要执行的插件回调。
   */
  hookPoint: string;
  /**
   * 执行优先级（数值越小越先执行），用于在 dispatchHook 时确定执行顺序。
   */
  priority: number;
}

/**
 * Hook 执行后返回给调用方的结果。
 * 由 dispatchHook 在各插件执行 Hook 后汇总返回。
 */
export interface HookResult {
  /**
   * 是否允许后续流程继续，如果为 false 则 dispatchHook 会立即中断并返回。
   */
  allowed: boolean;
  /**
   * 拒绝或失败的原因描述，用于在返回结果中说明阻断原因。
   */
  reason: string;
}

/**
 * 插件的命令注册信息。
 * 用于注册插件可以处理的文本命令，支持别名、帮助文本和权限控制。
 */
export interface PluginCommandRegistration {
  /**
   * 所属插件标识，用于在命令分发时定位来源插件。
   */
  pluginId: string;
  /**
   * 命令名称，用于用户输入时的触发词匹配。
   */
  commandName: string;
  /**
   * 命令别名列表，用于为用户提供多个触发词选项。
   */
  aliases: Array<string>;
  /**
   * 命令的帮助文本，用于向用户显示命令的使用说明。
   */
  helpText: string;
  /**
   * 执行命令所需的权限，用于在执行前进行权限检查。
   */
  permission: string;
  /**
   * 命令是否启用，禁用的命令不会匹配用户输入。
   */
  enabled: boolean;
}

/**
 * 插件的工具注册信息。
 * 用于向系统注册插件提供的可调用工具，支持 JSON Schema 参数定义和权限控制。
 */
export interface PluginToolRegistration {
  /**
   * 所属插件标识。
   */
  pluginId: string;
  /**
   * 工具名称。
   */
  toolName: string;
  /**
   * 工具显示名称。
   */
  displayName: string;
  /**
   * 工具描述。
   */
  description: string;
  /**
   * 工具参数的 JSON Schema 字符串，用于描述工具接受的参数结构。
   */
  parametersJson: string;
  /**
   * 使用工具所需的权限。
   */
  permission: string;
  /**
   * 是否对用户隐藏，隐藏的工具不会显示在用户面前但仍在后台可用。
   */
  stealth: boolean;
  /**
   * 工具是否启用。
   */
  enabled: boolean;
}

/**
 * 插件的宏注册信息。
 * 用于注册插件提供的模板宏，在 Prompt 中替换对应占位符。
 */
export interface PluginMacroRegistration {
  /**
   * 所属插件标识。
   */
  pluginId: string;
  /**
   * 宏名称，用于在模板中匹配 {{宏名称}} 占位符。
   */
  macroName: string;
  /**
   * 宏处理函数名称，用于在运行时定位并执行宏解析逻辑。
   */
  handlerName: string;
  /**
   * 宏描述，用于说明宏的用途和替换结果。
   */
  description: string;
}

/**
 * 插件的 Prompt 注入信息。
 * 用于插件在指定 Hook 点注入自定义提示词内容，扩展或修改系统提示。
 */
export interface PluginPromptInjection {
  /**
   * 所属插件标识。
   */
  pluginId: string;
  /**
   * 注入目标的 Hook 点名称，决定注入的提示词在 Prompt 中的位置。
   */
  hookPoint: string;
  /**
   * 注入的提示词内容。
   */
  content: string;
  /**
   * 注入位置（如 before、after、replace），决定注入内容相对于目标位置的关系。
   */
  position: string;
  /**
   * 执行优先级，决定多个插件在同一个 Hook 点的注入顺序。
   */
  priority: number;
}

/**
 * 插件的设置条目。
 * 用于存储插件自定义的键值对设置，通过 setPluginSetting / getPluginSetting 管理。
 */
export interface PluginSettingEntry {
  /**
   * 所属插件标识。
   */
  pluginId: string;
  /**
   * 设置的键名。
   */
  key: string;
  /**
   * 设置的值。
   */
  value: string;
}

/**
 * 插件注册完成时通过事件总线发布的数据载荷。
 * 由 installPlugin 发布，通知监听方（如 UI 层）刷新插件列表。
 */
export interface PluginRegisteredPayload {
  /**
   * 已注册的插件记录，供监听方获取新安装插件的详细信息。
   */
  plugin: PluginRecord;
}

/**
 * 插件启用时通过事件总线发布的数据载荷。
 * 由 enablePlugin 发布，通知监听方（如 Hook 分发器）该插件已可参与执行。
 */
export interface PluginEnabledPayload {
  /**
   * 已启用的插件记录，供监听方获取启用后的插件状态。
   */
  plugin: PluginRecord;
}

/**
 * 插件禁用时通过事件总线发布的数据载荷。
 * 由 disablePlugin 发布，通知监听方（如 Hook 分发器）该插件不再参与执行。
 */
export interface PluginDisabledPayload {
  /**
   * 已禁用的插件记录，供监听方获取禁用后的插件状态。
   */
  plugin: PluginRecord;
}

/**
 * 插件卸载时通过事件总线发布的数据载荷。
 * 由 uninstallPlugin 发布，通知监听方（如 UI 层）从列表中移除插件。
 */
export interface PluginUninstalledPayload {
  /**
   * 已卸载的插件记录，供监听方获取被移除插件的最后状态。
   */
  plugin: PluginRecord;
}

/**
 * 插件 Hook 执行完毕时通过事件总线发布的数据载荷。
 * 由 dispatchHook 在每个插件执行完 Hook 后发布。
 */
export interface PluginHookAppliedPayload {
  /**
   * 执行 Hook 的插件标识。
   */
  pluginId: string;
  /**
   * Hook 点名称。
   */
  hookPoint: string;
  /**
   * Hook 执行结果，包含是否允许继续的执行状态。
   */
  result: HookResult;
}

/**
 * 插件发生错误时通过事件总线发布的数据载荷。
 * 用于通知监听方（如 UI 层或日志系统）记录插件运行错误。
 */
export interface PluginErrorPayload {
  /**
   * 出错插件的标识。
   */
  pluginId: string;
  /**
   * 错误消息。
   */
  message: string;
}

/**
 * 插件的 Prompt 注入执行时通过事件总线发布的数据载荷。
 * 由 addPromptInjection 发布，通知监听方（如 UI 层或 Prompt 合成器）注入已生效。
 */
export interface PluginPromptInjectedPayload {
  /**
   * 执行注入的插件标识。
   */
  pluginId: string;
  /**
   * 注入目标 Hook 点名称。
   */
  hookPoint: string;
  /**
   * 注入的提示词内容。
   */
  content: string;
  /**
   * 注入位置。
   */
  position: string;
}

/**
 * 插件的导出/导入格式。
 * 用于在备份或迁移时序列化插件的完整数据，包含清单、设置和 Prompt 注入。
 */
export interface PluginExportData {
  /**
   * 插件清单信息，用于导入时重建插件元数据。
   */
  manifest: PluginManifest;
  /**
   * 插件设置列表，用于导入时恢复插件的自定义配置。
   */
  settings: Array<PluginSettingEntry>;
  /**
   * 插件注册的 Prompt 注入列表，用于导入时恢复插件的提示词注入规则。
   */
  promptInjections: Array<PluginPromptInjection>;
}
