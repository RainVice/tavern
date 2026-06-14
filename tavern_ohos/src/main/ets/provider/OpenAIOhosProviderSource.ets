import {
  OpenAIRequestClient,
  type OpenAIClientOptions,
  type OpenAISSEEvent,
  type OpenAIStream,
} from 'openai_ohos';
import type {
  ProviderChatMessage,
  ProviderStreamHandle,
  ProviderStreamRequest,
  ProviderStreamSink,
  ProviderStreamSource,
} from './ProviderModels';

/**
 * OpenAI 兼容 Provider 流式数据源的配置选项，继承自 OpenAIClientOptions。
 */
export interface OpenAIOhosProviderStreamSourceOptions extends OpenAIClientOptions {
}

interface OpenAIOhosChatMessage {
  role: string;
  content: string;
}

interface OpenAIOhosChatCompletionStreamBody {
  model: string;
  messages: Array<OpenAIOhosChatMessage>;
  temperature: number;
  max_tokens: number;
  stop: Array<string>;
  stream: boolean;
}

/**
 * 基于 openai_ohos 库实现的 OpenAI 兼容 Provider 流式数据源。
 * 使用 OpenAIRequestClient 发起 SSE 流式请求，并将事件转发给 ProviderStreamSink。
 */
export class OpenAIOhosProviderStreamSource implements ProviderStreamSource {
  private client: OpenAIRequestClient;

  constructor(options: OpenAIOhosProviderStreamSourceOptions) {
    this.client = new OpenAIRequestClient(options);
  }

  /**
   * 启动流式请求，通过 openai_ohos 客户端发送 POST 请求并转发 SSE 事件。
   * @param request 流式请求参数。
   * @param sink 流式数据消费者。
   * @returns 流式连接句柄，可在外部关闭。
   */
  async start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle> {
    const owner: OpenAIOhosProviderStreamSource = this;
    const headers: Record<string, string> = {};
    const body: OpenAIOhosChatCompletionStreamBody = {
      model: request.model,
      messages: owner.cloneMessages(request.messages),
      temperature: request.temperature,
      max_tokens: request.maxTokens,
      stop: request.stop.slice(),
      stream: true,
    };
    const stream = this.client.streamPost('/chat/completions', body, headers, (event: OpenAISSEEvent) => {
      owner.forwardEvent(sink, event);
    }, (message: string) => {
      owner.forwardError(sink, message);
    }, () => {
      owner.forwardDone(sink);
    });
    return new OpenAIOhosProviderStreamHandle(stream);
  }

  private cloneMessages(messages: Array<ProviderChatMessage>): Array<OpenAIOhosChatMessage> {
    const result: Array<OpenAIOhosChatMessage> = [];
    for (let index = 0; index < messages.length; index += 1) {
      const source = messages[index];
      const message: OpenAIOhosChatMessage = {
        role: source.role,
        content: source.content,
      };
      result.push(message);
    }
    return result;
  }

  private forwardEvent(sink: ProviderStreamSink, event: OpenAISSEEvent): void {
    const chunk = this.serializeEvent(event);
    sink.onChunk(chunk).catch((error: Error) => {
      this.forwardError(sink, String(error));
    });
  }

  private forwardError(sink: ProviderStreamSink, message: string): void {
    sink.onError(message);
  }

  private forwardDone(sink: ProviderStreamSink): void {
    sink.onDone();
  }

  /**
   * 将 SSE 事件序列化为标准 SSE 格式字符串（event + id + data 行）。
   * @param event 原始 SSE 事件对象。
   * @returns 序列化后的 SSE 文本块。
   */
  private serializeEvent(event: OpenAISSEEvent): string {
    let result = '';
    if (event.event.length > 0 && event.event !== 'message') {
      result += 'event: ' + event.event + '\n';
    }
    if (event.id !== undefined) {
      result += 'id: ' + event.id + '\n';
    }
    const lines = event.data.split('\n');
    for (let index = 0; index < lines.length; index += 1) {
      result += 'data: ' + lines[index] + '\n';
    }
    return result + '\n';
  }
}

/**
 * OpenAI 流式连接句柄的实现，通过底层流对象提供关闭功能。
 */
class OpenAIOhosProviderStreamHandle implements ProviderStreamHandle {
  private stream: OpenAIStream;

  constructor(stream: OpenAIStream) {
    this.stream = stream;
  }

  /**
   * 关闭底层流式连接。
   */
  close(): void {
    this.stream.close();
  }
}
