import { EventBus } from '../runtime/EventBus';
import type {
  SwipeChangedPayload,
  SwipeCreateParams,
  SwipeDeletedPayload,
  SwipeRecord,
  SwipeStreamState,
} from './SwipeModels';

export class SwipeRuntime {
  private events: EventBus;
  private swipes: Map<string, Array<SwipeRecord>> = new Map<string, Array<SwipeRecord>>();

  constructor(events: EventBus) {
    this.events = events;
  }

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

  regenerateSwipe(chatId: string, messageId: string): SwipeRecord {
    const records = this.getOrCreateRecords(chatId, messageId);
    this.deactivateAll(records);
    const swipe = this.createRecord(chatId, messageId, records.length, '', 'streaming', '');
    swipe.active = true;
    records.push(swipe);
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  switchSwipe(chatId: string, messageId: string, swipeIndex: number): SwipeRecord {
    const records = this.requireRecords(chatId, messageId);
    const swipe = this.requireSwipe(records, swipeIndex, chatId, messageId);
    this.deactivateAll(records);
    swipe.active = true;
    swipe.updatedAt = Date.now();
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

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

  appendStreamDelta(chatId: string, messageId: string, swipeIndex: number, delta: string): SwipeRecord {
    const records = this.requireRecords(chatId, messageId);
    const swipe = this.requireSwipe(records, swipeIndex, chatId, messageId);
    swipe.text += delta;
    swipe.state = 'streaming';
    swipe.updatedAt = Date.now();
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

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

  markFailed(chatId: string, messageId: string, error: string): SwipeRecord {
    const records = this.getOrCreateRecords(chatId, messageId);
    this.deactivateAll(records);
    const swipe = this.createRecord(chatId, messageId, records.length, '', 'failed', error);
    swipe.active = true;
    records.push(swipe);
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  markInterrupted(chatId: string, messageId: string, text: string): SwipeRecord {
    const records = this.getOrCreateRecords(chatId, messageId);
    this.deactivateAll(records);
    const swipe = this.createRecord(chatId, messageId, records.length, text, 'interrupted', '');
    swipe.active = true;
    records.push(swipe);
    this.publishChanged(swipe);
    return this.cloneSwipe(swipe);
  }

  getActiveSwipe(chatId: string, messageId: string): SwipeRecord {
    const records = this.requireRecords(chatId, messageId);
    for (let index = 0; index < records.length; index += 1) {
      if (records[index].active) {
        return this.cloneSwipe(records[index]);
      }
    }
    throw new Error(`Active swipe not found: ${chatId}/${messageId}`);
  }

  listSwipes(chatId: string, messageId: string): Array<SwipeRecord> {
    const records = this.swipes.get(this.keyOf(chatId, messageId));
    if (records === undefined) {
      return new Array<SwipeRecord>();
    }
    return this.cloneSwipes(records);
  }

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

  private requireRecords(chatId: string, messageId: string): Array<SwipeRecord> {
    const records = this.swipes.get(this.keyOf(chatId, messageId));
    if (records === undefined) {
      throw new Error(`Swipes not found: ${chatId}/${messageId}`);
    }
    return records;
  }

  private requireSwipe(records: Array<SwipeRecord>, swipeIndex: number, chatId: string, messageId: string): SwipeRecord {
    if (swipeIndex < 0 || swipeIndex >= records.length) {
      throw new Error(`Swipe not found: ${chatId}/${messageId}/${swipeIndex}`);
    }
    return records[swipeIndex];
  }

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

  private hasActive(records: Array<SwipeRecord>): boolean {
    for (let index = 0; index < records.length; index += 1) {
      if (records[index].active) {
        return true;
      }
    }
    return false;
  }

  private publishChanged(swipe: SwipeRecord): void {
    const payload: SwipeChangedPayload = {
      chatId: swipe.chatId,
      messageId: swipe.messageId,
      swipeIndex: swipe.index,
      swipe: this.cloneSwipe(swipe),
    };
    this.events.publish<SwipeChangedPayload>('message.swipe.changed', payload);
  }

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
