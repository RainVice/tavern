import { EventBus } from '../runtime/EventBus';
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
   * 条目列表，由当前实例内部维护。
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
   * 设置变量，用于切换运行时状态或保存配置。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param key 键名。
   * @param value 要保存或比较的字段值。
   */
  setVariable(scope: string, scopeId: string, key: string, value: string): VariableEntry {
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
   * 设置上下文变量，用于切换运行时状态或保存配置。
   * @param scope 绑定或查询使用的作用域。
   * @param key 键名。
   * @param value 要保存或比较的字段值。
   */
  setContextVariable(scope: string, key: string, value: string, context: VariableResolveContext): VariableEntry {
    return this.setVariable(scope, this.scopeIdForContext(scope, context), key, value);
  }

  /**
   * 设置管道变量，用于切换运行时状态或保存配置。
   * @param key 键名。
   * @param value 要保存或比较的字段值。
   */
  setPipeVariable(key: string, value: string): VariableEntry {
    return this.setVariable('pipe', '', key, value);
  }

  /**
   * 写入Command Variable 值，持久化当前运行时状态。
   * @param scope 绑定或查询使用的作用域。
   * @param key 键名。
   * @param value 要保存或比较的字段值。
   */
  writeCommandVariable(scope: string, key: string, value: string, context: VariableResolveContext): VariableEntry {
    return this.setContextVariable(scope, key, value, context);
  }

  /**
   * 读取指定Variable，不存在时抛出错误。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param key 键名。
   * @returns 更新或读取后的记录副本。
   */
  getVariable(scope: string, scopeId: string, key: string): string {
    const entry = this.entries.get(this.entryKey(scope, scopeId, key));
    if (entry === undefined) {
      return '';
    }
    return entry.value;
  }

  /**
   * 读取指定ContextVariable，不存在时抛出错误。
   * @param scope 绑定或查询使用的作用域。
   * @param key 键名。

   * @returns 更新或读取后的记录副本。
   */
  getContextVariable(scope: string, key: string, context: VariableResolveContext): string {
    return this.getVariable(scope, this.scopeIdForContext(scope, context), key);
  }

  /**
   * 读取指定PipeVariable，不存在时抛出错误。
   * @param key 键名。
   * @returns 更新或读取后的记录副本。
   */
  getPipeVariable(key: string): string {
    return this.getVariable('pipe', '', key);
  }

  /**
   * 读取Command Variable 值，并转换为运行时使用的数据结构。
   * @param scope 绑定或查询使用的作用域。
   * @param key 键名。
   */
  readCommandVariable(scope: string, key: string, context: VariableResolveContext): string {
    if (scope === 'resolved') {
      return this.resolveVariable(key, context).value;
    }
    return this.getContextVariable(scope, key, context);
  }

  /**
   * 删除指定Variable，并清理相关索引或资源引用。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param key 键名。
   */
  deleteVariable(scope: string, scopeId: string, key: string): void {
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
   * 删除指定ContextVariable，并清理相关索引或资源引用。
   * @param scope 绑定或查询使用的作用域。
   * @param key 键名。

   */
  deleteContextVariable(scope: string, key: string, context: VariableResolveContext): void {
    this.deleteVariable(scope, this.scopeIdForContext(scope, context), key);
  }

  /**
   * 根据当前上下文解析Variable 值，返回实际可用值。
   * @param key 键名。
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
   * 执行 expandVariableMacros 的内部处理步骤，供当前模块复用。
   * @param text 文本内容。
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
   * 导出变量列表，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 可持久化或可传输的导出内容。
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
   * 从外部数据导入Variables 列表，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  importVariables(data: VariableExportData): void {
    for (let index = 0; index < data.entries.length; index += 1) {
      const entry = this.cloneEntry(data.entries[index]);
      this.entries.set(this.entryKey(entry.scope, entry.scopeId, entry.key), entry);
    }
  }

  /**
   * 读取Variables列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listVariables(scope: string, scopeId: string): Array<VariableEntry> {
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
   * 删除或清理TemporaryVariables，并同步维护相关索引或状态。
   */
  clearTemporaryVariables(): void {
    this.clearScope('temporary');
  }

  /**
   * 删除或清理PipeVariables，并同步维护相关索引或状态。
   */
  clearPipeVariables(): void {
    this.clearScope('pipe');
  }

  /**
   * 删除或清理Scope，并同步维护相关索引或状态。
   * @param scope 绑定或查询使用的作用域。
   */
  private clearScope(scope: string): void {
    const keys = Array.from(this.entries.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const entry = this.entries.get(keys[index]);
      if (entry !== undefined && entry.scope === scope) {
        this.entries.delete(keys[index]);
      }
    }
  }
  private scopeIdForContext(scope: string, context: VariableResolveContext): string {
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
   * 根据当前上下文解析Order 值，返回实际可用值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 判断Persistent Scope 值是否满足条件。
   * @param scope 绑定或查询使用的作用域。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  private isPersistentScope(scope: string): boolean {
    return scope !== 'temporary' && scope !== 'pipe';
  }

  /**
   * 把变量解析过程转换为解析结果结构。
   * @param entry 条目记录。
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
   * 复制Entry 值，避免外部修改内部状态。
   * @param entry 条目记录。
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
  private entryKey(scope: string, scopeId: string, key: string): string {
    return `${scope}:${scopeId}:${key}`;
  }
}
