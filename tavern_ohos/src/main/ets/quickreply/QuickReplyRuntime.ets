import { CommandRuntime } from '../command/CommandRuntime';
import type {
  CommandExecuteOptions,
  CommandExecutionResult,
  CommandPipelineResult,
} from '../command/CommandModels';
import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
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

interface QuickReplyStorageSnapshot {
  schemaVersion: number;
  sets: Array<QuickReplySetRecord>;
}

/**
 * 提供快捷回复相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class QuickReplyRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * commands 列表，由当前实例内部维护。
   */
  private commands: CommandRuntime;
  /**
   * 文件存储适配器；未传入时仅使用内存态。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 用户标识。
   */
  private userId: string = 'default';
  /**
   * sets 列表，由当前实例内部维护。
   */
  private sets: Map<string, QuickReplySetRecord> = new Map<string, QuickReplySetRecord>();

  /**
   * 注入快捷回复运行时依赖并初始化实例状态。
   * @param events 事件总线。
   */
  constructor(
    events: EventBus,
    commands: CommandRuntime,
    files?: TavernFileStore,
    rootPath: string = 'tavern-data',
    userId: string = 'default',
  ) {
    this.events = events;
    this.commands = commands;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从 SDK 内部文件存储恢复快捷回复集合。
   */
  async loadFromStore(): Promise<void> {
    const store = new JsonStore<QuickReplyStorageSnapshot>(this.requireFiles(), this.storagePath());
    const snapshot = await store.read(this.defaultStorageSnapshot());
    this.sets.clear();
    for (let index = 0; index < snapshot.sets.length; index += 1) {
      const set = this.cloneSet(snapshot.sets[index]);
      this.sets.set(set.id, set);
    }
  }

  /**
   * 把当前快捷回复集合写入 SDK 内部文件存储。
   */
  async saveToStore(): Promise<void> {
    const sets = this.cloneSets(Array.from(this.sets.values()));
    const snapshot: QuickReplyStorageSnapshot = {
      schemaVersion: 1,
      sets: sets,
    };
    await new JsonStore<QuickReplyStorageSnapshot>(this.requireFiles(), this.storagePath()).write(snapshot);
  }

  /**
   * 创建新的快捷回复集合记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 读取指定Set，不存在时抛出错误。
   * @param setId 目标快捷回复集合标识。
   * @returns 更新或读取后的记录副本。
   */
  getSet(setId: string): QuickReplySetRecord {
    return this.cloneSet(this.requireSet(setId));
  }

  /**
   * 读取Sets列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listSets(): Array<QuickReplySetRecord> {
    const result = new Array<QuickReplySetRecord>();
    const values = Array.from(this.sets.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.cloneSet(values[index]));
    }
    return result;
  }

  /**
   * 删除指定Set，并清理相关索引或资源引用。
   * @param setId 目标快捷回复集合标识。
   */
  deleteSet(setId: string): void {
    this.requireSet(setId);
    this.sets.delete(setId);
  }

  /**
   * 创建或写入Item，完成持久化后返回可供调用方使用的结果。
   * @param setId 目标快捷回复集合标识。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
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

  /**
   * 设置快捷回复项可见状态，用于切换运行时状态或保存配置。
   * @param setId 目标快捷回复集合标识。
   * @param itemId 目标内容项标识。
   * @param visible 是否显示对应 UI。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  setItemVisible(setId: string, itemId: string, visible: boolean): QuickReplyItemRecord {
    const set = this.requireSet(setId);
    const item = this.requireItem(set, itemId);
    item.visible = visible;
    this.publishSetUpdated(set);
    return this.cloneItem(item);
  }

  /**
   * 移除内容项，用于解除注册、绑定或索引关系。
   * @param setId 目标快捷回复集合标识。
   * @param itemId 目标内容项标识。
   */
  removeItem(setId: string, itemId: string): void {
    const set = this.requireSet(setId);
    const index = this.findItemIndex(set, itemId);
    if (index < 0) {
      throw new Error(`Quick reply item not found: ${itemId}`);
    }
    set.items.splice(index, 1);
    this.publishSetUpdated(set);
  }

  /**
   * 读取Buttons列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 执行 executeItem 的内部处理步骤，供当前模块复用。
   * @param setId 目标快捷回复集合标识。
   * @param itemId 目标内容项标识。
   * @param options 控制本次调用行为的选项。
   */
  async executeItem(
    setId: string,
    itemId: string,
    options: CommandExecuteOptions,
  ): Promise<QuickReplyExecutionResult> {
    const set = this.requireSet(setId);
    const item = this.requireItem(set, itemId);
    if (!set.enabled || !this.isRunnableItem(item)) {
      const skipped = this.makeSkippedResult(item);
      const skippedSet = this.cloneSet(set);
      const skippedItem = this.cloneItem(item);
      const skippedResult = this.cloneCommandResult(skipped);
      return {
        set: skippedSet,
        item: skippedItem,
        executed: false,
        commandResult: skippedResult,
      };
    }
    const commandResult = await this.executeCommand(item.command, options);
    const payloadSet = this.cloneSet(set);
    const payloadItem = this.cloneItem(item);
    const payloadCommandResult = this.cloneCommandResult(commandResult);
    const payload: QuickReplyExecutedPayload = {
      set: payloadSet,
      item: payloadItem,
      commandResult: payloadCommandResult,
    };
    this.events.publish<QuickReplyExecutedPayload>('quickReply.executed', payload);
    const resultSet = this.cloneSet(set);
    const resultItem = this.cloneItem(item);
    const resultCommandResult = this.cloneCommandResult(commandResult);
    return {
      set: resultSet,
      item: resultItem,
      executed: commandResult.ok,
      commandResult: resultCommandResult,
    };
  }

  /**
   * 执行 executeAutoTrigger 的内部处理步骤，供当前模块复用。

   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param options 控制本次调用行为的选项。
   */
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

  /**
   * 导出快捷回复集合，用于备份、迁移或与 SillyTavern 数据互通。
   * @param setId 目标快捷回复集合标识。
   * @returns 可持久化或可传输的导出内容。
   */
  exportSet(setId: string): QuickReplyExportData {
    const set = this.cloneSet(this.requireSet(setId));
    const data: QuickReplyExportData = {
      set: set,
    };
    return data;
  }

  /**
   * 从外部数据导入Set 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   * @param newId 目标新记录标识。
   * @returns 更新或读取后的记录副本。
   */
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
    // command 名称。
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

  /**
   * 判断Runnable Item 值是否满足条件。
   * @param item 项目记录。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  private isRunnableItem(item: QuickReplyItemRecord): boolean {
    return item.enabled && item.visible;
  }

  /**
   * 把快捷回复项转换为界面按钮数据。

   * @param item 项目记录。
   */
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

  /**
   * 读取必须存在的Set 值，缺失时抛出错误。
   * @param setId 目标快捷回复集合标识。
   */
  private requireSet(setId: string): QuickReplySetRecord {
    const set = this.sets.get(setId);
    if (set === undefined) {
      throw new Error(`Quick reply set not found: ${setId}`);
    }
    return set;
  }

  private requireFiles(): TavernFileStore {
    if (this.files === undefined) {
      throw new Error('QuickReplyRuntime storage is not configured.');
    }
    return this.files;
  }

  private storagePath(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/quick-replies/sets/index.json`;
  }

  private defaultStorageSnapshot(): QuickReplyStorageSnapshot {
    return {
      schemaVersion: 1,
      sets: new Array<QuickReplySetRecord>(),
    };
  }

  /**
   * 读取必须存在的Item 值，缺失时抛出错误。

   * @param itemId 目标内容项标识。
   */
  private requireItem(set: QuickReplySetRecord, itemId: string): QuickReplyItemRecord {
    const index = this.findItemIndex(set, itemId);
    if (index < 0) {
      throw new Error(`Quick reply item not found: ${itemId}`);
    }
    return set.items[index];
  }

  /**
   * 在当前集合中查找Item Index 值，未命中时返回空值或默认位置。

   * @param itemId 目标内容项标识。
   */
  private findItemIndex(set: QuickReplySetRecord, itemId: string): number {
    for (let index = 0; index < set.items.length; index += 1) {
      if (set.items[index].id === itemId) {
        return index;
      }
    }
    return -1;
  }

  /**
   * 复制Set 值，避免外部修改内部状态。
   */
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

  private cloneSets(sets: Array<QuickReplySetRecord>): Array<QuickReplySetRecord> {
    const cloned = new Array<QuickReplySetRecord>();
    for (let index = 0; index < sets.length; index += 1) {
      cloned.push(this.cloneSet(sets[index]));
    }
    return cloned;
  }

  /**
   * 复制Item 值，避免外部修改内部状态。
   * @param item 项目记录。
   */
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

  /**
   * 复制Command Result 值，避免外部修改内部状态。
   * @param result 返回结果。
   */
  private cloneCommandResult(result: CommandExecutionResult): CommandExecutionResult {
    return {
      ok: result.ok,
      commandName: result.commandName,
      output: result.output,
      error: result.error,
      cancelled: result.cancelled,
    };
  }

  /**
   * 发布快捷回复事件，把状态变化通知给宿主或其他 Runtime。

   */
  private publishSetUpdated(set: QuickReplySetRecord): void {
    const payloadSet = this.cloneSet(set);
    const payload: QuickReplySetUpdatedPayload = {
      set: payloadSet,
    };
    this.events.publish<QuickReplySetUpdatedPayload>('quickReply.setUpdated', payload);
  }
}
