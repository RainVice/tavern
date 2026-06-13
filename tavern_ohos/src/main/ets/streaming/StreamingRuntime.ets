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

export class StreamingRuntime {
  private events: EventBus;
  private sessions: Map<string, StreamSession> = new Map<string, StreamSession>();
  private nextId: number = 1;
  private messageRuntime: MessageRuntime | null = null;

  constructor(events: EventBus) {
    this.events = events;
  }

  attachMessageRuntime(messageRuntime: MessageRuntime): void {
    this.messageRuntime = messageRuntime;
  }

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

  private requireSession(sessionId: string): StreamSession {
    const session = this.sessions.get(sessionId);
    if (session === undefined) {
      throw new Error(`Stream session not found: ${sessionId}`);
    }
    return session;
  }

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
