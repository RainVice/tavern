import { MessageRuntime } from '../chats/MessageRuntime';
import { EventBus } from '../runtime/EventBus';
import type {
  StreamAbortPayload,
  StreamCompletePayload,
  StreamDeltaPayload,
  StreamSession,
  StreamStartParams,
  StreamStartPayload,
} from './StreamingModels';

/**
 * 提供流式生成相关的无 UI 运行时能力，负责流式会话的创建、增量追加、完成和中止管理，以及通过事件总线发布对应的状态变更事件。
 */
export class StreamingRuntime {
  /**
   * 事件总线实例，用于发布流式会话状态变更事件。
   */
  private events: EventBus;
  /**
   * 按 sessionId 索引的流式会话 Map，由当前运行时内部维护。
   */
  private sessions: Map<string, StreamSession> = new Map<string, StreamSession>();
  /**
   * 自增 ID 计数器，用于生成流式会话标识。
   */
  private nextId: number = 1;
  /**
   * MessageRuntime 实例引用，用于在流式生成过程中持久化消息快照。
   */
  private messageRuntime: MessageRuntime | null = null;

  /**
   * 构建流式运行时实例。
   * @param events 注入的事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 绑定 MessageRuntime 实例，使流式运行时能够在生成过程中将增量内容持久化到消息存储。
   */
  attachMessageRuntime(messageRuntime: MessageRuntime): void {
    this.messageRuntime = messageRuntime;
  }

  /**
   * 启动流式生成，创建会话记录并发布 stream.started 事件。
   * @param params 流式启动参数，包含 taskId / chatId / messageId。
   * @returns 新创建的流式会话副本。
   */
  startStream(params: StreamStartParams): StreamSession {
    const now = Date.now();
    const session: StreamSession = {
      id: `stream-${this.nextId}`,
      taskId: params.taskId,
      chatId: params.chatId,
      messageId: params.messageId,
      status: 'running',
      snapshot: '',
      reasoningSnapshot: '',
      abortReason: '',
      createdAt: now,
      updatedAt: now,
    };
    this.nextId += 1;
    this.sessions.set(session.id, this.copySession(session));
    const payload: StreamStartPayload = {
      session: this.copySession(session),
    };
    this.events.publish<StreamStartPayload>('stream.started', payload);
    return this.copySession(session);
  }

  /**
   * 向指定的流式会话追加增量文本，根据 reasoning 参数决定追加到推理快照还是内容快照，并发布 stream.delta 事件。
   * @param sessionId 目标流式会话标识。
   * @param delta 本次追加的增量文本。
   * @param reasoning 是否为推理过程增量。
   * @returns 更新后的流式会话副本。
   */
  async applyDelta(sessionId: string, delta: string, reasoning: boolean): Promise<StreamSession> {
    const session = this.requireSession(sessionId);
    if (session.status !== 'running') {
      return this.copySession(session);
    }

    if (reasoning) {
      session.reasoningSnapshot += delta;
    } else {
      session.snapshot += delta;
      await this.persistSnapshot(session);
    }
    session.updatedAt = Date.now();
    const payload: StreamDeltaPayload = {
      sessionId: session.id,
      taskId: session.taskId,
      chatId: session.chatId,
      messageId: session.messageId,
      delta: delta,
      snapshot: session.snapshot,
      reasoning: reasoning,
      reasoningSnapshot: session.reasoningSnapshot,
    };
    this.events.publish<StreamDeltaPayload>('stream.delta', payload);
    return this.copySession(session);
  }

  /**
   * 标记流式会话为 completed 状态，发布 stream.completed 事件。
   * @param sessionId 目标流式会话标识。
   * @returns 更新后的流式会话副本。
   */
  completeStream(sessionId: string): StreamSession {
    const session = this.requireSession(sessionId);
    if (session.status === 'running') {
      session.status = 'completed';
      session.updatedAt = Date.now();
    }
    const payload: StreamCompletePayload = {
      session: this.copySession(session),
    };
    this.events.publish<StreamCompletePayload>('stream.completed', payload);
    return this.copySession(session);
  }

  /**
   * 中止指定的流式会话，设置状态为 aborted 并记录原因，发布 stream.aborted 事件。
   * @param sessionId 目标流式会话标识。
   * @param reason 中止原因描述。
   * @returns 更新后的流式会话副本。
   */
  abortStream(sessionId: string, reason: string): StreamSession {
    const session = this.requireSession(sessionId);
    if (session.status === 'running') {
      session.status = 'aborted';
      session.abortReason = reason;
      session.updatedAt = Date.now();
    }
    const payload: StreamAbortPayload = {
      session: this.copySession(session),
    };
    this.events.publish<StreamAbortPayload>('stream.aborted', payload);
    return this.copySession(session);
  }

  /**
   * 根据会话标识读取已有流式会话，会话不存在时抛出异常。
   * @param sessionId 目标流式会话标识。
   * @returns 流式会话的副本。
   */
  getSession(sessionId: string): StreamSession {
    return this.copySession(this.requireSession(sessionId));
  }
  private async persistSnapshot(session: StreamSession): Promise<void> {
    if (this.messageRuntime === null) {
      return;
    }
    await this.messageRuntime.updateMessage(session.messageId, {
      text: session.snapshot,
      isSystem: false,
    });
  }

  /**
   * 读取必须存在的Session 值，缺失时抛出错误。
   * @param sessionId 目标流式会话标识。
   */
  private requireSession(sessionId: string): StreamSession {
    const session = this.sessions.get(sessionId);
    if (session === undefined) {
      throw new Error(`Stream session not found: ${sessionId}`);
    }
    return session;
  }

  /**
   * 复制Session 值，避免外部修改内部状态。
   */
  private copySession(session: StreamSession): StreamSession {
    return {
      id: session.id,
      taskId: session.taskId,
      chatId: session.chatId,
      messageId: session.messageId,
      status: session.status,
      snapshot: session.snapshot,
      reasoningSnapshot: session.reasoningSnapshot,
      abortReason: session.abortReason,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    };
  }
}
