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
 * 提供推理内容相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ReasoningRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 记录副本列表，由当前实例内部维护。
   */
  private records: Map<string, ReasoningRecord> = new Map<string, ReasoningRecord>();
  /**
   * stream Subscription 值，由当前实例内部维护。
   */
  private streamSubscription: EventSubscription | null = null;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 启动Streaming Accumulator 值流程，并记录初始任务或会话状态。
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
   * 执行 stopStreamingAccumulator 的内部处理步骤，供当前模块复用。
   */
  stopStreamingAccumulator(): void {
    if (this.streamSubscription === null) {
      return;
    }
    this.streamSubscription.unsubscribe();
    this.streamSubscription = null;
  }

  /**
   * 执行 applyDelta 的内部处理步骤，供当前模块复用。
   * @param messageId 目标消息标识。
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
   * 执行 editReasoning 的内部处理步骤，供当前模块复用。
   * @param messageId 目标消息标识。
   */
  editReasoning(messageId: string, snapshot: string): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.snapshot = snapshot;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  /**
   * 设置元数据，用于切换运行时状态或保存配置。
   * @param messageId 目标消息标识。
   * @param metadataJson metadata JSON 字符串。
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
   * 设置可见性，用于切换运行时状态或保存配置。
   * @param messageId 目标消息标识。
   * @param visible 是否显示对应 UI。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  setVisibility(messageId: string, visible: boolean): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.visible = visible;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  /**
   * 设置提示词Policy，用于切换运行时状态或保存配置。
   * @param messageId 目标消息标识。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  setPromptPolicy(messageId: string, includeInPrompt: boolean): ReasoningRecord {
    const record = this.ensureRecord(messageId);
    record.includeInPrompt = includeInPrompt;
    record.updatedAt = Date.now();
    this.publishUpdated(record);
    return this.copyRecord(record);
  }

  /**
   * 复制Reasoning 值，避免外部修改内部状态。
   * @param messageId 目标消息标识。
   */
  copyReasoning(messageId: string): string {
    return this.getReasoning(messageId).snapshot;
  }

  /**
   * 生成提示词输出，供请求发送、导出或界面展示使用。
   * @param messageId 目标消息标识。
   */
  formatForPrompt(messageId: string): string {
    const record = this.getReasoning(messageId);
    if (!record.includeInPrompt || record.snapshot.length === 0) {
      return '';
    }
    return `<reasoning>\n${record.snapshot}\n</reasoning>`;
  }

  /**
   * 读取指定Reasoning，不存在时抛出错误。
   * @param messageId 目标消息标识。
   * @returns 更新或读取后的记录副本。
   */
  getReasoning(messageId: string): ReasoningRecord {
    return this.copyRecord(this.ensureRecord(messageId));
  }

  /**
   * 读取Reasoning列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 发布推理内容事件，把状态变化通知给宿主或其他 Runtime。
   * @param record 记录副本。
   */
  private publishUpdated(record: ReasoningRecord): void {
    const payload: ReasoningUpdatedPayload = {
      reasoning: this.copyRecord(record),
    };
    this.events.publish<ReasoningUpdatedPayload>('reasoning.updated', payload);
    this.events.publish<ReasoningUpdatedPayload>('message.reasoning.updated', payload);
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
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
