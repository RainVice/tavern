import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  getBackendCapability,
  OPENROUTER_CAPABILITY,
  ProviderRuntime,
  StreamingRuntime,
  type ProviderChatMessage,
  type ProviderCapability,
  type ProviderGenerationPayload,
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
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
      const source = new ScriptedStreamSource([
        'data: {"choices":[{"delta":{"content":"Hel"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"lo"}}]}\n\n',
        'data: [DONE]\n\n',
      ], '');
      const provider = new ProviderRuntime(bus, streaming);
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
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
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
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
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
  });
}

class ScriptedStreamSource implements ProviderStreamSource {
  private chunks: Array<string>;
  private errorMessage: string;

  constructor(chunks: Array<string>, errorMessage: string) {
    this.chunks = chunks;
    this.errorMessage = errorMessage;
  }

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

class ScriptedStreamHandle implements ProviderStreamHandle {
  close(): void {
  }
}

class ThrowingStreamSource implements ProviderStreamSource {
  async start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle> {
    if (!request.stream) {
      await sink.onError('stream disabled');
    }
    throw new Error('provider start failed');
  }
}

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

function makeMessage(): ProviderChatMessage {
  return {
    role: 'user',
    content: 'Hello',
  };
}
