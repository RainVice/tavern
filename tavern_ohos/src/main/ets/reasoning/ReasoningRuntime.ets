import {
  EventBus,
  type EventSubscription,
  type RuntimeEvent,
} from '../runtime/EventBus';
import type { StreamDeltaPayload } from '../streaming/StreamingModels';
import type {
  ReasoningDeltaPayload,
  ReasoningRecord,
  ReasoningUpdatedPayload,
} from './ReasoningModels';

export class ReasoningRuntime {
  private events: EventBus;
  private records: Map<string, ReasoningRecord> = new Map<string, ReasoningRecord>();
  private streamSubscription: EventSubscription | null = null;

  constructor(events: EventBus) {
    this.events = events;
  }

  startStreamingAccumulator(): void {
    if (this.streamSubscription !== null) {
      return;
    }
    this.streamSubscription = this.events.subscribe<StreamDeltaPayload>(
      'stream.delta',
      (event: RuntimeEvent<StreamDeltaPayload>) => {
        if (!event.payload.reasoning) {
          return;
        }
        this.applyDelta(event.payload.messageId, event.payload.delta);
      },
    );
  }

  stopStreamingAccumulator(): void {
    if (this.streamSubscription === null) {
      return;
    }
    this.streamSubscription.unsubscribe();
    this.streamSubscription = null;
  }

  applyDelta(messageId: string, delta: string): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.snapshot += delta;
    record.updatedAt = Date.now();
    const payload: ReasoningDeltaPayload = {
      reasoning: this.copyRecord(record),
      delta: delta,
    };
    this.events.publish<ReasoningDeltaPayload>('reasoning.delta', payload);
    this.events.publish<ReasoningDeltaPayload>('message.reasoning.delta', {
      reasoning: this.copyRecord(record),
      delta: delta,
    });
    return this.copyRecord(record);
  }

  editReasoning(messageId: string, snapshot: string): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.snapshot = snapshot;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  setMetadata(messageId: string, metadataJson: string, signature: string): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.metadataJson = metadataJson;
    record.signature = signature;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  setVisibility(messageId: string, visible: boolean): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.visible = visible;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  setPromptPolicy(messageId: string, includeInPrompt: boolean): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.includeInPrompt = includeInPrompt;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  copyReasoning(messageId: string): string {
    return this.getReasoning(messageId).snapshot;
  }

  formatForPrompt(messageId: string): string {
    const record = this.getReasoning(messageId);
    if (!record.includeInPrompt || record.snapshot.length === 0) {
      return '';
    }
    return `<reasoning>\n${record.snapshot}\n</reasoning>`;
  }

  getReasoning(messageId: string): ReasoningRecord {
    return this.copyRecord(this.ensureRecord(messageId));
  }

  listReasoning(): Array<ReasoningRecord> {
    const result = new Array<ReasoningRecord>();
    const values = Array.from(this.records.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyRecord(values[index]));
    }
    return result;
  }

  private ensureRecord(messageId: string): ReasoningRecord {
    const existing = this.records.get(messageId);
    if (existing !== undefined) {
      return existing;
    }
    const now = Date.now();
    const record: ReasoningRecord = {
      messageId: messageId,
      snapshot: '',
      metadataJson: '',
      signature: '',
      visible: true,
      includeInPrompt: false,
      createdAt: now,
      updatedAt: now,
    };
    this.records.set(messageId, record);
    return record;
  }

  private publishUpdated(record: ReasoningRecord): void {
    const payload: ReasoningUpdatedPayload = {
      reasoning: this.copyRecord(record),
    };
    this.events.publish<ReasoningUpdatedPayload>('reasoning.updated', payload);
    this.events.publish<ReasoningUpdatedPayload>('message.reasoning.updated', payload);
  }

  private copyRecord(record: ReasoningRecord): ReasoningRecord {
    return {
      messageId: record.messageId,
      snapshot: record.snapshot,
      metadataJson: record.metadataJson,
      signature: record.signature,
      visible: record.visible,
      includeInPrompt: record.includeInPrompt,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }
}
