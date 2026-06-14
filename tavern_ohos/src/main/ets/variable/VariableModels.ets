import type { TavernScope } from '../contracts/PublicContracts';

/**
 * 描述变量解析时所需的上下文信息，涵盖当前对话的各类实体标识。
 */
export interface VariableResolveContext {
  /**
   * 当前用户的唯一标识。
   */
  userId: string;
  /**
   * 当前角色的唯一标识。
   */
  characterId: string;
  /**
   * 当前 persona 的唯一标识。
   */
  personaId: string;
  /**
   * 当前聊天的唯一标识。
   */
  chatId: string;
  /**
   * 当前群组的唯一标识。
   */
  groupId: string;
  /**
   * 当前消息的唯一标识。
   */
  messageId: string;
  /**
   * 当前插件的唯一标识。
   */
  pluginId: string;
}

/**
 * 描述变量在内存中的一条完整存储记录。
 */
export interface VariableEntry {
  /**
   * 变量所属的作用域类型（如 global / user / character / chat / temporary 等）。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 当 scope 为 "plugin" 时记录插件标识。
   */
  pluginId: string;
  /**
   * 变量名。
   */
  key: string;
  /**
   * 变量的当前值。
   */
  value: string;
  /**
   * 变量是否持久化（temporary 和 pipe 作用域的变量不持久化）。
   */
  persistent: boolean;
  /**
   * 变量创建时间戳。
   */
  createdAt: number;
  /**
   * 变量最近更新时间戳。
   */
  updatedAt: number;
}

/**
 * 描述变量解析完成后的返回结果（包含找到的变量或其缺失信息）。
 */
export interface VariableResolveResult {
  /**
   * 是否找到匹配的变量。
   */
  found: boolean;
  /**
   * 找到的变量所属作用域。
   */
  scope: TavernScope;
  /**
   * 找到的变量所属作用域标识。
   */
  scopeId: string;
  /**
   * 找到的变量名。
   */
  key: string;
  /**
   * 找到的变量值（未找到时为空字符串）。
   */
  value: string;
}

/**
 * 描述变量值变更事件（如 variable.changed）发布时携带的负载数据。
 */
export interface VariableChangedPayload {
  /**
   * 变量所属作用域。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 变更的变量名。
   */
  key: string;
  /**
   * 变更前的变量值。
   */
  oldValue: string;
  /**
   * 变更后的变量值。
   */
  newValue: string;
  /**
   * 变量是否持久化。
   */
  persistent: boolean;
}

/**
 * 描述变量删除事件（如 variable.deleted）发布时携带的负载数据。
 */
export interface VariableDeletedPayload {
  /**
   * 被删除变量所属作用域。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 被删除的变量名。
   */
  key: string;
  /**
   * 被删除前的变量值。
   */
  oldValue: string;
}

/**
 * 描述变量导出数据的结构，用于备份、迁移或与 SillyTavern 数据互通。
 */
export interface VariableExportData {
  /**
   * 导出的所有持久化变量条目列表。
   */
  entries: Array<VariableEntry>;
  /**
   * 导出操作的时间戳。
   */
  exportedAt: number;
}
