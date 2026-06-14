import type { CommandExecutionResult } from '../command/CommandModels';
import type { TavernScope } from '../contracts/PublicContracts';

/**
 * 创建新的快捷回复集合时需要提供的参数。
 */
export interface QuickReplySetCreateParams {
  /**
   * 集合标识。
   */
  id: string;
  /**
   * 集合名称。
   */
  name: string;
  /**
   * 集合作用域，决定该集合在哪些场景下可用。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识，为空时表示匹配该作用域下所有场景。
   */
  scopeId: string;
  /**
   * 集合启用状态，禁用后该集合内所有项均不参与匹配与执行。
   */
  enabled: boolean;
}

/**
 * 在集合中添加快捷回复项时需要提供的参数。
 */
export interface QuickReplyItemCreateParams {
  /**
   * 项目标识。
   */
  id: string;
  /**
   * 按钮显示标签。
   */
  label: string;
  /**
   * 长按时显示的标题文本。
   */
  title: string;
  /**
   * 点击按钮后要执行的命令文本，支持管道。
   */
  command: string;
  /**
   * 项目启用状态，禁用后按钮不参与执行。
   */
  enabled: boolean;
  /**
   * 按钮可见性，可被运行时动态控制。
   */
  visible: boolean;
  /**
   * 是否启用自动触发，开启后当 trigger 匹配时自动执行。
   */
  autoExecute: boolean;
  /**
   * 触发自动执行的关键字，仅在 autoExecute 为 true 时有效。
   */
  trigger: string;
  /**
   * 关联的插件标识。
   */
  pluginId: string;
}

/**
 * 内存索引或持久化存储中的一条快捷回复项目记录。
 */
export interface QuickReplyItemRecord {
  /**
   * 项目标识。
   */
  id: string;
  /**
   * 按钮显示标签。
   */
  label: string;
  /**
   * 长按时显示的标题文本。
   */
  title: string;
  /**
   * 点击按钮后执行的命令文本。
   */
  command: string;
  /**
   * 项目启用状态。
   */
  enabled: boolean;
  /**
   * 按钮可见性。
   */
  visible: boolean;
  /**
   * 是否启用自动触发。
   */
  autoExecute: boolean;
  /**
   * 自动触发关键字。
   */
  trigger: string;
  /**
   * 关联的插件标识。
   */
  pluginId: string;
}

/**
 * 内存索引或持久化存储中的一条快捷回复集合记录。
 */
export interface QuickReplySetRecord {
  /**
   * 集合标识。
   */
  id: string;
  /**
   * 集合名称。
   */
  name: string;
  /**
   * 集合作用域，决定该集合在哪些场景下可用。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 集合启用状态。
   */
  enabled: boolean;
  /**
   * 集合内包含的项目列表。
   */
  items: Array<QuickReplyItemRecord>;
}

/**
 * 通过 listButtons 返回给 UI 层的按钮数据，包含来源集合信息和执行入口。
 */
export interface QuickReplyButtonData {
  /**
   * 来源集合标识。
   */
  setId: string;
  /**
   * 按钮对应的项目标识。
   */
  itemId: string;
  /**
   * 按钮显示标签。
   */
  label: string;
  /**
   * 长按时显示的标题文本。
   */
  title: string;
  /**
   * 按钮对应的命令文本。
   */
  command: string;
  /**
   * 来源集合作用域。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 按钮关联的插件标识。
   */
  pluginId: string;
}

/**
 * 执行快捷回复项后返回给调用方的执行结果。
 */
export interface QuickReplyExecutionResult {
  /**
   * 执行结果所处的集合快照。
   */
  set: QuickReplySetRecord;
  /**
   * 被执行的项目快照。
   */
  item: QuickReplyItemRecord;
  /**
   * 是否实际执行了命令（可能因禁用或隐藏而跳过）。
   */
  executed: boolean;
  /**
   * 底层命令执行结果。
   */
  commandResult: CommandExecutionResult;
}

/**
 * 快捷回复项执行完成后发布的事件负载。
 */
export interface QuickReplyExecutedPayload {
  /**
   * 执行结果所处的集合快照。
   */
  set: QuickReplySetRecord;
  /**
   * 被执行的项目快照。
   */
  item: QuickReplyItemRecord;
  /**
   * 底层命令执行结果。
   */
  commandResult: CommandExecutionResult;
}

/**
 * 集合发生变化时发布的事件负载。
 */
export interface QuickReplySetUpdatedPayload {
  /**
   * 变化后的集合快照。
   */
  set: QuickReplySetRecord;
}

/**
 * 快捷回复集合的导出数据格式，用于备份和与 SillyTavern 数据互通。
 */
export interface QuickReplyExportData {
  /**
   * 导出的集合快照。
   */
  set: QuickReplySetRecord;
}
