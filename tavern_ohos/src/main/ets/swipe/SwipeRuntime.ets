import { EventBus } from '../runtime/EventBus';
import type {
  SwipeChangedPayload,
  SwipeCreateParams,
  SwipeDeletedPayload,
  SwipeRecord,
  SwipeStreamState,
} from './SwipeModels';

/**
 * 提供消息候选回复相关的无 UI 运行时能力，负责候选回复记录的创建、切换、编辑、删除和流式增量追加，并通过事件总线发布对应的状态变更事件。
 */
export class SwipeRuntime {
  /**
   * 事件总线实例，用于发布候选回复状态变更事件。
   */
  private events: EventBus;
  /**
   * 按 "chatId:messageId" 键索引的候选回复列表 Map，由当前运行时内部维护。
   */
  private swipes: Map<string, Array<SwipeRecord>> = new Map<string, Array<SwipeRecord>>();

  /**
   * 构建消息候选回复运行时实例。
   * @param events 注入的事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的候选回复记录，置为 complete 状态，并发布 message.swipe.changed 事件。
   * @param params 创建参数，包含 chatId / messageId / text。
   * @returns 新创建的候选回复记录副本。
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
   * 重新生成候选回复，创建一条新的 streaming 状态的空记录并设为激活，适合流式场景。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 新创建的候选回复记录副本。
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
   * 切换到指定索引的候选回复，将其设为激活状态，同时取消其他记录激活状态。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 要切换到的候选回复索引。
   * @returns 切换后的候选回复记录副本。
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
   * 编辑指定候选回复的文本内容，状态置为 complete。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标候选回复索引。
   * @param text 更新后的文本内容。
   * @returns 编辑后的候选回复记录副本。
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
   * 删除指定候选回复，重新索引剩余记录；若删除后无激活记录则自动激活第一条，并发布 message.swipe.deleted 事件。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 要删除的候选回复索引。
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
   * 向指定候选回复追加流式增量文本，维持 streaming 状态。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标候选回复索引。
   * @param delta 本次追加的增量文本。
   * @returns 更新后的候选回复记录副本。
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
   * 标记流式候选回复完成，追加最终增量文本并将状态置为 complete。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标候选回复索引。
   * @param finalDelta 最终追加的增量文本。
   * @returns 完成后的候选回复记录副本。
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
   * 创建一条 failed 状态的候选回复，标记当前执行为失败。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param error 失败原因描述。
   * @returns 新创建的失败候选回复记录副本。
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
   * 创建一条 interrupted 状态的候选回复，标记当前执行为打断。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param text 打断时已累积的文本内容。
   * @returns 新创建的中断候选回复记录副本。
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
   * 读取指定消息当前激活的候选回复，不存在时抛出异常。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 当前激活的候选回复记录副本。
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
   * 读取指定消息的所有候选回复列表，返回副本以避免外部修改内部状态。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 候选回复记录列表的副本。
   */
  listSwipes(chatId: string, messageId: string): Array<SwipeRecord> {
    const records = this.swipes.get(this.keyOf(chatId, messageId));
    if (records === undefined) {
      return new Array<SwipeRecord>();
    }
    return this.cloneSwipes(records);
  }

  /**
   * 读取指定消息所有候选回复的运行时状态快照列表。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 候选回复运行时状态列表。
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
   * 根据 chatId 和 messageId 获取候选回复列表，不存在则创建空列表。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 候选回复列表引用（非副本）。
   */
  private getOrCreateRecords(chatId: string, messageId: string): Array<SwipeRecord> {
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
   * 根据 chatId 和 messageId 获取候选回复列表，不存在时抛出异常。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 候选回复列表引用（非副本）。
   */
  private requireRecords(chatId: string, messageId: string): Array<SwipeRecord> {
    const records = this.swipes.get(this.keyOf(chatId, messageId));
    if (records === undefined) {
      throw new Error(`Swipes not found: ${chatId}/${messageId}`);
    }
    return records;
  }

  /**
   * 根据索引从列表中获取候选回复记录，越界时抛出异常。
   * @param records 候选回复列表。
   * @param swipeIndex 目标索引。
   * @param chatId 仅用于错误消息中的上下文。
   * @param messageId 仅用于错误消息中的上下文。
   * @returns 候选回复记录引用。
   */
  private requireSwipe(records: Array<SwipeRecord>, swipeIndex: number, chatId: string, messageId: string): SwipeRecord {
    if (swipeIndex < 0 || swipeIndex >= records.length) {
      throw new Error(`Swipe not found: ${chatId}/${messageId}/${swipeIndex}`);
    }
    return records[swipeIndex];
  }

  /**
   * 创建一条 SwipeRecord 数据结构（不写入存储）。
   * @param chatId 所属聊天标识。
   * @param messageId 所属消息标识。
   * @param index 候选回复索引。
   * @param text 文本内容。
   * @param state 初始状态。
   * @param error 可选的错误信息。
   * @returns 新创建的 SwipeRecord 对象。
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
   * 将列表中所有候选回复的 active 标记设为 false。
   * @param records 候选回复列表。
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
   * 检查列表中是否存在 active 标记为 true 的记录。
   * @param records 候选回复列表。
   * @returns 存在激活记录返回 true，否则 false。
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
   * 发布 message.swipe.changed 事件，通知监听者候选回复已变更。
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
   * 深度复制 SwipeRecord，防止外部修改内部状态。
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
   * 深度复制 SwipeRecord 列表，防止外部修改内部状态。
   * @returns SwipeRecord 副本列表。
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
