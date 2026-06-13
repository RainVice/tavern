import type {
  ChatKitSession,
  ChatKitSessionCreateParams,
  ChatKitThread,
  ChatKitThreadDeleted,
  ChatKitThreadItemListParams,
  ChatKitThreadItemListResponse,
  ChatKitThreadListParams,
  ChatKitThreadListResponse,
} from '../../models/ChatKit';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { appendCursorQuery, appendStringQuery, buildCursorListPath, buildPathWithQuery, encodePathParam } from '../core/RequestUtils';

interface EmptyRequestBody {
}

const CHATKIT_BETA_HEADERS: Record<string, string> = {
  'OpenAI-Beta': 'chatkit_beta=v1',
};

/**
 * ChatKit 资源入口。
 *
 * API：`/v1/chatkit`。
 * 说明：ChatKit beta REST 资源，所有请求都带 `OpenAI-Beta: chatkit_beta=v1`。
 */
export interface OpenAIChatKitResource {
  /** Sessions 子资源。API：ChatKit Sessions。说明：创建和取消 ChatKit session。 */
  sessions: OpenAIChatKitSessionsResource;
  /** Threads 子资源。API：ChatKit Threads。说明：读取和删除 ChatKit threads。 */
  threads: OpenAIChatKitThreadsResource;
}

/** ChatKit sessions 子资源。API：`/v1/chatkit/sessions`。说明：管理 ChatKit 短期 session。 */
export interface OpenAIChatKitSessionsResource {
  /** 创建 session。API：Create ChatKit session。说明：返回前端可用 client_secret。 */
  create(params: ChatKitSessionCreateParams): Promise<ChatKitSession>;
  /** 取消 session。API：Cancel ChatKit session。说明：使 session 失效。 */
  cancel(sessionID: string): Promise<ChatKitSession>;
}

/** ChatKit threads 子资源。API：`/v1/chatkit/threads`。说明：管理 ChatKit 历史线程。 */
export interface OpenAIChatKitThreadsResource {
  /** Items 子资源。API：ChatKit Thread Items。说明：读取 thread items。 */
  items: OpenAIChatKitThreadItemsResource;
  /** 列出 threads。API：List ChatKit threads。说明：支持 user 过滤和分页。 */
  list(params?: ChatKitThreadListParams): Promise<ChatKitThreadListResponse>;
  /** 获取 thread。API：Retrieve ChatKit thread。说明：读取单个 thread。 */
  retrieve(threadID: string): Promise<ChatKitThread>;
  /** 删除 thread。API：Delete ChatKit thread。说明：删除历史 thread。 */
  delete(threadID: string): Promise<ChatKitThreadDeleted>;
}

/** ChatKit thread items 子资源。API：`/v1/chatkit/threads/{thread_id}/items`。说明：读取 thread 内 items。 */
export interface OpenAIChatKitThreadItemsResource {
  /** 列出 items。API：List ChatKit thread items。说明：支持游标分页。 */
  list(threadID: string, params?: ChatKitThreadItemListParams): Promise<ChatKitThreadItemListResponse>;
}

export class ChatKitResource implements OpenAIChatKitResource {
  sessions: OpenAIChatKitSessionsResource;
  threads: OpenAIChatKitThreadsResource;

  constructor(client: OpenAIRequestClient) {
    this.sessions = new ChatKitSessionsResource(client);
    this.threads = new ChatKitThreadsResource(client);
  }
}

class ChatKitSessionsResource implements OpenAIChatKitSessionsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: ChatKitSessionCreateParams): Promise<ChatKitSession> {
    const body = await this.client.post('/chatkit/sessions', params, CHATKIT_BETA_HEADERS);
    return JSON.parse(body) as ChatKitSession;
  }

  async cancel(sessionID: string): Promise<ChatKitSession> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post('/chatkit/sessions/' + encodePathParam(sessionID) + '/cancel', requestBody, CHATKIT_BETA_HEADERS);
    return JSON.parse(body) as ChatKitSession;
  }
}

class ChatKitThreadsResource implements OpenAIChatKitThreadsResource {
  items: OpenAIChatKitThreadItemsResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.items = new ChatKitThreadItemsResource(client);
  }

  async list(params?: ChatKitThreadListParams): Promise<ChatKitThreadListResponse> {
    const body = await this.client.get(this.buildListPath(params), CHATKIT_BETA_HEADERS);
    return JSON.parse(body) as ChatKitThreadListResponse;
  }

  async retrieve(threadID: string): Promise<ChatKitThread> {
    const body = await this.client.get('/chatkit/threads/' + encodePathParam(threadID), CHATKIT_BETA_HEADERS);
    return JSON.parse(body) as ChatKitThread;
  }

  async delete(threadID: string): Promise<ChatKitThreadDeleted> {
    const body = await this.client.delete('/chatkit/threads/' + encodePathParam(threadID), CHATKIT_BETA_HEADERS);
    return JSON.parse(body) as ChatKitThreadDeleted;
  }

  private buildListPath(params?: ChatKitThreadListParams): string {
    if (params === undefined) {
      return '/chatkit/threads';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'user', params.user);
    appendCursorQuery(query, params);
    return buildPathWithQuery('/chatkit/threads', query);
  }
}

class ChatKitThreadItemsResource implements OpenAIChatKitThreadItemsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(threadID: string, params?: ChatKitThreadItemListParams): Promise<ChatKitThreadItemListResponse> {
    const path = buildCursorListPath('/chatkit/threads/' + encodePathParam(threadID) + '/items', params);
    const body = await this.client.get(path, CHATKIT_BETA_HEADERS);
    return JSON.parse(body) as ChatKitThreadItemListResponse;
  }
}
