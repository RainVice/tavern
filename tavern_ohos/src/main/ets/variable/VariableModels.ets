import type { TavernScope } from '../contracts/PublicContracts';

/**
 * 描述变量模块在运行时交换的数据结构。
 */
export interface VariableResolveContext {
  /**
   * 用户标识。
   */
  userId: string;
  /**
   * 角色标识。
   */
  characterId: string;
  /**
   * persona 标识。
   */
  personaId: string;
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * group 标识。
   */
  groupId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * plugin 标识。
   */
  pluginId: string;
}

/**
 * 描述变量持久化或内存索引中的一条记录。
 */
export interface VariableEntry {
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 作用域标识。
   */
  scopeId: string;
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
  /**
   * persistent 值，由当前实例内部维护。
   */
  persistent: boolean;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述变量操作完成后返回给调用方的结果。
 */
export interface VariableResolveResult {
  /**
   * found 值，由当前实例内部维护。
   */
  found: boolean;
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 作用域标识。
   */
  scopeId: string;
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
 * 描述变量事件发布时携带的数据结构。
 */
export interface VariableChangedPayload {
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * old Value 值，由当前实例内部维护。
   */
  oldValue: string;
  /**
   * new Value 值，由当前实例内部维护。
   */
  newValue: string;
  /**
   * persistent 值，由当前实例内部维护。
   */
  persistent: boolean;
}

/**
 * 描述变量事件发布时携带的数据结构。
 */
export interface VariableDeletedPayload {
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * old Value 值，由当前实例内部维护。
   */
  oldValue: string;
}

/**
 * 描述变量模块在运行时交换的数据结构。
 */
export interface VariableExportData {
  /**
   * 条目列表，由当前实例内部维护。
   */
  entries: Array<VariableEntry>;
  /**
   * exported At 值，由当前实例内部维护。
   */
  exportedAt: number;
}
