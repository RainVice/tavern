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

export class ProviderRuntime {
  private events: EventBus;
  private streaming: StreamingRuntime;
  private normalizer: OpenAICompatibleNormalizer = new OpenAICompatibleNormalizer();
  private tasks: Map<string, ProviderStreamTask> = new Map<string, ProviderStreamTask>();
  private handles: Map<string, ProviderStreamHandle> = new Map<string, ProviderStreamHandle>();

  constructor(events: EventBus, streaming: StreamingRuntime) {
    this.events = events;
    this.streaming = streaming;
  }

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

  getTask(taskId: string): ProviderStreamTask {
    return this.copyTask(this.requireTask(taskId));
  }

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

  buildTextCompletionRequest(params: ProviderTextCompletionBuildParams): ProviderTextCompletionRequest {
    const apiType = params.apiType.toLowerCase();
    if (apiType === 'ollama') {
      return this.buildOllamaTextCompletionRequest(apiType, params);
    }
    return this.buildOpenAITextCompletionRequest(apiType, params);
  }

  async acceptOpenAICompatibleChunk(taskId: string, parser: ProviderSSEParser, chunk: string): Promise<void> {
    const events = parser.push(chunk);
    await this.consumeEvents(taskId, events);
  }

  async finishOpenAICompatibleStream(taskId: string, parser: ProviderSSEParser): Promise<void> {
    const events = parser.flush();
    await this.consumeEvents(taskId, events);
    this.completeStream(taskId);
  }

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

  private requireTask(taskId: string): ProviderStreamTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`Provider stream task not found: ${taskId}`);
    }
    return task;
  }

  private publish(eventName: string, task: ProviderStreamTask): void {
    const payload: ProviderGenerationPayload = {
      task: this.copyTask(task),
    };
    this.events.publish<ProviderGenerationPayload>(eventName, payload);
  }

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
