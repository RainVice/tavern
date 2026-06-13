import type { CommandExecutionResult } from '../command/CommandModels';

/**
 * 描述调用快捷回复能力时需要传入的参数。
 */
export interface QuickReplySetCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * 作用域。
   */
  scope: string;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
}

/**
 * 描述调用快捷回复能力时需要传入的参数。
 */
export interface QuickReplyItemCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * command 值，由当前实例内部维护。
   */
  command: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * visible 值，由当前实例内部维护。
   */
  visible: boolean;
  /**
   * auto Execute 值，由当前实例内部维护。
   */
  autoExecute: boolean;
  /**
   * trigger 值，由当前实例内部维护。
   */
  trigger: string;
  /**
   * plugin 标识。
   */
  pluginId: string;
}

/**
 * 描述快捷回复持久化或内存索引中的一条记录。
 */
export interface QuickReplyItemRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * command 值，由当前实例内部维护。
   */
  command: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * visible 值，由当前实例内部维护。
   */
  visible: boolean;
  /**
   * auto Execute 值，由当前实例内部维护。
   */
  autoExecute: boolean;
  /**
   * trigger 值，由当前实例内部维护。
   */
  trigger: string;
  /**
   * plugin 标识。
   */
  pluginId: string;
}

/**
 * 描述快捷回复持久化或内存索引中的一条记录。
 */
export interface QuickReplySetRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * 作用域。
   */
  scope: string;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * 项目列表，由当前实例内部维护。
   */
  items: Array<QuickReplyItemRecord>;
}

/**
 * 描述快捷回复模块在运行时交换的数据结构。
 */
export interface QuickReplyButtonData {
  /**
   * set 标识。
   */
  setId: string;
  /**
   * item 标识。
   */
  itemId: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * command 值，由当前实例内部维护。
   */
  command: string;
  /**
   * 作用域。
   */
  scope: string;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * plugin 标识。
   */
  pluginId: string;
}

/**
 * 描述快捷回复操作完成后返回给调用方的结果。
 */
export interface QuickReplyExecutionResult {
  /**
   * set 值，由当前实例内部维护。
   */
  set: QuickReplySetRecord;
  /**
   * 项目记录，由当前实例内部维护。
   */
  item: QuickReplyItemRecord;
  /**
   * executed 值，由当前实例内部维护。
   */
  executed: boolean;
  /**
   * commandResult 结果。
   */
  commandResult: CommandExecutionResult;
}

/**
 * 描述快捷回复事件发布时携带的数据结构。
 */
export interface QuickReplyExecutedPayload {
  /**
   * set 值，由当前实例内部维护。
   */
  set: QuickReplySetRecord;
  /**
   * 项目记录，由当前实例内部维护。
   */
  item: QuickReplyItemRecord;
  /**
   * commandResult 结果。
   */
  commandResult: CommandExecutionResult;
}

/**
 * 描述快捷回复事件发布时携带的数据结构。
 */
export interface QuickReplySetUpdatedPayload {
  /**
   * set 值，由当前实例内部维护。
   */
  set: QuickReplySetRecord;
}

/**
 * 描述快捷回复模块在运行时交换的数据结构。
 */
export interface QuickReplyExportData {
  /**
   * set 值，由当前实例内部维护。
   */
  set: QuickReplySetRecord;
}
