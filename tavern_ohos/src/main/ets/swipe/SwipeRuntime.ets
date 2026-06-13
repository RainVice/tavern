import { EventBus } from '../runtime/EventBus';
import type {
  SwipeChangedPayload,
  SwipeCreateParams,
  SwipeDeletedPayload,
  SwipeRecord,
  SwipeStreamState,
} from './SwipeModels';

/**
 * 提供消息候选回复相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class SwipeRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * swipes 列表，由当前实例内部维护。
   */
  private swipes: Map<string, Array<SwipeRecord>> = new Map<string, Array<SwipeRecord>>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的候选回复记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  createSwipe(params: SwipeCreateParams): SwipeRecord {
    const records = this.getOrCreateRecords(params.chatId, params.messageId);
    const swipe = this.createRecord(params.chatId, params.messageId, records.length, params.text, 'complete', '');
    if (records.length === 0) {
      swipe.active = true;
    }
    records.push(swipe);
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  /**
   * 执行 regenerateSwipe 的内部处理步骤，供当前模块复用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   */
  regenerateSwipe(chatId: string, messageId: string): SwipeRecord {
    const records = this.getOrCreateRecords(chatId, messageId);
    this.deactivateAll(records);
    const swipe = this.createRecord(chatId, messageId, records.length, '', 'streaming', '');
    swipe.active = true;
    records.push(swipe);
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  /**
   * 更新候选回复状态，必要时写回存储并发布对应事件。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标位置索引。
   */
  switchSwipe(chatId: string, messageId: string, swipeIndex: number): SwipeRecord {
    const records = this.requireRecords(chatId, messageId);
    const swipe = this.requireSwipe(records, swipeIndex, chatId, messageId);
    this.deactivateAll(records);
    swipe.active = true;
    swipe.updatedAt = Date.now();
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  /**
   * 执行 editSwipe 的内部处理步骤，供当前模块复用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标位置索引。
   * @param text 文本内容。
   */
  editSwipe(chatId: string, messageId: string, swipeIndex: number, text: string): SwipeRecord {
    const records = this.requireRecords(chatId, messageId);
    const swipe = this.requireSwipe(records, swipeIndex, chatId, messageId);
    swipe.text = text;
    swipe.state = 'complete';
    swipe.error = '';
    swipe.updatedAt = Date.now();
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  /**
   * 删除指定候选回复，并清理相关索引或资源引用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标位置索引。
   */
  deleteSwipe(chatId: string, messageId: string, swipeIndex: number): void {
    const records = this.requireRecords(chatId, messageId);
    this.requireSwipe(records, swipeIndex, chatId, messageId);
    const wasActive = records[swipeIndex].active;
    records.splice(swipeIndex, 1);
    this.reindex(records);
    if (records.length > 0 && (wasActive || !this.hasActive(records))) {
      records[0].active = true;
      records[0].updatedAt = Date.now();
      this.publishChanged(records[0]);
    }
    const payload: SwipeDeletedPayload = {
      chatId: chatId,
      messageId: messageId,
      swipeIndex: swipeIndex,
    };
    this.events.publish<SwipeDeletedPayload>('message.swipe.deleted', payload);
  }

  /**
   * 追加Stream Delta 值，保留既有内容并写入新增片段。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标位置索引。
   */
  appendStreamDelta(chatId: string, messageId: string, swipeIndex: number, delta: string): SwipeRecord {
    const records = this.requireRecords(chatId, messageId);
    const swipe = this.requireSwipe(records, swipeIndex, chatId, messageId);
    swipe.text += delta;
    swipe.state = 'streaming';
    swipe.updatedAt = Date.now();
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  /**
   * 标记Stream 值完成，并写入最终结果。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标位置索引。
   */
  completeStream(chatId: string, messageId: string, swipeIndex: number, finalDelta: string): SwipeRecord {
    const records = this.requireRecords(chatId, messageId);
    const swipe = this.requireSwipe(records, swipeIndex, chatId, messageId);
    swipe.text += finalDelta;
    swipe.state = 'complete';
    swipe.error = '';
    swipe.updatedAt = Date.now();
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  /**
   * 更新Failed状态，必要时写回存储并发布对应事件。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param error 错误信息。
   */
  markFailed(chatId: string, messageId: string, error: string): SwipeRecord {
    const records = this.getOrCreateRecords(chatId, messageId);
    this.deactivateAll(records);
    const swipe = this.createRecord(chatId, messageId, records.length, '', 'failed', error);
    swipe.active = true;
    records.push(swipe);
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  /**
   * 更新Interrupted状态，必要时写回存储并发布对应事件。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param text 文本内容。
   */
  markInterrupted(chatId: string, messageId: string, text: string): SwipeRecord {
    const records = this.getOrCreateRecords(chatId, messageId);
    this.deactivateAll(records);
    const swipe = this.createRecord(chatId, messageId, records.length, text, 'interrupted', '');
    swipe.active = true;
    records.push(swipe);
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  /**
   * 读取指定候选回复，不存在时抛出错误。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 更新或读取后的记录副本。
   */
  getActiveSwipe(chatId: string, messageId: string): SwipeRecord {
    const records = this.requireRecords(chatId, messageId);
    for (let index = 0; index < records.length; index += 1) {
      if (records[index].active) {
        return this.cloneSwipe(records[index]);
      }
    }
    throw new Error(`Active swipe not found: ${chatId}/${messageId}`);
  }

  /**
   * 读取Swipes列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listSwipes(chatId: string, messageId: string): Array<SwipeRecord> {
    const records = this.swipes.get(this.keyOf(chatId, messageId));
    if (records === undefined) {
      return new Array<SwipeRecord>();
    }
    return this.cloneSwipes(records);
  }

  /**
   * 读取States列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listStates(chatId: string, messageId: string): Array<SwipeStreamState> {
    const records = this.listSwipes(chatId, messageId);
    const states = new Array<SwipeStreamState>();
    for (let index = 0; index < records.length; index += 1) {
      const state: SwipeStreamState = {
        index: records[index].index,
        state: records[index].state,
        text: records[index].text,
        error: records[index].error,
      };
      states.push(state);
    }
    return states;
  }

  /**
   * 读取Or Create Records 列表，不存在时通常抛出错误或返回空值。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private getOrCreateRecords(chatId: string, messageId: string): Array<SwipeRecord> {
    // 键名。
    const key = this.keyOf(chatId, messageId);
    const existing = this.swipes.get(key);
    if (existing !== undefined) {
      return existing;
    }
    const records = new Array<SwipeRecord>();
    this.swipes.set(key, records);
    return records;
  }

  /**
   * 读取必须存在的Records 列表，缺失时抛出错误。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private requireRecords(chatId: string, messageId: string): Array<SwipeRecord> {
    const records = this.swipes.get(this.keyOf(chatId, messageId));
    if (records === undefined) {
      throw new Error(`Swipes not found: ${chatId}/${messageId}`);
    }
    return records;
  }

  /**
   * 读取必须存在的Swipe 值，缺失时抛出错误。
   * @param records 记录副本列表。
   * @param swipeIndex 目标位置索引。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private requireSwipe(records: Array<SwipeRecord>, swipeIndex: number, chatId: string, messageId: string): SwipeRecord {
    if (swipeIndex < 0 || swipeIndex >= records.length) {
      throw new Error(`Swipe not found: ${chatId}/${messageId}/${swipeIndex}`);
    }
    return records[swipeIndex];
  }

  /**
   * 创建新的记录记录，写入存储并返回副本。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param index 索引数据或循环位置。
   * @param text 文本内容。

   * @param error 错误信息。
   * @returns 更新或读取后的记录副本。
   */
  private createRecord(
    chatId: string,
    messageId: string,
    index: number,
    text: string,
    state: string,
    error: string,
  ): SwipeRecord {
    const now = Date.now();
    const swipe: SwipeRecord = {
      chatId: chatId,
      messageId: messageId,
      index: index,
      text: text,
      active: false,
      state: state,
      error: error,
      createdAt: now,
      updatedAt: now,
    };
    return swipe;
  }

  /**
   * 更新All状态，必要时写回存储并发布对应事件。
   * @param records 记录副本列表。
   */
  private deactivateAll(records: Array<SwipeRecord>): void {
    for (let index = 0; index < records.length; index += 1) {
      records[index].active = false;
    }
  }
  private reindex(records: Array<SwipeRecord>): void {
    const now = Date.now();
    for (let index = 0; index < records.length; index += 1) {
      records[index].index = index;
      records[index].updatedAt = now;
    }
  }

  /**
   * 判断当前对象是否包含Active 值。
   * @param records 记录副本列表。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  private hasActive(records: Array<SwipeRecord>): boolean {
    for (let index = 0; index < records.length; index += 1) {
      if (records[index].active) {
        return true;
      }
    }
    return false;
  }

  /**
   * 发布消息候选回复事件，把状态变化通知给宿主或其他 Runtime。

   */
  private publishChanged(swipe: SwipeRecord): void {
    const payload: SwipeChangedPayload = {
      chatId: swipe.chatId,
      messageId: swipe.messageId,
      swipeIndex: swipe.index,
      swipe: this.cloneSwipe(swipe),
    };
    this.events.publish<SwipeChangedPayload>('message.swipe.changed', payload);
  }

  /**
   * 复制Swipe 值，避免外部修改内部状态。
   */
  private cloneSwipe(swipe: SwipeRecord): SwipeRecord {
    return {
      chatId: swipe.chatId,
      messageId: swipe.messageId,
      index: swipe.index,
      text: swipe.text,
      active: swipe.active,
      state: swipe.state,
      error: swipe.error,
      createdAt: swipe.createdAt,
      updatedAt: swipe.updatedAt,
    };
  }

  /**
   * 复制Swipes 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneSwipes(swipes: Array<SwipeRecord>): Array<SwipeRecord> {
    const result = new Array<SwipeRecord>();
    for (let index = 0; index < swipes.length; index += 1) {
      result.push(this.cloneSwipe(swipes[index]));
    }
    return result;
  }
  private keyOf(chatId: string, messageId: string): string {
    return `${chatId}:${messageId}`;
  }
}
