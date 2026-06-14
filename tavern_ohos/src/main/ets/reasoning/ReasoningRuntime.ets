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

/**
 * 推理运行时：负责管理推理记录的状态、订阅流式增量事件并发布状态变更事件。
 */
export class ReasoningRuntime {
  /** 事件总线，用于订阅和发布推理相关事件。 */
  private events: EventBus;
  /** 推理记录缓存，以 messageId 为键。 */
  private records: Map<string, ReasoningRecord> = new Map<string, ReasoningRecord>();
  /** 流式增量事件的订阅句柄，未订阅时为 null。 */
  private streamSubscription: EventSubscription | null = null;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 订阅 stream.delta 事件，开始累积流式推理内容的增量文本。
   */
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

  /**
   * 取消订阅 stream.delta 事件，停止累积流式推理内容。
   */
  stopStreamingAccumulator(): void {
    if (this.streamSubscription === null) {
      return;
    }
    this.streamSubscription.unsubscribe();
    this.streamSubscription = null;
  }

  /**
   * 对指定消息的推理记录追加增量文本，更新快照并发布 delta 事件。
   * @param messageId 目标消息标识。
   * @param delta 待追加的增量文本。
   * @returns 更新后的推理记录副本。
   */
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

  /**
   * 直接替换指定消息的推理快照内容，并发布更新事件。
   * @param messageId 目标消息标识。
   * @param snapshot 新的推理内容文本。
   * @returns 更新后的推理记录副本。
   */
  editReasoning(messageId: string, snapshot: string): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.snapshot = snapshot;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  /**
   * 设置指定消息的元数据和签名，并发布更新事件。
   * @param messageId 目标消息标识。
   * @param metadataJson 元数据 JSON 字符串。
   * @param signature 推理来源签名。
   * @returns 更新后的推理记录副本。
   */
  setMetadata(messageId: string, metadataJson: string, signature: string): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.metadataJson = metadataJson;
    record.signature = signature;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  /**
   * 设置指定消息的推理内容在界面中的可见性，并发布更新事件。
   * @param messageId 目标消息标识。
   * @param visible 是否显示对应 UI。
   * @returns 更新后的推理记录副本。
   */
  setVisibility(messageId: string, visible: boolean): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.visible = visible;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  /**
   * 设置指定消息的推理内容是否包含在对话提示词中，并发布更新事件。
   * @param messageId 目标消息标识。
   * @param includeInPrompt 是否包含在提示词中。
   * @returns 更新后的推理记录副本。
   */
  setPromptPolicy(messageId: string, includeInPrompt: boolean): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.includeInPrompt = includeInPrompt;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  /**
   * 返回指定消息的推理快照文本（深拷贝），避免外部修改内部状态。
   * @param messageId 目标消息标识。
   * @returns 推理内容快照字符串。
   */
  copyReasoning(messageId: string): string {
    return this.getReasoning(messageId).snapshot;
  }

  /**
   * 若推理内容标记为包含在提示词中且非空，则格式化为 XML 标签包裹的字符串。
   * @param messageId 目标消息标识。
   * @returns 格式化的提示词片段；若无需包含则返回空字符串。
   */
  formatForPrompt(messageId: string): string {
    const record = this.getReasoning(messageId);
    if (!record.includeInPrompt || record.snapshot.length === 0) {
      return '';
    }
    return `<reasoning>\n${record.snapshot}\n</reasoning>`;
  }

  /**
   * 获取指定消息的推理记录（内部确保记录存在，不存在时自动创建）。
   * @param messageId 目标消息标识。
   * @returns 推理记录副本。
   */
  getReasoning(messageId: string): ReasoningRecord {
    return this.copyRecord(this.ensureRecord(messageId));
  }

  /**
   * 返回所有推理记录的深拷贝列表，调用方修改返回值不会改变内部状态。
   * @returns 推理记录列表。
   */
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

  /**
   * 发布推理记录更新事件（reasoning.updated 和 message.reasoning.updated），通知各订阅方。
   * @param record 更新后的推理记录（内部会先创建副本再发布）。
   */
  private publishUpdated(record: ReasoningRecord): void {
    const payload: ReasoningUpdatedPayload = {
      reasoning: this.copyRecord(record),
    };
    this.events.publish<ReasoningUpdatedPayload>('reasoning.updated', payload);
    this.events.publish<ReasoningUpdatedPayload>('message.reasoning.updated', payload);
  }

  /**
   * 深拷贝一条推理记录，返回新对象防止外部修改内部状态。
   * @param record 源记录。
   * @returns 新创建的副本。
   */
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
