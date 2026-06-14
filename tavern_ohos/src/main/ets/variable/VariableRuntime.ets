import { EventBus } from '../runtime/EventBus';
import type { TavernScope } from '../contracts/PublicContracts';
import type {
  VariableChangedPayload,
  VariableDeletedPayload,
  VariableEntry,
  VariableExportData,
  VariableResolveContext,
  VariableResolveResult,
} from './VariableModels';

/**
 * 提供变量相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class VariableRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 按组合键（"scope:scopeId:key"）索引的所有变量条目。
   */
  private entries: Map<string, VariableEntry> = new Map<string, VariableEntry>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 设置指定作用域和键对应的变量值。如果变量已存在则覆盖并触发 variable.changed 事件。
   * @param scope 变量所属作用域。
   * @param scopeId 作用域下的对象标识。
   * @param key 变量名。
   * @param value 变量值。
   * @returns 新建或更新后的变量条目副本。
   */
  setVariable(scope: TavernScope, scopeId: string, key: string, value: string): VariableEntry {
    const entryKey = this.entryKey(scope, scopeId, key);
    const existing = this.entries.get(entryKey);
    const now = Date.now();
    const oldValue = existing === undefined ? '' : existing.value;
    const entry: VariableEntry = {
      scope: scope,
      scopeId: scopeId,
      pluginId: scope === 'plugin' ? scopeId : '',
      key: key,
      value: value,
      persistent: this.isPersistentScope(scope),
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.entries.set(entryKey, this.cloneEntry(entry));
    const payload: VariableChangedPayload = {
      scope: scope,
      scopeId: scopeId,
      key: key,
      oldValue: oldValue,
      newValue: value,
      persistent: entry.persistent,
    };
    this.events.publish<VariableChangedPayload>('variable.changed', payload);
    return this.cloneEntry(entry);
  }

  /**
   * 根据上下文设置变量值（自动根据 scope 从 context 中提取 scopeId）。
   * @param scope 变量所属作用域。
   * @param key 变量名。
   * @param value 变量值。
   * @param context 当前上下文，用于提取 scopeId。
   * @returns 新建或更新后的变量条目副本。
   */
  setContextVariable(scope: TavernScope, key: string, value: string, context: VariableResolveContext): VariableEntry {
    return this.setVariable(scope, this.scopeIdForContext(scope, context), key, value);
  }

  /**
   * 设置管道变量（作用域固定为 "pipe"，scopeId 为空字符串）。
   * @param key 变量名。
   * @param value 变量值。
   * @returns 新建的变量条目副本。
   */
  setPipeVariable(key: string, value: string): VariableEntry {
    return this.setVariable('pipe', '', key, value);
  }

  /**
   * 写入命令变量（调用 setContextVariable 的便捷封装）。
   * @param scope 变量所属作用域。
   * @param key 变量名。
   * @param value 变量值。
   * @param context 当前上下文。
   * @returns 新建或更新后的变量条目副本。
   */
  writeCommandVariable(scope: TavernScope, key: string, value: string, context: VariableResolveContext): VariableEntry {
    return this.setContextVariable(scope, key, value, context);
  }

  /**
   * 获取指定作用域和键对应的变量值。
   * @param scope 变量所属作用域。
   * @param scopeId 作用域下的对象标识。
   * @param key 变量名。
   * @returns 变量值，未找到时返回空字符串。
   */
  getVariable(scope: TavernScope, scopeId: string, key: string): string {
    const entry = this.entries.get(this.entryKey(scope, scopeId, key));
    if (entry === undefined) {
      return '';
    }
    return entry.value;
  }

  /**
   * 获取指定上下文和键对应的变量值（自动提取 scopeId）。
   * @param scope 变量所属作用域。
   * @param key 变量名。
   * @param context 当前上下文。
   * @returns 变量值，未找到时返回空字符串。
   */
  getContextVariable(scope: TavernScope, key: string, context: VariableResolveContext): string {
    return this.getVariable(scope, this.scopeIdForContext(scope, context), key);
  }

  /**
   * 获取指定管道变量的值。
   * @param key 变量名。
   * @returns 变量值，未找到时返回空字符串。
   */
  getPipeVariable(key: string): string {
    return this.getVariable('pipe', '', key);
  }

  /**
   * 读取命令变量值。当 scope 为 "resolved" 时进行跨作用域解析，否则直接从指定上下文获取。
   * @param scope 变量所属作用域（特殊值 "resolved" 触发自动解析）。
   * @param key 变量名。
   * @param context 当前上下文。
   * @returns 变量值。
   */
  readCommandVariable(scope: TavernScope, key: string, context: VariableResolveContext): string {
    if (scope === 'resolved') {
      return this.resolveVariable(key, context).value;
    }
    return this.getContextVariable(scope, key, context);
  }

  /**
   * 删除指定作用域和键对应的变量，触发 variable.deleted 事件。
   * @param scope 变量所属作用域。
   * @param scopeId 作用域下的对象标识。
   * @param key 变量名。
   */
  deleteVariable(scope: TavernScope, scopeId: string, key: string): void {
    const entryKey = this.entryKey(scope, scopeId, key);
    const existing = this.entries.get(entryKey);
    if (existing === undefined) {
      return;
    }
    this.entries.delete(entryKey);
    const payload: VariableDeletedPayload = {
      scope: scope,
      scopeId: scopeId,
      key: key,
      oldValue: existing.value,
    };
    this.events.publish<VariableDeletedPayload>('variable.deleted', payload);
  }

  /**
   * 删除指定上下文和键对应的变量。
   * @param scope 变量所属作用域。
   * @param key 变量名。
   * @param context 当前上下文。
   */
  deleteContextVariable(scope: TavernScope, key: string, context: VariableResolveContext): void {
    this.deleteVariable(scope, this.scopeIdForContext(scope, context), key);
  }

  /**
   * 根据当前上下文按作用域优先级解析变量值。
   * 解析顺序：temporary > pipe > message > chat > group > character > persona > user > plugin > global。
   * @param key 变量名。
   * @param context 当前上下文。
   * @returns 解析结果（含 found 标识和对应取值）。
   */
  resolveVariable(key: string, context: VariableResolveContext): VariableResolveResult {
    const scopes = this.resolveOrder();
    for (let index = 0; index < scopes.length; index += 1) {
      const scope = scopes[index];
      // scope 标识。
      const scopeId = this.scopeIdForContext(scope, context);
      const entry = this.entries.get(this.entryKey(scope, scopeId, key));
      if (entry !== undefined) {
        return this.toResolveResult(entry);
      }
    }
    const missing: VariableResolveResult = {
      found: false,
      scope: '',
      scopeId: '',
      key: key,
      value: '',
    };
    return missing;
  }

  /**
   * 展开文本中的 `{{var::key}}` 宏，替换为变量解析后的实际值。
   * @param text 包含变量宏的原始文本。
   * @param context 当前上下文。
   * @returns 变量宏被替换后的文本。
   */
  expandVariableMacros(text: string, context: VariableResolveContext): string {
    let expanded = text;
    let start = expanded.indexOf('{{var::');
    while (start >= 0) {
      const end = expanded.indexOf('}}', start);
      if (end < 0) {
        return expanded;
      }
      // 键名。
      const key = expanded.substring(start + 7, end);
      const value = this.resolveVariable(key, context).value;
      expanded = `${expanded.substring(0, start)}${value}${expanded.substring(end + 2)}`;
      start = expanded.indexOf('{{var::');
    }
    return expanded;
  }

  /**
   * 导出所有持久化变量（排除 temporary 和 pipe 作用域），用于备份或数据迁移。
   * @returns 可持久化的变量导出数据。
   */
  exportVariables(): VariableExportData {
    const exportedEntries = new Array<VariableEntry>();
    const entries = Array.from(this.entries.values());
    for (let index = 0; index < entries.length; index += 1) {
      if (entries[index].persistent) {
        exportedEntries.push(this.cloneEntry(entries[index]));
      }
    }
    const data: VariableExportData = {
      entries: exportedEntries,
      exportedAt: Date.now(),
    };
    return data;
  }

  /**
   * 从外部导入变量数据，合并到当前运行时中（覆盖同键已有条目）。
   * @param data 导入的变量数据。
   */
  importVariables(data: VariableExportData): void {
    for (let index = 0; index < data.entries.length; index += 1) {
      const entry = this.cloneEntry(data.entries[index]);
      this.entries.set(this.entryKey(entry.scope, entry.scopeId, entry.key), entry);
    }
  }

  /**
   * 获取指定作用域和对象标识下的所有变量条目。
   * @param scope 变量所属作用域。
   * @param scopeId 作用域下的对象标识。
   * @returns 匹配的变量条目副本数组。
   */
  listVariables(scope: TavernScope, scopeId: string): Array<VariableEntry> {
    const result = new Array<VariableEntry>();
    const entries = Array.from(this.entries.values());
    for (let index = 0; index < entries.length; index += 1) {
      const entry = entries[index];
      if (entry.scope === scope && entry.scopeId === scopeId) {
        result.push(this.cloneEntry(entry));
      }
    }
    return result;
  }

  /**
   * 清理所有 temporary 作用域的变量。
   */
  clearTemporaryVariables(): void {
    this.clearScope('temporary');
  }

  /**
   * 清理所有 pipe 作用域的变量。
   */
  clearPipeVariables(): void {
    this.clearScope('pipe');
  }

  /**
   * 清空指定作用域下的所有变量条目。
   * @param scope 要清空的作用域。
   */
  private clearScope(scope: TavernScope): void {
    const keys = Array.from(this.entries.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const entry = this.entries.get(keys[index]);
      if (entry !== undefined && entry.scope === scope) {
        this.entries.delete(keys[index]);
      }
    }
  }
  /**
   * 根据上下文和作用域提取对应的 scopeId。
   * @param scope 作用域。
   * @param context 当前上下文。
   * @returns 对应的 scopeId（global / temporary / pipe 返回空字符串）。
   */
  private scopeIdForContext(scope: TavernScope, context: VariableResolveContext): string {
    if (scope === 'global' || scope === 'temporary' || scope === 'pipe') {
      return '';
    }
    if (scope === 'user') {
      return context.userId;
    }
    if (scope === 'character') {
      return context.characterId;
    }
    if (scope === 'persona') {
      return context.personaId;
    }
    if (scope === 'chat') {
      return context.chatId;
    }
    if (scope === 'group') {
      return context.groupId;
    }
    if (scope === 'message') {
      return context.messageId;
    }
    if (scope === 'plugin') {
      return context.pluginId;
    }
    return '';
  }

  /**
   * 获取变量解析的作用域优先级顺序。
   * @returns 按优先级从高到低排列的作用域名称数组。
   */
  private resolveOrder(): Array<string> {
    return [
      'temporary',
      'pipe',
      'message',
      'chat',
      'group',
      'character',
      'persona',
      'user',
      'plugin',
      'global',
    ];
  }

  /**
   * 判断指定作用域是否应持久化存储（temporary 和 pipe 不持久化）。
   * @param scope 作用域。
   * @returns 需要持久化返回 true，否则 false。
   */
  private isPersistentScope(scope: TavernScope): boolean {
    return scope !== 'temporary' && scope !== 'pipe';
  }

  /**
   * 将变量条目转换为解析结果结构。
   * @param entry 变量条目。
   * @returns 解析结果（found 设为 true）。
   */
  private toResolveResult(entry: VariableEntry): VariableResolveResult {
    const result: VariableResolveResult = {
      found: true,
      scope: entry.scope,
      scopeId: entry.scopeId,
      key: entry.key,
      value: entry.value,
    };
    return result;
  }

  /**
   * 深拷贝变量条目，避免外部修改内部状态。
   * @param entry 原始变量条目。
   * @returns 独立副本。
   */
  private cloneEntry(entry: VariableEntry): VariableEntry {
    const cloned: VariableEntry = {
      scope: entry.scope,
      scopeId: entry.scopeId,
      pluginId: entry.pluginId,
      key: entry.key,
      value: entry.value,
      persistent: entry.persistent,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    };
    return cloned;
  }
  private entryKey(scope: TavernScope, scopeId: string, key: string): string {
    return `${scope}:${scopeId}:${key}`;
  }
}
