import type {
  ChatCompletion,
  ChatCompletionChunk,
  ChatCompletionCreateParams,
  ChatCompletionDeleted,
  ChatCompletionListParams,
  ChatCompletionListResponse,
  ChatCompletionUpdateParams,
} from '../../models/Chat';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import type { OpenAISSEEvent } from '../core/OpenAISSEParser';
import { appendCursorQuery, appendStringQuery, buildPathWithQuery } from '../core/RequestUtils';
import type { OpenAIRequestSettings, OpenAIStream } from '../core/Types';

/** Chat Completions 流式回调。 */
export interface ChatCompletionStreamHandlers {
  /** 收到一条 SSE chunk。 */
  onChunk(chunk: ChatCompletionChunk): void;
  /** 流式请求发生错误。 */
  onError?: (message: string) => void;
  /** 底层连接结束。 */
  onDone?: () => void;
}

/**
 * Chat Completions 资源入口。
 *
 * API：`POST /v1/chat/completions`。
 * 说明：兼容官方 SDK 的 `client.chat.completions.create(...)` 调用方式。
 */
export interface OpenAIChatCompletionsResource {
  /**
   * 创建 Chat Completion。
   *
   * API：`POST /v1/chat/completions`。
   * 说明：使用 messages 数组创建对话式模型响应。
   */
  create(params: ChatCompletionCreateParams): Promise<ChatCompletion>;

  /**
   * 创建流式 Chat Completion。
   *
   * API：`POST /v1/chat/completions`。
   * 说明：自动设置 `stream: true`，并把 SSE 数据解析为 `ChatCompletionChunk`。
   */
  createStream(
    params: ChatCompletionCreateParams,
    handlers: ChatCompletionStreamHandlers,
    options?: OpenAIRequestSettings
  ): OpenAIStream;

  /**
   * 获取已存储 Chat Completion。
   *
   * API：`GET /v1/chat/completions/{completion_id}`。
   * 说明：仅对 `store: true` 创建的 completion 有效。
   */
  retrieve(completionID: string): Promise<ChatCompletion>;

  /**
   * 更新已存储 Chat Completion。
   *
   * API：`POST /v1/chat/completions/{completion_id}`。
   * 说明：当前主要用于更新 metadata。
   */
  update(completionID: string, params: ChatCompletionUpdateParams): Promise<ChatCompletion>;

  /**
   * 列出已存储 Chat Completion。
   *
   * API：`GET /v1/chat/completions`。
   * 说明：仅返回 `store: true` 的 completion。
   */
  list(params?: ChatCompletionListParams): Promise<ChatCompletionListResponse>;

  /**
   * 删除已存储 Chat Completion。
   *
   * API：`DELETE /v1/chat/completions/{completion_id}`。
   * 说明：仅对已存储 completion 有效。
   */
  delete(completionID: string): Promise<ChatCompletionDeleted>;
}

export interface OpenAIChatResource {
  /**
   * Chat Completions API。
   *
   * API：`/v1/chat/completions`。
   * 说明：保持官方 SDK 的 `chat.completions` 层级。
   */
  completions: OpenAIChatCompletionsResource;
}

class ChatCompletionsResource implements OpenAIChatCompletionsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: ChatCompletionCreateParams): Promise<ChatCompletion> {
    const body = await this.client.post('/chat/completions', params);
    return JSON.parse(body) as ChatCompletion;
  }

  createStream(
    params: ChatCompletionCreateParams,
    handlers: ChatCompletionStreamHandlers,
    options?: OpenAIRequestSettings
  ): OpenAIStream {
    params.stream = true;
    return this.client.streamPost('/chat/completions', params, {}, (event: OpenAISSEEvent) => {
      if (event.data === '[DONE]') {
        return;
      }
      handlers.onChunk(JSON.parse(event.data) as ChatCompletionChunk);
    }, handlers.onError, handlers.onDone, options);
  }

  async retrieve(completionID: string): Promise<ChatCompletion> {
    const body = await this.client.get('/chat/completions/' + completionID);
    return JSON.parse(body) as ChatCompletion;
  }

  async update(completionID: string, params: ChatCompletionUpdateParams): Promise<ChatCompletion> {
    const body = await this.client.post('/chat/completions/' + completionID, params);
    return JSON.parse(body) as ChatCompletion;
  }

  async list(params?: ChatCompletionListParams): Promise<ChatCompletionListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as ChatCompletionListResponse;
  }

  async delete(completionID: string): Promise<ChatCompletionDeleted> {
    const body = await this.client.delete('/chat/completions/' + completionID);
    return JSON.parse(body) as ChatCompletionDeleted;
  }

  private buildListPath(params?: ChatCompletionListParams): string {
    if (params === undefined) {
      return '/chat/completions';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'model', params.model);
    appendCursorQuery(query, params);
    return buildPathWithQuery('/chat/completions', query);
  }
}

export class ChatResource implements OpenAIChatResource {
  completions: OpenAIChatCompletionsResource;

  constructor(client: OpenAIRequestClient) {
    this.completions = new ChatCompletionsResource(client);
  }
}
