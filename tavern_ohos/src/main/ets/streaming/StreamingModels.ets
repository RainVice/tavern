export interface StreamStartParams {
  taskId: string;
  chatId: string;
  messageId: string;
}

export interface StreamSession {
  id: string;
  taskId: string;
  chatId: string;
  messageId: string;
  status: string;
  snapshot: string;
  reasoningSnapshot: string;
  abortReason: string;
  createdAt: number;
  updatedAt: number;
}

export interface StreamStartPayload {
  session: StreamSession;
}

export interface StreamDeltaPayload {
  sessionId: string;
  taskId: string;
  chatId: string;
  messageId: string;
  delta: string;
  snapshot: string;
  reasoning: boolean;
  reasoningSnapshot: string;
}

export interface StreamCompletePayload {
  session: StreamSession;
}

export interface StreamAbortPayload {
  session: StreamSession;
}
