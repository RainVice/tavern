import type { CommandExecutionResult } from '../command/CommandModels';

/**
 * 描述调用快捷回复能力时需要传入的参数。
 */
export interface QuickReplySetCreateParams {
  /**
   * 快捷回复集合标识，用于在字典中索引和查询该集合——由上层模块分配并保证唯一性。
   */
  id: string;
  /**
   * 快捷回复集合的显示名称，用于 UI 展示和用户识别。
   */
  name: string;
  /**
   * 作用域类型（如 global、character、chat 等），用于限定该集合在哪些场景下生效——执行按钮查询时根据此字段过滤。
   */
  scope: string;
  /**
   * 作用域下的具体对象标识，配合 scope 精确匹配——如 character 的 ID 或 chat 的 ID。
   */
  scopeId: string;
  /**
   * 集合初始启用状态，启用时集合内的按钮才可被查询和执行。
   */
  enabled: boolean;
}

/**
 * 描述调用快捷回复能力时需要传入的参数。
 */
export interface QuickReplyItemCreateParams {
  /**
   * 快捷回复项标识，用于在集合内唯一索引该按钮。
   */
  id: string;
  /**
   * 快捷回复按钮上显示的标签文本，用于 UI 按钮上的简短显示文字。
   */
  label: string;
  /**
   * 快捷回复项的标题说明，用于按钮的详细描述或 tooltip。
   */
  title: string;
  /**
   * 执行时触发的命令字符串，支持单条命令或管道命令（以 | 分隔）。
   */
  command: string;
  /**
   * 项是否启用，禁用时不会出现在按钮列表也不会被执行。
   */
  enabled: boolean;
  /**
   * 项在快捷回复面板中是否可见，仅可见项出现在 UI 按钮列表中。
   */
  visible: boolean;
  /**
   * 是否在触发条件满足时自动执行，用于消息到达或特定事件时自动触发该命令。
   */
  autoExecute: boolean;
  /**
   * 自动触发的条件字符串，与 autoExecute 配合使用——当触发条件匹配时自动执行该命令。
   */
  trigger: string;
  /**
   * 所属插件标识，用于追踪该按钮来自哪个插件——便于插件管理。
   */
  pluginId: string;
}

/**
 * 描述快捷回复持久化或内存索引中的一条记录。
 */
export interface QuickReplyItemRecord {
  /**
   * 快捷回复项标识，用于在集合内唯一索引该按钮。
   */
  id: string;
  /**
   * 快捷回复按钮上显示的标签文本，用于 UI 按钮上的简短显示文字。
   */
  label: string;
  /**
   * 快捷回复项的标题说明，用于按钮的详细描述或 tooltip。
   */
  title: string;
  /**
   * 执行时触发的命令字符串，支持单条命令或管道命令（以 | 分隔）。
   */
  command: string;
  /**
   * 项是否启用，禁用时不会出现在按钮列表也不会被执行。
   */
  enabled: boolean;
  /**
   * 项在快捷回复面板中是否可见，仅可见项出现在 UI 按钮列表中。
   */
  visible: boolean;
  /**
   * 是否在触发条件满足时自动执行，用于消息到达或特定事件时自动触发该命令。
   */
  autoExecute: boolean;
  /**
   * 自动触发的条件字符串，与 autoExecute 配合使用——当触发条件匹配时自动执行该命令。
   */
  trigger: string;
  /**
   * 所属插件标识，用于追踪该按钮来自哪个插件——便于插件管理。
   */
  pluginId: string;
}

/**
 * 描述快捷回复持久化或内存索引中的一条记录。
 */
export interface QuickReplySetRecord {
  /**
   * 快捷回复集合标识，用于在字典中索引和查询该集合。
   */
  id: string;
  /**
   * 快捷回复集合的显示名称，用于 UI 展示和用户识别。
   */
  name: string;
  /**
   * 作用域类型（如 global、character、chat 等），用于限定该集合在哪些场景下生效。
   */
  scope: string;
  /**
   * 作用域下的具体对象标识，配合 scope 精确匹配——如 character 的 ID 或 chat 的 ID。
   */
  scopeId: string;
  /**
   * 集合是否已启用，启用时集合内的按钮才可被查询和执行。
   */
  enabled: boolean;
  /**
   * 集合中包含的快捷回复项列表，每项对应一个可点击的按钮。
   */
  items: Array<QuickReplyItemRecord>;
}

/**
 * 描述快捷回复模块在运行时交换的数据结构。
 */
export interface QuickReplyButtonData {
  /**
   * 所属快捷回复集合标识，用于定位该按钮的来源集合。
   */
  setId: string;
  /**
   * 快捷回复项标识，用于唯一索引该按钮。
   */
  itemId: string;
  /**
   * 按钮上显示的标签文本，用于 UI 渲染按钮文字。
   */
  label: string;
  /**
   * 按钮的标题说明，用于 UI tooltip 或辅助描述。
   */
  title: string;
  /**
   * 按钮点击时触发的命令字符串，由 CommandRuntime 执行。
   */
  command: string;
  /**
   * 作用域类型，用于在 UI 中标识按钮的应用范围。
   */
  scope: string;
  /**
   * 作用域下的具体对象标识，用于在 UI 中标识按钮作用目标。
   */
  scopeId: string;
  /**
   * 所属插件标识，用于追踪该按钮来自哪个插件。
   */
  pluginId: string;
}

/**
 * 描述快捷回复操作完成后返回给调用方的结果。
 */
export interface QuickReplyExecutionResult {
  /**
   * 执行操作涉及的快捷回复集合记录，携带执行时的集合状态供调用方判断。
   */
  set: QuickReplySetRecord;
  /**
   * 执行操作涉及的快捷回复项记录，携带执行时的项状态供调用方判断。
   */
  item: QuickReplyItemRecord;
  /**
   * 命令是否已实际执行，false 表示因禁用/不可见等原因被跳过。
   */
  executed: boolean;
  /**
   * 命令执行的结果，包含执行成功/失败状态及输出信息。
   */
  commandResult: CommandExecutionResult;
}

/**
 * 描述快捷回复事件发布时携带的数据结构。
 */
export interface QuickReplyExecutedPayload {
  /**
   * 执行操作涉及的快捷回复集合记录副本，用于通知监听方本次执行的集合上下文。
   */
  set: QuickReplySetRecord;
  /**
   * 执行操作涉及的快捷回复项记录副本，用于通知监听方本次执行的具体项。
   */
  item: QuickReplyItemRecord;
  /**
   * 命令执行的结果，携带给 UI 或其他模块用于显示执行状态。
   */
  commandResult: CommandExecutionResult;
}

/**
 * 描述快捷回复事件发布时携带的数据结构。
 */
export interface QuickReplySetUpdatedPayload {
  /**
   * 变更后的快捷回复集合记录副本，用于通知监听方集合（或内部项）已发生变化。
   */
  set: QuickReplySetRecord;
}

/**
 * 描述快捷回复模块在运行时交换的数据结构。
 */
export interface QuickReplyExportData {
  /**
   * 待导出的快捷回复集合记录，包含所有项数据——用于跨实例转移或备份。
   */
  set: QuickReplySetRecord;
}
