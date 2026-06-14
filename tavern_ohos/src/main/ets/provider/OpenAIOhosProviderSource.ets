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
 * 基于 openai_ohos 库的 OpenAI 兼容 Provider 流式请求来源。
 * 将 ProviderStreamSource 接口适配到 openai_ohos 的流式请求客户端，
 * 负责发起 HTTP 流式 POST 请求并将事件转发到 ProviderStreamSink。
 */
export class OpenAIOhosProviderStreamSource implements ProviderStreamSource {
  private client: OpenAIRequestClient;

  constructor(options: OpenAIOhosProviderStreamSourceOptions) {
    this.client = new OpenAIRequestClient(options);
  }

  /**
   * 启动流式请求：将 ProviderStreamRequest 转换为 openai_ohos 的请求格式，
   * 发起 Chat Completions API 调用，并将流式事件转发到指定的 Sink。
   * @param request 流式请求参数，包含模型、消息和采样配置。
   * @param sink 流式数据消费者，接收 onChunk/onError/onDone 回调。
   * @returns 流式句柄，可通过 close() 中止请求。
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

  /**
   * 将 ProviderChatMessage 列表转换为 openai_ohos 的 ChatMessage 格式（浅拷贝）。
   */
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

  /**
   * 将 openai_ohos 的 SSE 事件序列化为原始文本块，转发到 Sink 的 onChunk。
   */
  private forwardEvent(sink: ProviderStreamSink, event: OpenAISSEEvent): void {
    const chunk = this.serializeEvent(event);
    sink.onChunk(chunk).catch((error: Error) => {
      this.forwardError(sink, String(error));
    });
  }

  /**
   * 将错误消息转发到 Sink 的 onError。
   */
  private forwardError(sink: ProviderStreamSink, message: string): void {
    sink.onError(message);
  }

  /**
   * 通知 Sink 流式请求已完成。
   */
  private forwardDone(sink: ProviderStreamSink): void {
    sink.onDone();
  }

  /**
   * 将 openai_ohos 的 SSE 事件对象序列化为符合 SSE 协议的原始文本字符串。
   * 包含 event 行、id 行和 data 行，以双换行结尾。
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
 * openai_ohos 流式请求的句柄实现，封装了对 OpenAIStream 的 close 调用。
 */
class OpenAIOhosProviderStreamHandle implements ProviderStreamHandle {
  private stream: OpenAIStream;

  constructor(stream: OpenAIStream) {
    this.stream = stream;
  }

  /** 关闭底层的 OpenAI 流式连接。 */
  close(): void {
    this.stream.close();
  }
}
