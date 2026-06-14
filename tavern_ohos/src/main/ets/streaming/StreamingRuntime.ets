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
 * 在 AI 模型回复生成过程中，接收逐段文本增量并实时分发给订阅者（如宿主 UI 的消息展示区域）。
 */
export class StreamingRuntime {
  /**
   * 事件总线实例，用于发布流式事件（stream.started、stream.delta、stream.completed、stream.aborted）。
   */
  private events: EventBus;
  /**
   * 按会话 ID 保存的活跃流式会话映射表，在 startStream 时存入，completeStream / abortStream 后可查询。
   */
  private sessions: Map<string, StreamSession> = new Map<string, StreamSession>();
  /**
   * 自增 ID 计数器，用于生成流式会话 ID，确保每个会话标识唯一。
   */
  private nextId: number = 1;
  /**
   * 消息运行时引用，用于在流式过程中自动持久化快照到消息内容（通过 attachMessageRuntime 注入）。
   */
  private messageRuntime: MessageRuntime | null = null;

  /**
   * 初始化 StreamingRuntime 实例。
   * @param events 事件总线实例，由宿主在初始化时注入，用于跨模块事件通信。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 关联 MessageRuntime 实例，用于在流式增量过程中自动更新消息文本。
   * 在需要将流式生成结果自动持久化到消息记录时调用（如用户界面直接展示的消息文本）。
   */
  attachMessageRuntime(messageRuntime: MessageRuntime): void {
    this.messageRuntime = messageRuntime;
  }

  /**
   * 启动一个新的流式生成会话，记录初始状态并发布 stream.started 事件。
   * 在 AI 模型开始生成回复时由 ProviderRuntime 调用，通知宿主 UI 显示流式加载状态。
   * @param params 流式启动参数（任务/聊天/消息标识），由调用方传入，用于关联流式会话与业务上下文。
   * @returns 新建的流式会话快照，包含会话 ID 和初始状态。
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
   * 向指定会话追加文本增量（普通内容或推理过程内容），自动持久化快照并发布 stream.delta 事件。
   * 在流式接收过程中由 ProviderRuntime 的 SSE 解析循环逐段调用，将收到的每块文本增量分发给宿主 UI。
   * @param sessionId 目标流式会话标识，用于定位 startStream 时创建的会话记录。
   * @param delta 本次追加的文本增量，来自 AI 模型的即时输出片段。
   * @param reasoning 是否为推理过程增量，决定增量内容追加到 snapshot 还是 reasoningSnapshot。
   * @returns 更新后的流式会话快照，包含追加后的累积文本。
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
   * 标记指定会话为已完成，发布 stream.completed 事件。
   * 在 AI 模型结束回复时由 ProviderRuntime 调用，通知宿主 UI 流式生成已结束。
   * @param sessionId 目标流式会话标识，用于定位要标记完成的会话。
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
   * 中止指定会话，记录中止原因，发布 stream.aborted 事件。
   * 在用户手动取消、超时或网络错误时由调用方（如 ProviderRuntime 或 UI 层）调用。
   * @param sessionId 目标流式会话标识。
   * @param reason 中止原因的描述，用于日志记录和 UI 提示。
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
   * 获取指定会话的副本；会话不存在时抛出错误。
   * 在宿主 UI 或其它 Runtime 需要查询流式会话当前状态时调用。
   * @param sessionId 目标流式会话标识。
   * @returns 流式会话快照的副本。
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
   * 确保指定会话存在，缺失时抛出错误。
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
   * 深度复制 StreamSession，防止外部代码修改内部状态。
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
