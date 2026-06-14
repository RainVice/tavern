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
   * 所有变量条目的映射表，key 为 "scope:scopeId:key" 格式。
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
   * 设置变量值，覆盖已存在的同名变量，并发布变更事件。在命令执行、宏展开和插件数据存储时调用。
   * @param scope 变量所属的作用域（如 global、user、chat、temporary 等），决定变量的生命周期和可见范围。
   * @param scopeId 作用域下的具体对象标识，用于在作用域内定位变量归属。
   * @param key 变量键名，在同一 (scope, scopeId) 内唯一标识变量。
   * @param value 要设置的变量值，将被存储在变量条目中供后续读取或宏展开使用。
   * @returns 新建或更新后的变量条目深拷贝，用于后续操作或返回给调用方。
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
   * 根据上下文信息设置指定作用域的变量。在命令处理和宏展开流程中，使用上下文自动推导 scopeId 时调用。
   * @param scope 变量所属的作用域，用于决定从上下文中提取哪个标识符作为 scopeId。
   * @param key 变量键名。
   * @param value 要设置的变量值。
   * @param context 解析上下文，用于从 scope 推算出 scopeId（如 chat 作用域取 context.chatId）。
   * @returns 新建或更新后的变量条目深拷贝。
   */
  setContextVariable(scope: string, key: string, value: string, context: VariableResolveContext): VariableEntry {
    return this.setVariable(scope, this.scopeIdForContext(scope, context), key, value);
  }

  /**
   * 设置管道变量（作用域为 pipe），用于跨组件临时数据传递，生命周期仅限当前执行链。
   * @param key 变量键名。
   * @param value 要设置的变量值，将在管道执行完成后被 clearPipeVariables 清理。
   * @returns 新建的变量条目深拷贝。
   */
  setPipeVariable(key: string, value: string): VariableEntry {
    return this.setVariable('pipe', '', key, value);
  }

  /**
   * 写入命令执行的上下文变量，相当于 setContextVariable 的别名。在命令处理流程中调用，提供更语义化的接口名称。
   * @param scope 变量所属的作用域。
   * @param key 变量键名。
   * @param value 要设置的变量值。
   * @param context 解析上下文，用于自动推导 scopeId。
   * @returns 新建或更新后的变量条目深拷贝。
   */
  writeCommandVariable(scope: string, key: string, value: string, context: VariableResolveContext): VariableEntry {
    return this.setContextVariable(scope, key, value, context);
  }

  /**
   * 读取指定作用域和键名的变量值，不存在时返回空字符串。在变量宏展开和命令执行过程中读取变量时调用。
   * @param scope 变量所属的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param key 变量键名。
   * @returns 变量值，未找到时返回空字符串，供调用方判断是否需要使用默认值。
   */
  getVariable(scope: string, scopeId: string, key: string): string {
    const entry = this.entries.get(this.entryKey(scope, scopeId, key));
    if (entry === undefined) {
      return '';
    }
    return entry.value;
  }

  /**
   * 根据上下文读取指定作用域的变量值。在命令执行和宏展开中，使用上下文自动确定 scopeId 时调用。
   * @param scope 变量所属的作用域。
   * @param key 变量键名。
   * @param context 解析上下文，用于从 scope 推算出 scopeId。
   * @returns 变量值，未找到时返回空字符串。
   */
  getContextVariable(scope: string, key: string, context: VariableResolveContext): string {
    return this.getVariable(scope, this.scopeIdForContext(scope, context), key);
  }

  /**
   * 读取管道变量的值（作用域为 pipe）。在管道数据流中读取临时传递的数据时调用。
   * @param key 变量键名。
   * @returns 变量值，未找到时返回空字符串。
   */
  getPipeVariable(key: string): string {
    return this.getVariable('pipe', '', key);
  }

  /**
   * 读取命令执行的上下文变量。当 scope 为 "resolved" 时，按优先级在各作用域中查找。在命令处理流程中读取变量时调用。
   * @param scope 变量所属的作用域，或 "resolved" 表示自动解析，按优先级链从临时到全局依次查找。
   * @param key 变量键名。
   * @param context 解析上下文，用于 scope 不为 "resolved" 时确定 scopeId，或 scope 为 "resolved" 时参与解析链路。
   * @returns 变量值。
   */
  readCommandVariable(scope: string, key: string, context: VariableResolveContext): string {
    if (scope === 'resolved') {
      return this.resolveVariable(key, context).value;
    }
    return this.getContextVariable(scope, key, context);
  }

  /**
   * 删除指定作用域和键名的变量，并发布删除事件。在变量清理或重置流程中调用。
   * @param scope 变量所属的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param key 要删除的变量键名。
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
   * 根据上下文删除指定作用域的变量。在命令处理流程中，使用上下文自动确定 scopeId 进行变量删除。
   * @param scope 变量所属的作用域。
   * @param key 要删除的变量键名。
   * @param context 解析上下文，用于从 scope 推算出 scopeId。
   */
  deleteContextVariable(scope: string, key: string, context: VariableResolveContext): void {
    this.deleteVariable(scope, this.scopeIdForContext(scope, context), key);
  }

  /**
   * 按作用域优先级链解析变量值，从最具体的临时变量开始逐级向上查找。在宏展开和命令处理中解析变量引用时调用。
   * @param key 变量键名，在所有作用域中查找匹配项。
   * @param context 解析上下文，用于按作用域类型提取对应的 scopeId 参与匹配。
   * @returns 解析结果，包含是否找到以及匹配的变量信息，供调用方获取最终的变量值。
   */
  resolveVariable(key: string, context: VariableResolveContext): VariableResolveResult {
    const scopes = this.resolveOrder();
    for (let index = 0; index < scopes.length; index += 1) {
      const scope = scopes[index];
      // 根据作用域类型从上下文中获取对应的 scopeId。
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
   * 展开文本中的变量宏（{{var::键名}} 格式），替换为实际的变量值。在提示词组装和消息处理流程中调用。
   * @param text 包含变量宏的原始文本，如聊天消息或提示词模板。
   * @param context 解析上下文，用于在宏展开时解析每个 {{var::key}} 对应的变量值。
   * @returns 变量宏被替换后的文本，用于最终的消息内容或模型输入。
   */
  expandVariableMacros(text: string, context: VariableResolveContext): string {
    let expanded = text;
    let start = expanded.indexOf('{{var::');
    while (start >= 0) {
      const end = expanded.indexOf('}}', start);
      if (end < 0) {
        return expanded;
      }
      // 提取 {{var:: 和 }} 之间的变量键名。
      const key = expanded.substring(start + 7, end);
      const value = this.resolveVariable(key, context).value;
      expanded = `${expanded.substring(0, start)}${value}${expanded.substring(end + 2)}`;
      start = expanded.indexOf('{{var::');
    }
    return expanded;
  }

  /**
   * 导出所有持久化变量，用于备份、迁移或与 SillyTavern 数据互通。在数据导出流程中调用。
   * @returns 可持久化或可传输的导出内容，包含变量条目列表和导出时间戳。
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
   * 从外部导入变量数据，将每个条目恢复到当前运行时。在数据导入或从存储恢复流程中调用。
   * @param data 导入的变量数据，包含之前导出的变量条目列表。
   */
  importVariables(data: VariableExportData): void {
    for (let index = 0; index < data.entries.length; index += 1) {
      const entry = this.cloneEntry(data.entries[index]);
      this.entries.set(this.entryKey(entry.scope, entry.scopeId, entry.key), entry);
    }
  }

  /**
   * 列出指定作用域和标识下的所有变量条目。在变量管理或调试界面中查看变量时调用。
   * @param scope 变量所属的作用域，用于过滤变量。
   * @param scopeId 作用域下的具体对象标识，用于过滤变量。
   * @returns 匹配的变量条目深拷贝列表，供 UI 展示变量列表。
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
   * 清除所有临时变量（scope 为 temporary），用于清理一次性数据。在完成单次命令执行或操作流程后调用。
   */
  clearTemporaryVariables(): void {
    this.clearScope('temporary');
  }

  /**
   * 清除所有管道变量（scope 为 pipe），用于清理跨组件临时数据。在管道数据传递完成后调用。
   */
  clearPipeVariables(): void {
    this.clearScope('pipe');
  }

  /**
   * 清除指定作用域下的所有变量条目。
   * @param scope 要清除的作用域名称。
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

  /**
   * 根据作用域类型从上下文中提取对应的标识符。
   * @param scope 作用域。
   * @param context 上下文。
   * @returns 作用域标识符。
   */
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
   * 返回变量解析时的作用域优先级顺序，从最具体到最通用。
   * @returns 按优先级排列的作用域名称数组。
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
   * 判断指定作用域是否为持久化作用域（temporary 和 pipe 不会持久化）。
   * @param scope 作用域名称。
   * @returns 持久化作用域返回 true，临时/管道作用域返回 false。
   */
  private isPersistentScope(scope: string): boolean {
    return scope !== 'temporary' && scope !== 'pipe';
  }

  /**
   * 将变量条目转换为解析结果结构。
   * @param entry 变量条目。
   * @returns 解析结果。
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
   * 深拷贝变量条目，防止外部修改内部状态。
   * @param entry 变量条目。
   * @returns 变量条目深拷贝。
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

  /**
   * 生成变量条目在映射表中的唯一存储键。
   * @param scope 作用域。
   * @param scopeId 作用域标识。
   * @param key 变量键名。
   * @returns 格式为 "scope:scopeId:key" 的存储键。
   */
  private entryKey(scope: string, scopeId: string, key: string): string {
    return `${scope}:${scopeId}:${key}`;
  }
}
