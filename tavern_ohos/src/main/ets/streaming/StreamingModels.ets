/**
 * 描述调用流式生成能力时需要传入的参数。
 */
export interface StreamStartParams {
  /**
   * 任务标识，用于将流式会话关联到当前正在执行的任务（如文本生成任务），方便在任务系统中追踪状态。
   */
  taskId: string;
  /**
   * 聊天标识，用于将流式会话绑定到具体的聊天上下文，确保增量内容归属正确会话。
   */
  chatId: string;
  /**
   * 消息标识，用于将流式生成的回复文本关联到目标消息记录，供后续快照持久化使用。
   */
  messageId: string;
}

/**
 * 描述流式生成模块在运行时交换的数据结构。
 * 在整个流式生成生命周期（开始 -> 增量 -> 完成/中止）中，用于在各组件间传递会话状态。
 */
export interface StreamSession {
  /**
   * 流式会话唯一标识（如 "stream-1"），由 StreamingRuntime 在 startStream 时自动生成，用于后续增量/完成/中止操作的索引。
   */
  id: string;
  /**
   * 所属任务的标识，在 startStream 时从 params 中传入，用于关联任务系统中的追踪记录。
   */
  taskId: string;
  /**
   * 所属聊天的标识，在 startStream 时从 params 中传入，用于确定流式内容归属的聊天会话。
   */
  chatId: string;
  /**
   * 当前正在生成回复的消息标识，在 startStream 时从 params 中传入，用于将流式增量持久化到对应消息的文本字段。
   */
  messageId: string;
  /**
   * 当前会话状态：running / completed / aborted，由 startStream、completeStream、abortStream 方法驱动状态流转。
   */
  status: string;
  /**
   * 已累积的文本内容快照，在 applyDelta 时逐次追加，供宿主 UI 实时展示和最终写入消息文本。
   */
  snapshot: string;
  /**
   * 已累积的推理过程文本快照，在 applyDelta(reasoning=true) 时逐次追加，用于展示模型推理过程（如 chain-of-thought）。
   */
  reasoningSnapshot: string;
  /**
   * 会话中止时的原因描述，由 abortStream 的参数传入，供日志排查或 UI 展示中止原因。
   */
  abortReason: string;
  /**
   * 会话创建时间戳（毫秒），在 startStream 时记录，用于衡量流式生成的总耗时。
   */
  createdAt: number;
  /**
   * 会话最近更新时间戳（毫秒），在 applyDelta、completeStream、abortStream 时更新，用于追踪会话活性。
   */
  updatedAt: number;
}

/**
 * 描述流式生成开始事件发布时携带的数据结构。
 * StreamingRuntime 调用 startStream 后发布 stream.started 事件，通知宿主 UI 或其他 Runtime 生成已启动。
 */
export interface StreamStartPayload {
  /**
   * 流式会话的状态快照，包含会话 ID、任务/聊天/消息标识及初始状态信息。
   */
  session: StreamSession;
}

/**
 * 描述流式生成增量事件发布时携带的数据结构。
 * StreamingRuntime 调用 applyDelta 后发布 stream.delta 事件，通知宿主 UI 实时追加文本到显示区域。
 */
export interface StreamDeltaPayload {
  /**
   * 增量数据所属的流式会话标识，用于宿主 UI 定位需要更新文本的目标会话。
   */
  sessionId: string;
  /**
   * 增量数据所属的任务标识，用于将增量结果关联回任务系统。
   */
  taskId: string;
  /**
   * 增量数据所属的聊天标识，用于确定更新所属的聊天上下文。
   */
  chatId: string;
  /**
   * 增量数据所属的消息标识，用于将增量内容持久化到对应的消息记录。
   */
  messageId: string;
  /**
   * 本次增量追加的文本片段，由宿主 UI 拼接后实时展示给用户。
   */
  delta: string;
  /**
   * 追加后的累积文本快照，供宿主 UI 直接替换当前显示内容（避免逐段拼接）。
   */
  snapshot: string;
  /**
   * 是否为推理过程（reasoning）增量，宿主 UI 据此决定是否用特殊样式展示推理文本。
   */
  reasoning: boolean;
  /**
   * 追加后的推理文本快照，供宿主 UI 展示模型推理过程。
   */
  reasoningSnapshot: string;
}

/**
 * 描述流式生成完成事件发布时携带的数据结构。
 * StreamingRuntime 调用 completeStream 后发布 stream.completed 事件，通知宿主 UI 流式生成已结束。
 */
export interface StreamCompletePayload {
  /**
   * 完成时的流式会话快照，包含最终累积的完整文本内容、推理文本及状态信息。
   */
  session: StreamSession;
}

/**
 * 描述流式生成中止事件发布时携带的数据结构。
 * StreamingRuntime 调用 abortStream 后发布 stream.aborted 事件，通知宿主 UI 生成被用户或系统中止。
 */
export interface StreamAbortPayload {
  /**
   * 中止时的流式会话快照，包含中止前已累积的文本内容及中止原因描述。
   */
  session: StreamSession;
}
