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
   * 事件总线，用于发布快捷回复执行和集合更新事件。
   */
  private events: EventBus;
  /**
   * 命令运行时，用于执行快捷回复关联的命令。
   */
  private commands: CommandRuntime;
  /**
   * 文件存储适配器；未传入时仅使用内存态。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 数据根路径，用于构造存储文件的路径前缀。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 用户标识，用于构造用户专属存储子路径。
   */
  private userId: string = 'default';
  /**
   * 已注册的快捷回复集合字典，键为集合标识，值为集合记录。
   */
  private sets: Map<string, QuickReplySetRecord> = new Map<string, QuickReplySetRecord>();

  /**
   * 通过注入依赖初始化快捷回复运行时实例。
   * @param events 事件总线实例，用于发布 quickReply.executed 和 quickReply.setUpdated 事件。
   * @param commands 命令运行时实例，用于执行快捷回复项绑定的命令。
   * @param files 可选的文件存储适配器，用于持久化快捷回复数据。
   * @param rootPath 可选的数据根路径，用于构造存储路径。
   * @param userId 可选的用户标识，用于构造用户专属存储子路径。
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
   * 从 SDK 内部文件存储恢复快捷回复集合。在应用启动时调用，将持久化的集合数据加载到内存。
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
   * 把当前快捷回复集合写入 SDK 内部文件存储。在集合数据发生变更后调用，确保持久化。
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
   * 创建新的快捷回复集合并写入内存，返回新集合的深拷贝。由 UI 配置页面在用户创建新集合时调用。
   * @param params 创建集合所需的参数（标识、名称、作用域、启用状态等）。
   * @returns 新创建的快捷回复集合记录副本。
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
   * 按集合标识查询快捷回复集合的深拷贝。由 UI 或外部模块在获取单个集合详情时调用。
   * @param setId 目标快捷回复集合标识。
   * @returns 集合记录的深拷贝。
   */
  getSet(setId: string): QuickReplySetRecord {
    return this.cloneSet(this.requireSet(setId));
  }

  /**
   * 返回所有快捷回复集合记录的深拷贝列表，调用方修改不影响内部状态。用于 UI 列表渲染或批量导出。
   * @returns 所有快捷回复集合记录的副本数组。
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
   * 删除指定快捷回复集合及其包含的所有项。由 UI 配置页面在用户删除集合时调用。
   * @param setId 目标快捷回复集合标识。
   */
  deleteSet(setId: string): void {
    this.requireSet(setId);
    this.sets.delete(setId);
  }

  /**
   * 向指定集合添加或更新快捷回复项，已存在同 ID 项则覆盖，否则追加。由 UI 配置页面在用户编辑快捷回复项时调用。
   * @param setId 目标快捷回复集合标识。
   * @param params 快捷回复项的创建参数（标识、标签、标题、命令、可见性等）。
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
   * 设置指定快捷回复项的可见状态并发布更新事件。由 UI 在切换项目可见性时调用。
   * @param setId 目标快捷回复集合标识。
   * @param itemId 目标快捷回复项标识。
   * @param visible 是否在 UI 中显示该项。
   * @returns 更新后的快捷回复项记录副本。
   */
  setItemVisible(setId: string, itemId: string, visible: boolean): QuickReplyItemRecord {
    const set = this.requireSet(setId);
    const item = this.requireItem(set, itemId);
    item.visible = visible;
    this.publishSetUpdated(set);
    return this.cloneItem(item);
  }

  /**
   * 从指定集合中移除快捷回复项。由 UI 配置页面在用户删除项时调用。
   * @param setId 目标快捷回复集合标识。
   * @param itemId 目标快捷回复项标识。
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
   * 根据作用域匹配规则查询所有可见且已启用的快捷回复按钮列表。在用户打开快捷回复面板时调用，获取当前上下文下可用的按钮。
   * @param scope 查询作用域类型，用于匹配集合的 scope 字段。
   * @param scopeId 作用域下的具体对象标识，用于精确匹配集合的 scopeId。
   * @returns 匹配条件的快捷回复按钮数据列表。
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
   * 执行指定集合中的快捷回复项，若项已禁用或不可见则返回跳过结果，否则执行命令并发布执行事件。
   * 在用户点击快捷回复按钮或自动触发条件匹配时调用。
   * @param setId 目标快捷回复集合标识。
   * @param itemId 目标快捷回复项标识。
   * @param options 命令执行选项（如上下文变量），传递给 CommandRuntime 执行命令时使用。
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
   * 自动检查所有集合中配置了自动触发且 trigger 匹配的项，逐一执行并收集结果。
   * 在特定事件（如消息到达）发生后由事件监听回调调用，用于自动执行符合条件的快捷回复。
   * @param trigger 触发条件字符串，与项的 trigger 字段匹配。
   * @param scope 查询作用域类型，用于过滤匹配的集合。
   * @param scopeId 作用域下的具体对象标识，用于过滤匹配的集合。
   * @param options 命令执行选项，传递给 CommandRuntime 执行命令时使用。
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
   * 导出指定快捷回复集合，生成可持久化或可传输的导出数据结构。由导出流程在用户备份或迁移数据时调用。
   * @param setId 目标快捷回复集合标识。
   * @returns 包含集合完整数据的导出对象。
   */
  exportSet(setId: string): QuickReplyExportData {
    const set = this.cloneSet(this.requireSet(setId));
    const data: QuickReplyExportData = {
      set: set,
    };
    return data;
  }

  /**
   * 从外部导出数据导入快捷回复集合，分配新标识后写入内存。由导入流程在用户从备份或其它实例恢复数据时调用。
   * @param data 外部导入的序列化集合数据。
   * @param newId 导入后使用的新集合标识，避免与现有集合冲突。
   * @returns 导入后的集合记录副本。
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
    // 提取管道中最后一步的命令名称用于结果标识。
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
   * 判断快捷回复项是否为可执行状态（同时已启用且可见）。
   * @param item 待检查的快捷回复项。
   * @returns 项可执行时返回 true，否则返回 false。
   */
  private isRunnableItem(item: QuickReplyItemRecord): boolean {
    return item.enabled && item.visible;
  }

  /**
   * 将快捷回复集合记录和项记录转换为界面按钮数据。
   * @param item 待转换的快捷回复项。
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
   * 按标识查询集合记录，不存在时抛出异常。
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
   * 按项标识在集合中查询快捷回复项，不存在时抛出异常。
   * @param itemId 目标快捷回复项标识。
   */
  private requireItem(set: QuickReplySetRecord, itemId: string): QuickReplyItemRecord {
    const index = this.findItemIndex(set, itemId);
    if (index < 0) {
      throw new Error(`Quick reply item not found: ${itemId}`);
    }
    return set.items[index];
  }

  /**
   * 在集合中按项标识查找索引位置，未找到时返回 -1。
   * @param itemId 目标快捷回复项标识。
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
   * 深拷贝集合记录及其内部所有项。
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
   * 深拷贝快捷回复项记录。
   * @param item 待拷贝的快捷回复项。
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
   * 深拷贝命令执行结果，防止外部修改。
   * @param result 待拷贝的命令执行结果。
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
   * 发布集合更新事件，通知宿主或其他 Runtime 集合状态已变化。
   */
  private publishSetUpdated(set: QuickReplySetRecord): void {
    const payloadSet = this.cloneSet(set);
    const payload: QuickReplySetUpdatedPayload = {
      set: payloadSet,
    };
    this.events.publish<QuickReplySetUpdatedPayload>('quickReply.setUpdated', payload);
  }
}
