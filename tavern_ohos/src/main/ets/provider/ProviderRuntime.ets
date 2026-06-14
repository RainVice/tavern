import { EventBus } from '../runtime/EventBus';
import { StreamingRuntime } from '../streaming/StreamingRuntime';
import { OpenAICompatibleNormalizer } from './OpenAICompatibleNormalizer';
import type {
  ProviderCapability,
  ProviderGenerationPayload,
  ProviderNormalizedChunk,
  ProviderSSEEvent,
  ProviderStreamHandle,
  ProviderStreamSink,
  ProviderStreamStartParams,
  ProviderStreamTask,
  ProviderTextCompletionBody,
  ProviderTextCompletionBuildParams,
  ProviderTextCompletionOptions,
  ProviderTextCompletionRequest,
} from './ProviderModels';
import { ProviderSSEParser } from './ProviderSSEParser';

/**
 * OpenAI 兼容流式请求的 Sink 实现，将原始数据块通过 SSE 解析后转发给 ProviderRuntime。
 */
class OpenAIProviderStreamSink implements ProviderStreamSink {
  /** ProviderRuntime 实例，用于处理流式数据块和任务状态更新。 */
  private runtime: ProviderRuntime;
  /** 当前流式任务标识。 */
  private taskId: string;
  /** SSE 解析器，用于将原始数据块解析为 SSE 事件。 */
  private parser: ProviderSSEParser;

  /**
   * 初始化 Sink，关联运行时、任务和解析器。
   * @param runtime ProviderRuntime 实例，负责状态管理和事件发布。
   * @param taskId 当前流式任务的唯一标识。
   * @param parser 用于解析 SSE 事件的解析器实例。
   */
  constructor(runtime: ProviderRuntime, taskId: string, parser: ProviderSSEParser) {
    this.runtime = runtime;
    this.taskId = taskId;
    this.parser = parser;
  }

  /**
   * 接收到原始数据块后，推入 SSE 解析器并将解析出的事件提交给运行时处理。
   */
  async onChunk(chunk: string): Promise<void> {
    await this.runtime.acceptOpenAICompatibleChunk(this.taskId, this.parser, chunk);
  }

  /**
   * 流式请求发生错误时，通知运行时将该任务标记为失败。
   * @param message 错误描述信息。
   */
  async onError(message: string): Promise<void> {
    await this.runtime.failStream(this.taskId, message);
  }

  /**
   * 流式请求正常结束时，刷新 SSE 解析器中的剩余数据并完成流处理。
   */
  async onDone(): Promise<void> {
    await this.runtime.finishOpenAICompatibleStream(this.taskId, this.parser);
  }
}

/**
 * 提供 Provider 流式请求的无 UI 运行时能力，负责任务生命周期管理、数据读写和事件发布。
 */
export class ProviderRuntime {
  /** 事件总线，用于广播生成任务的状态变化。 */
  private events: EventBus;
  /** StreamingRuntime 实例，管理底层流式数据写入和会话生命周期。 */
  private streaming: StreamingRuntime;
  /** OpenAI 兼容格式的响应归一化器，将原始 JSON 转换为统一的数据块结构。 */
  private normalizer: OpenAICompatibleNormalizer = new OpenAICompatibleNormalizer();
  /** 所有活跃的流式任务，以 taskId 为键。 */
  private tasks: Map<string, ProviderStreamTask> = new Map<string, ProviderStreamTask>();
  /** 所有活跃流式请求的句柄，以 taskId 为键，用于关闭/中止连接。 */
  private handles: Map<string, ProviderStreamHandle> = new Map<string, ProviderStreamHandle>();

  /**
   * 注入运行时依赖并初始化实例状态。
   * @param events 事件总线实例，用于发布生成任务事件。
   * @param streaming StreamingRuntime 实例，管理流式数据写入。
   */
  constructor(events: EventBus, streaming: StreamingRuntime) {
    this.events = events;
    this.streaming = streaming;
  }

  /**
   * 启动一个 OpenAI 兼容的流式生成请求，创建任务记录并连接数据源。
   * @param params 启动流式请求所需的参数，包括请求体、数据源和标识信息。
   * @returns 创建后的流式任务状态快照。
   */
  async startOpenAICompatibleStream(params: ProviderStreamStartParams): Promise<ProviderStreamTask> {
    const now = Date.now();
    const session = this.streaming.startStream({
      taskId: params.taskId,
      chatId: params.chatId,
      messageId: params.messageId,
    });
    const task: ProviderStreamTask = {
      taskId: params.taskId,
      sessionId: session.id,
      chatId: params.chatId,
      messageId: params.messageId,
      provider: params.request.provider,
      model: params.request.model,
      status: 'running',
      error: '',
      finishReason: '',
      createdAt: now,
      updatedAt: now,
    };
    this.tasks.set(task.taskId, this.copyTask(task));
    this.publish('generation.started', task);
    const parser = new ProviderSSEParser();
    const sink = new OpenAIProviderStreamSink(this, task.taskId, parser);
    try {
      const handle = await params.source.start(params.request, sink);
      this.handles.set(task.taskId, handle);
    } catch (error) {
      await this.failStream(task.taskId, String(error));
    }
    return this.getTask(task.taskId);
  }

  /**
   * 中止指定的 Provider 流式任务，关闭网络连接并更新任务状态。
   * @param taskId 要中止的任务标识。
   * @param reason 中止原因说明。
   * @returns 中止后的任务状态快照。
   */
  abortProviderStream(taskId: string, reason: string): ProviderStreamTask {
    const handle = this.handles.get(taskId);
    if (handle !== undefined) {
      handle.close();
    }
    const task = this.requireTask(taskId);
    if (task.status === 'running') {
      this.streaming.abortStream(task.sessionId, reason);
      task.status = 'aborted';
      task.error = reason;
      task.updatedAt = Date.now();
      this.publish('generation.failed', task);
    }
    return this.copyTask(task);
  }

  /**
   * 获取指定任务的快照副本。
   * @param taskId 目标任务标识。
   * @returns 任务状态的只读副本。
   */
  getTask(taskId: string): ProviderStreamTask {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 为指定模型构建 OpenAI 兼容的能力声明。
   * @param model 模型名称。
   * @param maxContext 模型的最大上下文窗口大小。
   * @param supportsReasoning 该模型是否支持推理过程输出。
   * @returns 该模型的能力描述对象。
   */
  openAICompatibleCapability(model: string, maxContext: number, supportsReasoning: boolean): ProviderCapability {
    return {
      provider: 'openai-compatible',
      model: model,
      supportsStreaming: true,
      supportsSystemPrompt: true,
      supportsTools: false,
      supportsReasoning: supportsReasoning,
      supportsVisionInput: false,
      supportsImageOutput: false,
      supportsJsonSchema: false,
      supportsLogprobs: false,
      supportsSeed: true,
      supportsStopStrings: true,
      supportsAssistantPrefill: false,
      supportsTextCompletion: false,
      supportsChatCompletion: true,
      maxContext: maxContext,
      tokenizer: 'provider',
    };
  }

  /**
   * 根据构建参数生成文本补全请求。根据 apiType 区分 Ollama 和其他后端，分别构建不同的请求格式。
   * @param params 文本补全的构建参数。
   * @returns 构建好的文本补全请求，包含 API 路由和请求体。
   */
  buildTextCompletionRequest(params: ProviderTextCompletionBuildParams): ProviderTextCompletionRequest {
    const apiType = params.apiType.toLowerCase();
    if (apiType === 'ollama') {
      return this.buildOllamaTextCompletionRequest(apiType, params);
    }
    return this.buildOpenAITextCompletionRequest(apiType, params);
  }

  /**
   * 接收并处理一个 OpenAI 兼容的数据块：推入 SSE 解析器并消费解析出的事件。
   * @param taskId 当前流式任务标识。
   * @param parser 该任务关联的 SSE 解析器。
   * @param chunk 原始数据块字符串。
   */
  async acceptOpenAICompatibleChunk(taskId: string, parser: ProviderSSEParser, chunk: string): Promise<void> {
    // 将数据块推入 SSE 解析器，获取解析后的事件列表
    const events = parser.push(chunk);
    await this.consumeEvents(taskId, events);
  }

  /**
   * 结束流式处理：刷新 SSE 解析器中的残留数据，并标记流任务完成。
   * @param taskId 当前流式任务标识。
   * @param parser 该任务关联的 SSE 解析器。
   */
  async finishOpenAICompatibleStream(taskId: string, parser: ProviderSSEParser): Promise<void> {
    // 刷新 SSE 解析器中剩余的数据，获取最后一批事件
    const events = parser.flush();
    await this.consumeEvents(taskId, events);
    this.completeStream(taskId);
  }

  /**
   * 将流式任务标记为失败，保存错误信息并发布失败事件。
   * @param taskId 目标任务标识。
   * @param message 错误描述信息。
   */
  async failStream(taskId: string, message: string): Promise<void> {
    const task = this.requireTask(taskId);
    if (task.status !== 'running') {
      return;
    }
    this.streaming.abortStream(task.sessionId, message);
    task.status = 'failed';
    task.error = message;
    task.updatedAt = Date.now();
    this.publish('generation.failed', task);
  }

  /**
   * 依次消费解析后的 SSE 事件列表。
   * @param taskId 当前任务标识。
   * @param events SSE 事件列表。
   */
  private async consumeEvents(taskId: string, events: Array<ProviderSSEEvent>): Promise<void> {
    for (let index = 0; index < events.length; index += 1) {
      await this.consumeEvent(taskId, events[index]);
    }
  }

  /**
   * 消费单个 SSE 事件：处理终止标记、归一化数据块并写入流会话。
   * @param taskId 当前任务标识。
   * @param event 单个 SSE 事件。
   */
  private async consumeEvent(taskId: string, event: ProviderSSEEvent): Promise<void> {
    if (event.data === '[DONE]') {
      this.completeStream(taskId);
      return;
    }
    let normalized: ProviderNormalizedChunk;
    try {
      normalized = this.normalizer.normalizeChatChunk(event.data);
    } catch (error) {
      await this.failStream(taskId, String(error));
      return;
    }
    const task = this.requireTask(taskId);
    if (task.status !== 'running') {
      return;
    }
    // 将推理过程增量写入流会话
    if (normalized.reasoningDelta.length > 0) {
      await this.streaming.applyDelta(task.sessionId, normalized.reasoningDelta, true);
    }
    // 将文本增量写入流会话
    if (normalized.textDelta.length > 0) {
      await this.streaming.applyDelta(task.sessionId, normalized.textDelta, false);
    }
    // 记录结束原因
    if (normalized.finishReason.length > 0) {
      task.finishReason = normalized.finishReason;
      task.updatedAt = Date.now();
    }
  }

  /**
   * 将流式任务标记为完成，通知流会话结束并发布完成事件。
   * @param taskId 目标任务标识。
   */
  private completeStream(taskId: string): ProviderStreamTask {
    const task = this.requireTask(taskId);
    if (task.status !== 'running') {
      return task;
    }
    this.streaming.completeStream(task.sessionId);
    task.status = 'completed';
    task.updatedAt = Date.now();
    this.publish('generation.completed', task);
    return task;
  }

  /**
   * 按 taskId 查找任务，不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 内部存储的任务对象引用。
   */
  private requireTask(taskId: string): ProviderStreamTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`Provider stream task not found: ${taskId}`);
    }
    return task;
  }

  /**
   * 通过事件总线发布生成任务相关事件，传递任务状态的快照副本。
   * @param eventName 事件名称，如 "generation.started"、"generation.failed" 等。
   * @param task 当前任务对象。
   */
  private publish(eventName: string, task: ProviderStreamTask): void {
    const payload: ProviderGenerationPayload = {
      task: this.copyTask(task),
    };
    this.events.publish<ProviderGenerationPayload>(eventName, payload);
  }

  /**
   * 创建任务对象的浅拷贝，防止外部代码直接修改内部状态。
   */
  private copyTask(task: ProviderStreamTask): ProviderStreamTask {
    return {
      taskId: task.taskId,
      sessionId: task.sessionId,
      chatId: task.chatId,
      messageId: task.messageId,
      provider: task.provider,
      model: task.model,
      status: task.status,
      error: task.error,
      finishReason: task.finishReason,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }

  /**
   * 构建 OpenAI 兼容的文本补全请求，组装请求体中的采样参数。
   * @param apiType API 类型标识。
   * @param params 文本补全的构建参数。
   * @returns 构建好的文本补全请求。
   */
  private buildOpenAITextCompletionRequest(apiType: string, params: ProviderTextCompletionBuildParams): ProviderTextCompletionRequest {
    const body: ProviderTextCompletionBody = {
      model: params.model,
      prompt: params.prompt,
      temperature: params.temperature,
      max_tokens: params.maxTokens,
      stop: this.normalizeTextCompletionStops(apiType, params.stop),
      stream: params.stream,
    };
    this.applyOptionalSamplerFields(body, params);
    return {
      apiType: apiType,
      path: this.textCompletionPath(apiType),
      body: body,
    };
  }

  /**
   * 构建 Ollama 文本补全请求，Ollama 使用 options 子对象承载采样参数并默认启用 raw 模式。
   * @param apiType API 类型标识。
   * @param params 文本补全的构建参数。
   * @returns 构建好的 Ollama 文本补全请求。
   */
  private buildOllamaTextCompletionRequest(apiType: string, params: ProviderTextCompletionBuildParams): ProviderTextCompletionRequest {
    const stop = params.stop.slice();
    const options: ProviderTextCompletionOptions = {
      temperature: params.temperature,
      num_predict: params.maxTokens,
      stop: stop.slice(),
    };
    if (params.topP !== undefined) {
      options.top_p = params.topP;
    }
    if (params.presencePenalty !== undefined) {
      options.presence_penalty = params.presencePenalty;
    }
    if (params.frequencyPenalty !== undefined) {
      options.frequency_penalty = params.frequencyPenalty;
    }
    if (params.seed !== undefined) {
      options.seed = params.seed;
    }
    const body: ProviderTextCompletionBody = {
      model: params.model,
      prompt: params.prompt,
      temperature: params.temperature,
      stop: stop,
      stream: params.stream,
      raw: true,
      options: options,
    };
    return {
      apiType: apiType,
      path: '/api/generate',
      body: body,
    };
  }

  /**
   * 根据 API 类型返回文本补全的请求路径。
   * 不同后端（dreamgen、mancer、llamacpp、openrouter）使用不同的路径格式。
   */
  private textCompletionPath(apiType: string): string {
    if (apiType === 'dreamgen') {
      return '/api/openai/v1/completions';
    }
    if (apiType === 'mancer') {
      return '/oai/v1/completions';
    }
    if (apiType === 'llamacpp') {
      return '/completion';
    }
    if (apiType === 'openrouter') {
      return '/v1/chat/completions';
    }
    return '/v1/completions';
  }

  /**
   * 规范化文本补全的停止字符串列表。generic 类型的 API 限制最多 4 个停止词。
   * @param apiType API 类型标识。
   * @param stop 原始停止字符串列表。
   * @returns 规范化后的停止字符串列表副本。
   */
  private normalizeTextCompletionStops(apiType: string, stop: Array<string>): Array<string> {
    if (apiType !== 'generic') {
      return stop.slice();
    }
    const result = new Array<string>();
    const limit = Math.min(stop.length, 4);
    for (let index = 0; index < limit; index += 1) {
      result.push(stop[index]);
    }
    return result;
  }

  /**
   * 将可选的采样参数字段（topP、presencePenalty、frequencyPenalty、seed）写入请求体。
   * @param body 目标请求体，会被就地修改。
   * @param params 构建参数，从中读取可选字段。
   */
  private applyOptionalSamplerFields(body: ProviderTextCompletionBody, params: ProviderTextCompletionBuildParams): void {
    if (params.topP !== undefined) {
      body.top_p = params.topP;
    }
    if (params.presencePenalty !== undefined) {
      body.presence_penalty = params.presencePenalty;
    }
    if (params.frequencyPenalty !== undefined) {
      body.frequency_penalty = params.frequencyPenalty;
    }
    if (params.seed !== undefined) {
      body.seed = params.seed;
    }
  }
}
