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
   * 事件总线，用于发布推理增量、更新事件。
   */
  private events: EventBus;
  /**
   * 推理记录字典，键为消息标识，值为推理记录——每条 LLM 回复消息对应一条推理记录。
   */
  private records: Map<string, ReasoningRecord> = new Map<string, ReasoningRecord>();
  /**
   * 当前流式订阅对象，用于在停止时取消订阅。
   */
  private streamSubscription: EventSubscription | null = null;

  /**
   * 初始化当前运行时实例，清空推理记录字典。
   * @param events 事件总线，用于订阅 stream.delta 事件和发布 reasoning.* 系列事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 开始监听流式 delta 事件，自动累积推理内容到对应消息的推理记录中。
   * 在流式请求启动前由外部模块调用，开启后每个 stream.delta 事件中的推理内容会自动追加到该消息的推理快照。
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
   * 停止监听流式 delta 事件，并清理订阅引用。在流式请求结束或取消时由外部模块调用。
   */
  stopStreamingAccumulator(): void {
    if (this.streamSubscription === null) {
      return;
    }
    this.streamSubscription.unsubscribe();
    this.streamSubscription = null;
  }

  /**
   * 将流式 delta 内容追加到指定消息的推理记录快照中，并发布 delta 更新事件。
   * 被流式事件订阅回调自动调用，也可由外部模块手动追加推理内容。
   * @param messageId 目标消息标识，与 stream.delta 事件中的 messageId 对应。
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
   * 编辑指定消息的推理内容快照，替换为新的内容并发布更新事件。由 UI 编辑操作触发，用于手动修改推理内容。
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
   * 设置指定消息的推理元数据和签名。在推理完成后由外部模块调用，将模型返回的元数据写入记录。
   * @param messageId 目标消息标识。
   * @param metadataJson 关联的元数据 JSON 字符串。
   * @param signature 推理签名，用于验证或标识推理来源。
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
   * 设置推理内容在 UI 中的可见状态。由 UI 切换折叠/展开时调用，控制推理内容的显示与隐藏。
   * @param messageId 目标消息标识。
   * @param visible 是否在 UI 中显示推理内容。
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
   * 设置是否将推理内容包含在发送给 LLM 的提示词中。用于多轮对话中决定是否传递前一轮的推理链给下一轮请求。
   * @param messageId 目标消息标识。
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
   * 获取指定消息的推理快照文本副本。在需要查看或处理推理内容的场景下调用。
   * @param messageId 目标消息标识。
   */
  copyReasoning(messageId: string): string {
    return this.getReasoning(messageId).snapshot;
  }

  /**
   * 将指定消息的推理内容格式化为 <reasoning> 标签包裹的文本，用于拼接到提示词中。
   * 在组装发送给 LLM 的消息时调用，以决定是否将推理链传递到下一轮对话。
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
   * 按消息标识查询推理记录的深拷贝。由外部模块（如 UI 渲染或消息组装流程）获取推理内容时调用。
   * @param messageId 目标消息标识。
   * @returns 推理记录副本。
   */
  getReasoning(messageId: string): ReasoningRecord {
    return this.copyRecord(this.ensureRecord(messageId));
  }

  /**
   * 返回所有推理记录的深拷贝列表。用于批量操作或数据导出时的枚举。
   * @returns 所有推理记录副本的数组。
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
   * 发布推理内容更新事件到事件总线。
   * @param record 待发布的推理记录（将被深拷贝后发布）。
   */
  private publishUpdated(record: ReasoningRecord): void {
    const payload: ReasoningUpdatedPayload = {
      reasoning: this.copyRecord(record),
    };
    this.events.publish<ReasoningUpdatedPayload>('reasoning.updated', payload);
    this.events.publish<ReasoningUpdatedPayload>('message.reasoning.updated', payload);
  }

  /**
   * 深拷贝推理记录对象，防止外部修改内部存储的原始记录。
   * @param record 待拷贝的推理记录。
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
