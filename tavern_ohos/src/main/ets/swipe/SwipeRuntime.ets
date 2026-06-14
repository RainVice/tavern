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
 * 在同一条消息上支持多个候选回复（Swipe），用户可以在不同回复间切换，是 AI 对话中"重新生成"功能的底层实现。
 */
export class SwipeRuntime {
  /**
   * 事件总线实例，用于发布候选回复变更和删除事件。
   */
  private events: EventBus;
  /**
   * 按 "chatId:messageId" 键保存的消息候选回复列表，一个消息可以有多个候选回复变体。
   */
  private swipes: Map<string, Array<SwipeRecord>> = new Map<string, Array<SwipeRecord>>();

  /**
   * 初始化 SwipeRuntime 实例。
   * @param events 事件总线实例，由宿主在初始化时注入。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的候选回复记录。
   * 在 AI 模型生成完整回复（非流式）后或用户手动添加候选时调用。
   * @param params 创建参数（聊天标识、消息标识、文本内容），由调用方传入。
   * @returns 新建的候选回复记录副本。
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
   * 重新生成候选回复：创建一条新的流式状态记录并标记为激活。
   * 在用户点击"重新生成"按钮时由 UI 层调用，用于清空当前候选并开启新一轮生成。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 新建的生成中候选回复副本。
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
   * 切换到指定索引的候选回复，取消激活其他候选回复。
   * 在用户通过 UI 左右滑动切换不同回复版本时由 UI 层调用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 要激活的候选回复索引。
   * @returns 切换后的激活候选回复副本。
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
   * 编辑指定候选回复的文本内容并重置状态为完成。
   * 在用户手动修改某条候选回复文本后由 UI 层调用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标候选回复索引。
   * @param text 编辑后的新文本。
   * @returns 编辑后的候选回复副本。
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
   * 删除指定候选回复，从数组中移除并调整后续索引。
   * 在用户删除某条候选回复时由 UI 层调用。
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
   * 在指定候选回复尾部追加流式增量文本。
   * 在流式生成过程中由 ProviderRuntime 逐段调用，用于逐步构建候选回复的完整文本。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标候选回复索引。
   * @param delta 追加的文本增量。
   * @returns 更新后的候选回复副本。
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
   * 标记流式生成为完成，追加最终增量并设置状态为 complete。
   * 在候选回复流式生成结束时由 ProviderRuntime 调用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param swipeIndex 目标候选回复索引。
   * @param finalDelta 最终追加的文本增量。
   * @returns 完成后的候选回复副本。
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
   * 标记候选回复为失败状态，记录错误信息。
   * 在流式生成因错误中断时由 ProviderRuntime 调用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param error 错误描述。
   * @returns 失败状态的新候选回复副本。
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
   * 标记候选回复为中断状态，保留已生成的部分文本。
   * 在用户手动停止生成时由 UI 层调用，保留已生成的文本供用户参考。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @param text 中断前已生成的文本。
   * @returns 中断状态的新候选回复副本。
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
   * 获取指定消息当前激活的候选回复；不存在激活项时抛出错误。
   * 在 UI 需要展示当前选中候选回复的内容时调用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 激活的候选回复副本。
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
   * 列出指定消息的所有候选回复记录（返回副本）。
   * 在 UI 需要展示某条消息的所有候选回复列表时调用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 候选回复记录数组的副本。
   */
  listSwipes(chatId: string, messageId: string): Array<SwipeRecord> {
    const records = this.swipes.get(this.keyOf(chatId, messageId));
    if (records === undefined) {
      return new Array<SwipeRecord>();
    }
    return this.cloneSwipes(records);
  }

  /**
   * 列出指定消息的候选回复流式状态列表（不含完整记录的压缩视图）。
   * 在 UI 需要批量展示候选生成状态（如加载中/已完成/失败）时调用。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 流式状态数组。
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
   * 获取或创建指定 chat/message 的候选回复列表。如果不存在则创建空列表。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 候选回复记录列表。
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
   * 获取指定 chat/message 的候选回复列表，不存在时抛出错误。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 候选回复记录列表。
   */
  private requireRecords(chatId: string, messageId: string): Array<SwipeRecord> {
    const records = this.swipes.get(this.keyOf(chatId, messageId));
    if (records === undefined) {
      throw new Error(`Swipes not found: ${chatId}/${messageId}`);
    }
    return records;
  }

  /**
   * 验证指定索引的候选回复存在，缺失时抛出错误。
   * @param records 候选回复列表。
   * @param swipeIndex 要验证的索引。
   * @param chatId 用于构造错误消息的聊天标识。
   * @param messageId 用于构造错误消息的消息标识。
   * @returns 指定索引的候选回复记录。
   */
  private requireSwipe(records: Array<SwipeRecord>, swipeIndex: number, chatId: string, messageId: string): SwipeRecord {
    if (swipeIndex < 0 || swipeIndex >= records.length) {
      throw new Error(`Swipe not found: ${chatId}/${messageId}/${swipeIndex}`);
    }
    return records[swipeIndex];
  }

  /**
   * 构造一个新的 SwipeRecord 实例（不自动添加到列表）。
   * @param chatId 聊天标识。
   * @param messageId 消息标识。
   * @param index 索引位置。
   * @param text 文本内容。
   * @param state 初始状态。
   * @param error 初始错误信息。
   * @returns 新的候选回复记录。
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
   * 将列表中所有候选回复标记为非激活。
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
   * 检查列表中是否有任意候选回复处于激活状态。
   * @param records 候选回复列表。
   * @returns 有激活项时返回 true。
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
   * 发布 message.swipe.changed 事件，通知宿主或其他 Runtime 候选回复变更。
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
   * 深度复制 SwipeRecord，防止外部代码修改内部状态。
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
   * 深度复制 SwipeRecord 数组，防止外部代码修改内部状态。
   * @returns 候选回复记录列表的副本。
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
