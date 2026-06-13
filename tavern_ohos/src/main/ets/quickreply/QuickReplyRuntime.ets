import { CommandRuntime } from '../command/CommandRuntime';
import type {
  CommandExecuteOptions,
  CommandExecutionResult,
  CommandPipelineResult,
} from '../command/CommandModels';
import { EventBus } from '../runtime/EventBus';
import type {
  QuickReplyButtonData,
  QuickReplyExecutedPayload,
  QuickReplyExecutionResult,
  QuickReplyExportData,
  QuickReplyItemCreateParams,
  QuickReplyItemRecord,
  QuickReplySetCreateParams,
  QuickReplySetRecord,
  QuickReplySetUpdatedPayload,
} from './QuickReplyModels';

export class QuickReplyRuntime {
  private events: EventBus;
  private commands: CommandRuntime;
  private sets: Map<string, QuickReplySetRecord> = new Map<string, QuickReplySetRecord>();

  constructor(events: EventBus, commands: CommandRuntime) {
    this.events = events;
    this.commands = commands;
  }

  createSet(params: QuickReplySetCreateParams): QuickReplySetRecord {
    if (this.sets.has(params.id)) {
      throw new Error(`Quick reply set already exists: ${params.id}`);
    }
    const record: QuickReplySetRecord = {
      id: params.id,
      name: params.name,
      scope: params.scope,
      scopeId: params.scopeId,
      enabled: params.enabled,
      items: new Array<QuickReplyItemRecord>(),
    };
    this.sets.set(record.id, this.cloneSet(record));
    this.publishSetUpdated(record);
    return this.cloneSet(record);
  }

  getSet(setId: string): QuickReplySetRecord {
    return this.cloneSet(this.requireSet(setId));
  }

  listSets(): Array<QuickReplySetRecord> {
    const result = new Array<QuickReplySetRecord>();
    const values = Array.from(this.sets.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.cloneSet(values[index]));
    }
    return result;
  }

  deleteSet(setId: string): void {
    this.requireSet(setId);
    this.sets.delete(setId);
  }

  addItem(setId: string, params: QuickReplyItemCreateParams): QuickReplyItemRecord {
    const set = this.requireSet(setId);
    const item: QuickReplyItemRecord = {
      id: params.id,
      label: params.label,
      title: params.title,
      command: params.command,
      enabled: params.enabled,
      visible: params.visible,
      autoExecute: params.autoExecute,
      trigger: params.trigger,
      pluginId: params.pluginId,
    };
    const existingIndex = this.findItemIndex(set, item.id);
    if (existingIndex >= 0) {
      set.items[existingIndex] = item;
    } else {
      set.items.push(item);
    }
    this.publishSetUpdated(set);
    return this.cloneItem(item);
  }

  setItemVisible(setId: string, itemId: string, visible: boolean): QuickReplyItemRecord {
    const set = this.requireSet(setId);
    const item = this.requireItem(set, itemId);
    item.visible = visible;
    this.publishSetUpdated(set);
    return this.cloneItem(item);
  }

  removeItem(setId: string, itemId: string): void {
    const set = this.requireSet(setId);
    const index = this.findItemIndex(set, itemId);
    if (index < 0) {
      throw new Error(`Quick reply item not found: ${itemId}`);
    }
    set.items.splice(index, 1);
    this.publishSetUpdated(set);
  }

  listButtons(scope: string, scopeId: string): Array<QuickReplyButtonData> {
    const buttons = new Array<QuickReplyButtonData>();
    const sets = Array.from(this.sets.values());
    for (let setIndex = 0; setIndex < sets.length; setIndex += 1) {
      const set = sets[setIndex];
      if (!set.enabled || !this.scopeMatches(set, scope, scopeId)) {
        continue;
      }
      for (let itemIndex = 0; itemIndex < set.items.length; itemIndex += 1) {
        const item = set.items[itemIndex];
        if (this.isRunnableItem(item)) {
          buttons.push(this.toButton(set, item));
        }
      }
    }
    return buttons;
  }

  async executeItem(
    setId: string,
    itemId: string,
    options: CommandExecuteOptions,
  ): Promise<QuickReplyExecutionResult> {
    const set = this.requireSet(setId);
    const item = this.requireItem(set, itemId);
    if (!set.enabled || !this.isRunnableItem(item)) {
      const skipped = this.makeSkippedResult(item);
      return {
        set: this.cloneSet(set),
        item: this.cloneItem(item),
        executed: false,
        commandResult: this.cloneCommandResult(skipped),
      };
    }
    const commandResult = await this.executeCommand(item.command, options);
    const payload: QuickReplyExecutedPayload = {
      set: this.cloneSet(set),
      item: this.cloneItem(item),
      commandResult: this.cloneCommandResult(commandResult),
    };
    this.events.publish<QuickReplyExecutedPayload>('quickReply.executed', payload);
    return {
      set: this.cloneSet(set),
      item: this.cloneItem(item),
      executed: commandResult.ok,
      commandResult: this.cloneCommandResult(commandResult),
    };
  }

  async executeAutoTrigger(
    trigger: string,
    scope: string,
    scopeId: string,
    options: CommandExecuteOptions,
  ): Promise<Array<QuickReplyExecutionResult>> {
    const results = new Array<QuickReplyExecutionResult>();
    const sets = Array.from(this.sets.values());
    for (let setIndex = 0; setIndex < sets.length; setIndex += 1) {
      const set = sets[setIndex];
      if (!set.enabled || !this.scopeMatches(set, scope, scopeId)) {
        continue;
      }
      for (let itemIndex = 0; itemIndex < set.items.length; itemIndex += 1) {
        const item = set.items[itemIndex];
        if (this.isRunnableItem(item) && item.autoExecute && item.trigger === trigger) {
          const result = await this.executeItem(set.id, item.id, options);
          results.push(result);
        }
      }
    }
    return results;
  }

  exportSet(setId: string): QuickReplyExportData {
    const data: QuickReplyExportData = {
      set: this.cloneSet(this.requireSet(setId)),
    };
    return data;
  }

  importSet(data: QuickReplyExportData, newId: string): QuickReplySetRecord {
    if (this.sets.has(newId)) {
      throw new Error(`Quick reply set already exists: ${newId}`);
    }
    const imported = this.cloneSet(data.set);
    imported.id = newId;
    this.sets.set(imported.id, this.cloneSet(imported));
    this.publishSetUpdated(imported);
    return this.cloneSet(imported);
  }

  private async executeCommand(command: string, options: CommandExecuteOptions): Promise<CommandExecutionResult> {
    if (command.trim().length === 0) {
      return this.makeCommandResult(false, 'quick-reply', '', 'Quick reply command is empty.', false);
    }
    try {
      if (command.indexOf('|') >= 0) {
        const pipeline = await this.commands.executePipeline(command, options);
        return this.pipelineToExecutionResult(pipeline);
      }
      return await this.commands.executeText(command, options);
    } catch (error) {
      return this.makeCommandResult(false, 'quick-reply', '', String(error), false);
    }
  }

  private pipelineToExecutionResult(pipeline: CommandPipelineResult): CommandExecutionResult {
    let commandName = 'quick-reply';
    if (pipeline.steps.length > 0) {
      commandName = pipeline.steps[pipeline.steps.length - 1].commandName;
    }
    return this.makeCommandResult(
      pipeline.ok,
      commandName,
      pipeline.finalOutput,
      pipeline.error,
      pipeline.cancelled,
    );
  }

  private makeSkippedResult(item: QuickReplyItemRecord): CommandExecutionResult {
    return this.makeCommandResult(false, item.id, '', 'Quick reply item is disabled or hidden.', false);
  }

  private makeCommandResult(
    ok: boolean,
    commandName: string,
    output: string,
    error: string,
    cancelled: boolean,
  ): CommandExecutionResult {
    const result: CommandExecutionResult = {
      ok: ok,
      commandName: commandName,
      output: output,
      error: error,
      cancelled: cancelled,
    };
    return result;
  }

  private scopeMatches(set: QuickReplySetRecord, scope: string, scopeId: string): boolean {
    if (set.scope === 'global') {
      return scope === 'global';
    }
    if (set.scope !== scope) {
      return false;
    }
    if (set.scopeId.length === 0) {
      return true;
    }
    return set.scopeId === scopeId;
  }

  private isRunnableItem(item: QuickReplyItemRecord): boolean {
    return item.enabled && item.visible;
  }

  private toButton(set: QuickReplySetRecord, item: QuickReplyItemRecord): QuickReplyButtonData {
    const button: QuickReplyButtonData = {
      setId: set.id,
      itemId: item.id,
      label: item.label,
      title: item.title,
      command: item.command,
      scope: set.scope,
      scopeId: set.scopeId,
      pluginId: item.pluginId,
    };
    return button;
  }

  private requireSet(setId: string): QuickReplySetRecord {
    const set = this.sets.get(setId);
    if (set === undefined) {
      throw new Error(`Quick reply set not found: ${setId}`);
    }
    return set;
  }

  private requireItem(set: QuickReplySetRecord, itemId: string): QuickReplyItemRecord {
    const index = this.findItemIndex(set, itemId);
    if (index < 0) {
      throw new Error(`Quick reply item not found: ${itemId}`);
    }
    return set.items[index];
  }

  private findItemIndex(set: QuickReplySetRecord, itemId: string): number {
    for (let index = 0; index < set.items.length; index += 1) {
      if (set.items[index].id === itemId) {
        return index;
      }
    }
    return -1;
  }

  private cloneSet(set: QuickReplySetRecord): QuickReplySetRecord {
    const items = new Array<QuickReplyItemRecord>();
    for (let index = 0; index < set.items.length; index += 1) {
      items.push(this.cloneItem(set.items[index]));
    }
    const cloned: QuickReplySetRecord = {
      id: set.id,
      name: set.name,
      scope: set.scope,
      scopeId: set.scopeId,
      enabled: set.enabled,
      items: items,
    };
    return cloned;
  }

  private cloneItem(item: QuickReplyItemRecord): QuickReplyItemRecord {
    const cloned: QuickReplyItemRecord = {
      id: item.id,
      label: item.label,
      title: item.title,
      command: item.command,
      enabled: item.enabled,
      visible: item.visible,
      autoExecute: item.autoExecute,
      trigger: item.trigger,
      pluginId: item.pluginId,
    };
    return cloned;
  }

  private cloneCommandResult(result: CommandExecutionResult): CommandExecutionResult {
    return {
      ok: result.ok,
      commandName: result.commandName,
      output: result.output,
      error: result.error,
      cancelled: result.cancelled,
    };
  }

  private publishSetUpdated(set: QuickReplySetRecord): void {
    const payload: QuickReplySetUpdatedPayload = {
      set: this.cloneSet(set),
    };
    this.events.publish<QuickReplySetUpdatedPayload>('quickReply.setUpdated', payload);
  }
}
