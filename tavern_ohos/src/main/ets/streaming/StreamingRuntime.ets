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
 * 提供流式生成相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class StreamingRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * sessions 列表，由当前实例内部维护。
   */
  private sessions: Map<string, StreamSession> = new Map<string, StreamSession>();
  /**
   * next 标识。
   */
  private nextId: number = 1;
  /**
   * messageRuntime 运行时。
   */
  private messageRuntime: MessageRuntime | null = null;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 执行 attachMessageRuntime 的内部处理步骤，供当前模块复用。

   */
  attachMessageRuntime(messageRuntime: MessageRuntime): void {
    this.messageRuntime = messageRuntime;
  }

  /**
   * 启动Stream 值流程，并记录初始任务或会话状态。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 执行 applyDelta 的内部处理步骤，供当前模块复用。
   * @param sessionId 目标流式会话标识。


   * @returns 条件命中时返回 true，否则返回 false。
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
   * 标记Stream 值完成，并写入最终结果。
   * @param sessionId 目标流式会话标识。
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
   * 执行 abortStream 的内部处理步骤，供当前模块复用。
   * @param sessionId 目标流式会话标识。
   * @param reason 失败、中止或恢复操作的原因说明。
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
   * 读取指定会话，不存在时抛出错误。
   * @param sessionId 目标流式会话标识。
   * @returns 更新或读取后的记录副本。
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
