import { EventBus } from '../runtime/EventBus';
import type {
  VariableChangedPayload,
  VariableDeletedPayload,
  VariableEntry,
  VariableExportData,
  VariableResolveContext,
  VariableResolveResult,
} from './VariableModels';

export class VariableRuntime {
  private events: EventBus;
  private entries: Map<string, VariableEntry> = new Map<string, VariableEntry>();

  constructor(events: EventBus) {
    this.events = events;
  }

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

  setContextVariable(scope: string, key: string, value: string, context: VariableResolveContext): VariableEntry {
    return this.setVariable(scope, this.scopeIdForContext(scope, context), key, value);
  }

  setPipeVariable(key: string, value: string): VariableEntry {
    return this.setVariable('pipe', '', key, value);
  }

  writeCommandVariable(scope: string, key: string, value: string, context: VariableResolveContext): VariableEntry {
    return this.setContextVariable(scope, key, value, context);
  }

  getVariable(scope: string, scopeId: string, key: string): string {
    const entry = this.entries.get(this.entryKey(scope, scopeId, key));
    if (entry === undefined) {
      return '';
    }
    return entry.value;
  }

  getContextVariable(scope: string, key: string, context: VariableResolveContext): string {
    return this.getVariable(scope, this.scopeIdForContext(scope, context), key);
  }

  getPipeVariable(key: string): string {
    return this.getVariable('pipe', '', key);
  }

  readCommandVariable(scope: string, key: string, context: VariableResolveContext): string {
    if (scope === 'resolved') {
      return this.resolveVariable(key, context).value;
    }
    return this.getContextVariable(scope, key, context);
  }

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

  deleteContextVariable(scope: string, key: string, context: VariableResolveContext): void {
    this.deleteVariable(scope, this.scopeIdForContext(scope, context), key);
  }

  resolveVariable(key: string, context: VariableResolveContext): VariableResolveResult {
    const scopes = this.resolveOrder();
    for (let index = 0; index < scopes.length; index += 1) {
      const scope = scopes[index];
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

  expandVariableMacros(text: string, context: VariableResolveContext): string {
    let expanded = text;
    let start = expanded.indexOf('{{var::');
    while (start >= 0) {
      const end = expanded.indexOf('}}', start);
      if (end < 0) {
        return expanded;
      }
      const key = expanded.substring(start + 7, end);
      const value = this.resolveVariable(key, context).value;
      expanded = `${expanded.substring(0, start)}${value}${expanded.substring(end + 2)}`;
      start = expanded.indexOf('{{var::');
    }
    return expanded;
  }

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

  importVariables(data: VariableExportData): void {
    for (let index = 0; index < data.entries.length; index += 1) {
      const entry = this.cloneEntry(data.entries[index]);
      this.entries.set(this.entryKey(entry.scope, entry.scopeId, entry.key), entry);
    }
  }

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

  clearTemporaryVariables(): void {
    this.clearScope('temporary');
  }

  clearPipeVariables(): void {
    this.clearScope('pipe');
  }

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

  private isPersistentScope(scope: string): boolean {
    return scope !== 'temporary' && scope !== 'pipe';
  }

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
