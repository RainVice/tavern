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
 * OpenAI 兼容流式数据消费者的实现，将流式事件转发给 ProviderRuntime 处理。
 */
class OpenAIProviderStreamSink implements ProviderStreamSink {
  private runtime: ProviderRuntime;
  private taskId: string;
  private parser: ProviderSSEParser;

  constructor(runtime: ProviderRuntime, taskId: string, parser: ProviderSSEParser) {
    this.runtime = runtime;
    this.taskId = taskId;
    this.parser = parser;
  }

  async onChunk(chunk: string): Promise<void> {
    await this.runtime.acceptOpenAICompatibleChunk(this.taskId, this.parser, chunk);
  }

  async onError(message: string): Promise<void> {
    await this.runtime.failStream(this.taskId, message);
  }

  async onDone(): Promise<void> {
    await this.runtime.finishOpenAICompatibleStream(this.taskId, this.parser);
  }
}

/**
 * 提供 Provider 请求相关的无 UI 运行时能力，负责流式任务状态管理、数据读写和事件发布。
 */
export class ProviderRuntime {
  private events: EventBus;
  private streaming: StreamingRuntime;
  private normalizer: OpenAICompatibleNormalizer = new OpenAICompatibleNormalizer();
  private tasks: Map<string, ProviderStreamTask> = new Map<string, ProviderStreamTask>();
  private handles: Map<string, ProviderStreamHandle> = new Map<string, ProviderStreamHandle>();

  /**
   * 创建 ProviderRuntime 实例，注入事件总线和流式运行时依赖。
   * @param events 事件总线，用于发布流式生成事件。
   * @param streaming 流式运行时，管理流式会话。
   */
  constructor(events: EventBus, streaming: StreamingRuntime) {
    this.events = events;
    this.streaming = streaming;
  }

  /**
   * 启动 OpenAI 兼容流式请求，创建流式任务并发布 generation.started 事件。
   * @param params 流式启动参数（任务标识、聊天标识、请求数据、数据源等）。
   * @returns 创建后的流式任务状态信息。
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
   * 中止指定的 Provider 流式任务，关闭句柄并更新任务状态为 aborted。
   * @param taskId 任务标识。
   * @param reason 中止原因。
   * @returns 更新后的任务状态副本。
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
   * 获取指定任务的只读副本。
   * @param taskId 任务标识。
   * @returns 任务状态的副本。
   */
  getTask(taskId: string): ProviderStreamTask {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 为 OpenAI 兼容后端生成 ProviderCapability 声明。
   * @param model 模型名称。
   * @param maxContext 最大上下文长度（token 数）。
   * @param supportsReasoning 是否支持推理输出。
   * @returns 能力声明对象。
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
   * 根据构建参数创建文本补全请求对象，自动根据 API 类型分派到不同后端的构建逻辑。
   * @param params 文本补全构建参数。
   * @returns 构建后的文本补全请求对象。
   */
  buildTextCompletionRequest(params: ProviderTextCompletionBuildParams): ProviderTextCompletionRequest {
    const apiType = params.apiType.toLowerCase();
    if (apiType === 'ollama') {
      return this.buildOllamaTextCompletionRequest(apiType, params);
    }
    return this.buildOpenAITextCompletionRequest(apiType, params);
  }

  /**
   * 处理 OpenAI 兼容数据块，解析并消费其中包含的 SSE 事件。
   * @param taskId 任务标识。
   * @param parser SSE 解析器实例。
   * @param chunk 原始数据块字符串。
   */
  async acceptOpenAICompatibleChunk(taskId: string, parser: ProviderSSEParser, chunk: string): Promise<void> {
    const events = parser.push(chunk);
    await this.consumeEvents(taskId, events);
  }

  /**
   * 完成 OpenAI 兼容流式传输，处理剩余的 SSE 事件并标记任务完成。
   * @param taskId 任务标识。
   * @param parser SSE 解析器实例。
   */
  async finishOpenAICompatibleStream(taskId: string, parser: ProviderSSEParser): Promise<void> {
    const events = parser.flush();
    await this.consumeEvents(taskId, events);
    this.completeStream(taskId);
  }

  /**
   * 标记流式任务失败，更新状态为 failed 并发布 generation.failed 事件。
   * @param taskId 任务标识。
   * @param message 错误信息。
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
   * 深拷贝 ProviderStreamTask 对象，防止外部篡改内部任务数据。
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
   * 构建 OpenAI 兼容文本补全请求体，使用标准采样参数。
   * @param apiType API 连接类型。
   * @param params 文本补全构建参数。
   * @returns 文本补全请求对象。
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
   * 构建 Ollama 文本补全请求体，使用嵌套 options 结构和 raw 模式。
   * @param apiType API 连接类型。
   * @param params 文本补全构建参数。
   * @returns 文本补全请求对象。
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
  /**
   * 根据 API 类型返回对应的文本补全请求路径。
   */
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
   * 规范化文本补全的停止字符串列表，generic 类型最多保留 4 项。
   * @param apiType API 连接类型。
   * @param stop 原始停止字符串列表。
   * @returns 规范化后的停止字符串副本。
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
  /**
   * 将可选的采样参数（topP、penalties、seed）应用到请求体中。
   * @param body 请求体，会被原地修改。
   * @param params 构建参数，包含可选采样字段。
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
