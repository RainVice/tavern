import { describe, it, expect } from '@ohos/hypium';
import type {
  OpenAIRequestOptions,
  OpenAIResponse,
  OpenAIStream,
  OpenAIStreamChunkHandler,
  OpenAIStreamDoneHandler,
  OpenAIStreamErrorHandler,
  OpenAITransport,
} from 'openai_ohos';
import {
  EventBus,
  getBackendCapability,
  OpenAIOhosProviderStreamSource,
  OPENROUTER_CAPABILITY,
  ProviderRuntime,
  StreamingRuntime,
  type ProviderChatMessage,
  type ProviderCapability,
  type ProviderGenerationPayload,
  type OpenAIOhosProviderStreamSourceOptions,
  type ProviderTextCompletionRequest,
  type ProviderStreamHandle,
  type ProviderStreamRequest,
  type ProviderStreamSink,
  type ProviderStreamSource,
  type ProviderStreamStartParams,
  type RuntimeEvent,
  type StreamSession,
} from '../../Index';

export default function providerUnitTest() {
  describe('provider runtime', () => {
    it('normalizes OpenAI-compatible SSE chunks into streaming snapshots', 0, async () => {
      // 事件总线实例。
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
      // 来源类型。
      const source = new ScriptedStreamSource([
        'data: {"choices":[{"delta":{"content":"Hel"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"lo"}}]}\n\n',
        'data: [DONE]\n\n',
      ], '');
      const provider = new ProviderRuntime(bus, streaming);
      // 调用参数。
      const params: ProviderStreamStartParams = {
        taskId: 'task-provider-1',
        chatId: 'chat-1',
        messageId: 'msg-1',
        request: makeRequest(),
        source: source,
      };
      const task = await provider.startOpenAICompatibleStream(params);
      const session: StreamSession = streaming.getSession(task.sessionId);

      expect(session.status).assertEqual('completed');
      expect(session.snapshot).assertEqual('Hello');
      expect(task.status).assertEqual('completed');
    });

    it('accumulates reasoning deltas separately from visible text', 0, async () => {
      // 事件总线实例。
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
      // 来源类型。
      const source = new ScriptedStreamSource([
        'data: {"choices":[{"delta":{"reasoning_content":"Think"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"Answer"}}]}\n\n',
        'data: [DONE]\n\n',
      ], '');
      const provider = new ProviderRuntime(bus, streaming);
      const task = await provider.startOpenAICompatibleStream({
        taskId: 'task-provider-2',
        chatId: 'chat-1',
        messageId: 'msg-1',
        request: makeRequest(),
        source: source,
      });
      const session: StreamSession = streaming.getSession(task.sessionId);

      expect(task.status).assertEqual('completed');
      expect(session.snapshot).assertEqual('Answer');
      expect(session.reasoningSnapshot).assertEqual('Think');
    });

    it('aborts the streaming session when provider stream fails', 0, async () => {
      // 事件总线实例。
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
      // 来源类型。
      const source = new ScriptedStreamSource([
        'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
      ], 'network failed');
      const provider = new ProviderRuntime(bus, streaming);
      const task = await provider.startOpenAICompatibleStream({
        taskId: 'task-provider-3',
        chatId: 'chat-1',
        messageId: 'msg-1',
        request: makeRequest(),
        source: source,
      });
      const session: StreamSession = streaming.getSession(task.sessionId);

      expect(task.status).assertEqual('failed');
      expect(task.error).assertEqual('network failed');
      expect(session.status).assertEqual('aborted');
      expect(session.snapshot).assertEqual('partial');
    });

    it('marks stream task as failed when provider source throws during start', 0, async () => {
      // 事件总线实例。
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
      const provider = new ProviderRuntime(bus, streaming);
      const task = await provider.startOpenAICompatibleStream({
        taskId: 'task-provider-throw',
        chatId: 'chat-1',
        messageId: 'msg-1',
        request: makeRequest(),
        source: new ThrowingStreamSource(),
      });
      const session: StreamSession = streaming.getSession(task.sessionId);

      expect(task.status).assertEqual('failed');
      expect(task.error).assertContain('provider start failed');
      expect(session.status).assertEqual('aborted');
    });

    it('does not expose internal provider stream tasks', 0, async () => {
      // 事件总线实例。
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
      const provider = new ProviderRuntime(bus, streaming);
      bus.subscribe<ProviderGenerationPayload>('generation.started', (event: RuntimeEvent<ProviderGenerationPayload>) => {
        event.payload.task.status = 'event-mutated';
      });
      const task = await provider.startOpenAICompatibleStream({
        taskId: 'task-provider-copy',
        chatId: 'chat-1',
        messageId: 'msg-1',
        request: makeRequest(),
        source: new ScriptedStreamSource(['data: [DONE]\n\n'], ''),
      });
      task.status = 'external-mutated';
      const saved = provider.getTask('task-provider-copy');
      expect(saved.status).assertEqual('completed');
    });

    it('maps generic text completion prompts to OpenAI-compatible completion requests', 0, () => {
      const provider = new ProviderRuntime(new EventBus(), new StreamingRuntime(new EventBus()));
      const request: ProviderTextCompletionRequest = provider.buildTextCompletionRequest({
        apiType: 'generic',
        model: 'llama-3',
        prompt: 'System\nUser: hello\nAssistant:',
        temperature: 0.8,
        maxTokens: 120,
        stop: ['User:', 'Assistant:', '</s>', '<|end|>', 'extra-stop'],
        stream: true,
        topP: 0.9,
        presencePenalty: 0.1,
        frequencyPenalty: 0.2,
        seed: 42,
      });

      expect(request.path).assertEqual('/v1/completions');
      expect(request.body.model).assertEqual('llama-3');
      expect(request.body.prompt).assertEqual('System\nUser: hello\nAssistant:');
      expect(request.body.max_tokens).assertEqual(120);
      expect(request.body.stop.length).assertEqual(4);
      expect(request.body.stop[3]).assertEqual('<|end|>');
      expect(request.body.stream).assertTrue();
    });

    it('maps Ollama text completion prompts to raw generate requests', 0, () => {
      const provider = new ProviderRuntime(new EventBus(), new StreamingRuntime(new EventBus()));
      const request: ProviderTextCompletionRequest = provider.buildTextCompletionRequest({
        apiType: 'ollama',
        model: 'mistral',
        prompt: 'Tell me a story',
        temperature: 0.5,
        maxTokens: 64,
        stop: ['\nUser:'],
        stream: false,
        topP: 0.95,
      });

      expect(request.path).assertEqual('/api/generate');
      expect(request.body.model).assertEqual('mistral');
      expect(request.body.prompt).assertEqual('Tell me a story');
      expect(request.body.raw).assertTrue();
      expect(request.body.stream).assertFalse();
      const options = request.body.options;
      expect(options === undefined).assertFalse();
      expect(options!.num_predict).assertEqual(64);
      expect(options!.stop[0]).assertEqual('\nUser:');
    });

    it('does not reuse caller stop arrays in text completion requests', 0, () => {
      const provider = new ProviderRuntime(new EventBus(), new StreamingRuntime(new EventBus()));
      const stop = ['User:', 'Assistant:'];
      const openaiRequest: ProviderTextCompletionRequest = provider.buildTextCompletionRequest({
        apiType: 'openai',
        model: 'gpt',
        prompt: 'Hello',
        temperature: 0.7,
        maxTokens: 32,
        stop: stop,
        stream: false,
      });
      const ollamaRequest: ProviderTextCompletionRequest = provider.buildTextCompletionRequest({
        apiType: 'ollama',
        model: 'llama',
        prompt: 'Hello',
        temperature: 0.7,
        maxTokens: 32,
        stop: stop,
        stream: false,
      });

      stop[0] = 'mutated';

      expect(openaiRequest.body.stop[0]).assertEqual('User:');
      expect(ollamaRequest.body.stop[0]).assertEqual('User:');
      expect(ollamaRequest.body.options!.stop[0]).assertEqual('User:');
    });

    it('does not expose shared provider backend capability records', 0, () => {
      const first: ProviderCapability = getBackendCapability('openrouter');
      first.supportsStreaming = false;
      first.maxContext = 1;
      const second: ProviderCapability = getBackendCapability('openrouter');

      expect(second.supportsStreaming).assertTrue();
      expect(second.maxContext).assertEqual(200000);
    });

    it('保留后端能力常量导出并隔离运行时查询模板', 0, () => {
      OPENROUTER_CAPABILITY.supportsStreaming = false;
      OPENROUTER_CAPABILITY.maxContext = 1;
      const queried: ProviderCapability = getBackendCapability('openrouter');

      expect(queried.supportsStreaming).assertTrue();
      expect(queried.maxContext).assertEqual(200000);
    });

    it('uses openai_ohos streamPost for OpenAI-compatible chat streams', 0, async () => {
      const transport = new RecordingOpenAITransport();
      transport.nextStreamChunk = 'data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n';
      const headers: Record<string, string> = {
        'X-Test': 'provider',
      };
      const options: OpenAIOhosProviderStreamSourceOptions = {
        apiKey: 'sk-test',
        baseURL: 'https://gateway.example/v1',
        defaultHeaders: headers,
        transport: transport,
      };
      const source: ProviderStreamSource = new OpenAIOhosProviderStreamSource(options);
      const sink = new RecordingProviderStreamSink();
      const handle = await source.start(makeRequest(), sink);

      expect(transport.latestUrl).assertEqual('https://gateway.example/v1/chat/completions');
      expect(transport.latestHeaders['Authorization']).assertEqual('Bearer sk-test');
      expect(transport.latestHeaders['X-Test']).assertEqual('provider');
      expect(transport.latestBody).assertContain('"model":"test-model"');
      expect(transport.latestBody).assertContain('"stream":true');
      expect(transport.latestBody).assertContain('"messages":[{"role":"user","content":"Hello"}]');
      expect(transport.latestBody).assertContain('"stop":[]');
      expect(sink.chunks.length).assertEqual(1);
      expect(sink.chunks[0]).assertEqual('data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n');
      expect(sink.doneCount).assertEqual(1);

      handle.close();

      expect(transport.closedCount).assertEqual(1);
    });
  });
}

/**
 * 封装单元测试相关状态和行为。
 */
class ScriptedStreamSource implements ProviderStreamSource {
  /**
   * chunks 列表，由当前实例内部维护。
   */
  private chunks: Array<string>;
  /**
   * error Message 值，由当前实例内部维护。
   */
  private errorMessage: string;

  /**
   * 注入单元测试运行时依赖并初始化实例状态。


   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  constructor(chunks: Array<string>, errorMessage: string) {
    this.chunks = chunks;
    this.errorMessage = errorMessage;
  }

  /**
   * 启动目标对象流程，并记录初始任务或会话状态。
   * @param request 待处理的请求对象。
   */
  async start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle> {
    if (!request.stream) {
      await sink.onError('stream disabled');
      return new ScriptedStreamHandle();
    }
    for (let index = 0; index < this.chunks.length; index += 1) {
      await sink.onChunk(this.chunks[index]);
    }
    if (this.errorMessage.length > 0) {
      await sink.onError(this.errorMessage);
    } else {
      await sink.onDone();
    }
    return new ScriptedStreamHandle();
  }
}

/**
 * 封装单元测试相关状态和行为。
 */
class ScriptedStreamHandle implements ProviderStreamHandle {
  /**
   * 封装单元测试中的 close 步骤，供公开方法复用。
   */
  close(): void {
  }
}

/**
 * 封装单元测试相关状态和行为。
 */
class ThrowingStreamSource implements ProviderStreamSource {
  /**
   * 启动目标对象流程，并记录初始任务或会话状态。
   * @param request 待处理的请求对象。
   */
  async start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle> {
    if (!request.stream) {
      await sink.onError('stream disabled');
    }
    throw new Error('provider start failed');
  }
}

class RecordingProviderStreamSink implements ProviderStreamSink {
  chunks: Array<string> = [];
  errors: Array<string> = [];
  doneCount: number = 0;

  async onChunk(chunk: string): Promise<void> {
    this.chunks.push(chunk);
  }

  async onError(message: string): Promise<void> {
    this.errors.push(message);
  }

  async onDone(): Promise<void> {
    this.doneCount += 1;
  }
}

class RecordingOpenAITransport implements OpenAITransport {
  latestUrl: string = '';
  latestHeaders: Record<string, string> = {};
  latestBody: string = '';
  nextStreamChunk: string = '';
  closedCount: number = 0;

  async request(options: OpenAIRequestOptions): Promise<OpenAIResponse> {
    this.record(options);
    return {
      statusCode: 200,
      body: '{}',
    };
  }

  stream(
    options: OpenAIRequestOptions,
    onChunk: OpenAIStreamChunkHandler,
    _onError?: OpenAIStreamErrorHandler,
    onDone?: OpenAIStreamDoneHandler
  ): OpenAIStream {
    const owner: RecordingOpenAITransport = this;
    this.record(options);
    if (this.nextStreamChunk.length > 0) {
      onChunk(this.nextStreamChunk);
    }
    if (onDone !== undefined) {
      onDone();
    }
    return new RecordingOpenAIStream(owner);
  }

  private record(options: OpenAIRequestOptions): void {
    this.latestUrl = options.url;
    this.latestHeaders = options.headers;
    this.latestBody = options.body === undefined ? '' : options.body;
  }
}

class RecordingOpenAIStream implements OpenAIStream {
  private transport: RecordingOpenAITransport;

  constructor(transport: RecordingOpenAITransport) {
    this.transport = transport;
  }

  close(): void {
    this.transport.closedCount += 1;
  }
}

/**
 * 封装单元测试中的 makeRequest 步骤，供公开方法复用。
 */
function makeRequest(): ProviderStreamRequest {
  return {
    provider: 'openai-compatible',
    model: 'test-model',
    messages: [makeMessage()],
    temperature: 0.7,
    maxTokens: 128,
    stop: new Array<string>(),
    stream: true,
  };
}

/**
 * 封装单元测试中的 makeMessage 步骤，供公开方法复用。
 */
function makeMessage(): ProviderChatMessage {
  return {
    role: 'user',
    content: 'Hello',
  };
}
