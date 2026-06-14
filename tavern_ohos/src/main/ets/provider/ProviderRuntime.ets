import { EventBus } from '../runtime/EventBus';
import type { ConnectionApiType } from '../contracts/PublicContracts';
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
 * 封装Provider 请求相关状态和行为。
 */
class OpenAIProviderStreamSink implements ProviderStreamSink {
  /**
   * 运行时实例，由当前实例内部维护。
   */
  private runtime: ProviderRuntime;
  /**
   * 任务标识。
   */
  private taskId: string;
  /**
   * parser 值，由当前实例内部维护。
   */
  private parser: ProviderSSEParser;

  /**
   * 注入Provider 请求运行时依赖并初始化实例状态。
   * @param runtime 运行时实例。
   * @param taskId 目标任务标识。
   */
  constructor(runtime: ProviderRuntime, taskId: string, parser: ProviderSSEParser) {
    this.runtime = runtime;
    this.taskId = taskId;
    this.parser = parser;
  }

  /**
   * 执行 onChunk 的内部处理步骤，供当前模块复用。

   */
  async onChunk(chunk: string): Promise<void> {
    await this.runtime.acceptOpenAICompatibleChunk(this.taskId, this.parser, chunk);
  }

  /**
   * 执行 onError 的内部处理步骤，供当前模块复用。
   * @param message 消息记录。
   */
  async onError(message: string): Promise<void> {
    await this.runtime.failStream(this.taskId, message);
  }

  /**
   * 执行 onDone 的内部处理步骤，供当前模块复用。
   */
  async onDone(): Promise<void> {
    await this.runtime.finishOpenAICompatibleStream(this.taskId, this.parser);
  }
}

/**
 * 提供Provider 请求相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ProviderRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * streaming 值，由当前实例内部维护。
   */
  private streaming: StreamingRuntime;
  /**
   * normalizer 值，由当前实例内部维护。
   */
  private normalizer: OpenAICompatibleNormalizer = new OpenAICompatibleNormalizer();
  /**
   * tasks 列表，由当前实例内部维护。
   */
  private tasks: Map<string, ProviderStreamTask> = new Map<string, ProviderStreamTask>();
  /**
   * handles 列表，由当前实例内部维护。
   */
  private handles: Map<string, ProviderStreamHandle> = new Map<string, ProviderStreamHandle>();

  /**
   * 注入Provider 请求运行时依赖并初始化实例状态。
   * @param events 事件总线。
   */
  constructor(events: EventBus, streaming: StreamingRuntime) {
    this.events = events;
    this.streaming = streaming;
  }

  /**
   * 启动Open AICompatible Stream 值流程，并记录初始任务或会话状态。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 执行 abortProviderStream 的内部处理步骤，供当前模块复用。
   * @param taskId 目标任务标识。
   * @param reason 失败、中止或恢复操作的原因说明。
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
   * 读取指定任务，不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 更新或读取后的记录副本。
   */
  getTask(taskId: string): ProviderStreamTask {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 执行 openAICompatibleCapability 的内部处理步骤，供当前模块复用。
   * @param model 模型名称。


   * @returns 条件命中时返回 true，否则返回 false。
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
   * 根据入参构建Text Completion Request 值，仅生成数据结构，不直接执行外部请求。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildTextCompletionRequest(params: ProviderTextCompletionBuildParams): ProviderTextCompletionRequest {
    const apiType = params.apiType.toLowerCase();
    if (apiType === 'ollama') {
      return this.buildOllamaTextCompletionRequest(apiType, params);
    }
    return this.buildOpenAITextCompletionRequest(apiType, params);
  }

  /**
   * 执行 acceptOpenAICompatibleChunk 的内部处理步骤，供当前模块复用。
   * @param taskId 目标任务标识。


   */
  async acceptOpenAICompatibleChunk(taskId: string, parser: ProviderSSEParser, chunk: string): Promise<void> {
    // 事件总线。
    const events = parser.push(chunk);
    await this.consumeEvents(taskId, events);
  }

  /**
   * 执行 finishOpenAICompatibleStream 的内部处理步骤，供当前模块复用。
   * @param taskId 目标任务标识。

   */
  async finishOpenAICompatibleStream(taskId: string, parser: ProviderSSEParser): Promise<void> {
    // 事件总线。
    const events = parser.flush();
    await this.consumeEvents(taskId, events);
    this.completeStream(taskId);
  }

  /**
   * 标记Stream 值失败，并保存错误信息。
   * @param taskId 目标任务标识。
   * @param message 消息记录。
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
  private async consumeEvents(taskId: string, events: Array<ProviderSSEEvent>): Promise<void> {
    for (let index = 0; index < events.length; index += 1) {
      await this.consumeEvent(taskId, events[index]);
    }
  }
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
    if (normalized.reasoningDelta.length > 0) {
      await this.streaming.applyDelta(task.sessionId, normalized.reasoningDelta, true);
    }
    if (normalized.textDelta.length > 0) {
      await this.streaming.applyDelta(task.sessionId, normalized.textDelta, false);
    }
    if (normalized.finishReason.length > 0) {
      task.finishReason = normalized.finishReason;
      task.updatedAt = Date.now();
    }
  }

  /**
   * 标记Stream 值完成，并写入最终结果。
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
   * 读取必须存在的Task 值，缺失时抛出错误。
   * @param taskId 目标任务标识。
   */
  private requireTask(taskId: string): ProviderStreamTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`Provider stream task not found: ${taskId}`);
    }
    return task;
  }

  /**
   * 发布Provider 请求事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。

   */
  private publish(eventName: string, task: ProviderStreamTask): void {
    const payload: ProviderGenerationPayload = {
      task: this.copyTask(task),
    };
    this.events.publish<ProviderGenerationPayload>(eventName, payload);
  }

  /**
   * 复制Task 值，避免外部修改内部状态。
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
   * 根据入参构建Open AIText Completion Request 值，仅生成数据结构，不直接执行外部请求。

   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 构建好的请求、Prompt 或中间数据。
   */
  private buildOpenAITextCompletionRequest(apiType: ConnectionApiType, params: ProviderTextCompletionBuildParams): ProviderTextCompletionRequest {
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
   * 根据入参构建Ollama Text Completion Request 值，仅生成数据结构，不直接执行外部请求。

   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 构建好的请求、Prompt 或中间数据。
   */
  private buildOllamaTextCompletionRequest(apiType: ConnectionApiType, params: ProviderTextCompletionBuildParams): ProviderTextCompletionRequest {
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
  private textCompletionPath(apiType: ConnectionApiType): string {
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
   * 规范化Text Completion Stops 列表，保证后续比较和存储使用一致格式。


   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private normalizeTextCompletionStops(apiType: ConnectionApiType, stop: Array<string>): Array<string> {
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
