import type {
  Conversation,
  ConversationCreateParams,
  ConversationDeleted,
  ConversationItem,
  ConversationItemCreateParams,
  ConversationItemListParams,
  ConversationItemListResponse,
  ConversationItemRetrieveParams,
  ConversationUpdateParams,
} from '../../models/Conversations';
import type { CursorPageParams } from '../../models/Common';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { appendCursorQuery, appendStringArrayQuery, buildPathWithQuery } from '../core/RequestUtils';

/**
 * Conversations 资源入口。
 *
 * API：`/v1/conversations`。
 * 说明：管理 Responses API 可复用的会话状态。
 */
export interface OpenAIConversationsResource {
  /** Items 子资源。API：Conversation Items。说明：管理会话内消息和工具项。 */
  items: OpenAIConversationItemsResource;
  /** 创建 Conversation。API：`POST /v1/conversations`。说明：创建会话状态容器。 */
  create(params: ConversationCreateParams): Promise<Conversation>;
  /** 获取 Conversation。API：`GET /v1/conversations/{conversation_id}`。说明：读取会话元数据。 */
  retrieve(conversationID: string): Promise<Conversation>;
  /** 更新 Conversation。API：`POST /v1/conversations/{conversation_id}`。说明：更新 metadata。 */
  update(conversationID: string, params: ConversationUpdateParams): Promise<Conversation>;
  /** 删除 Conversation。API：`DELETE /v1/conversations/{conversation_id}`。说明：删除会话。 */
  delete(conversationID: string): Promise<ConversationDeleted>;
}

/**
 * Conversation Items 子资源。
 *
 * API：`/v1/conversations/{conversation_id}/items`。
 * 说明：管理会话中的单个 item。
 */
export interface OpenAIConversationItemsResource {
  /** 创建 item。API：Create Conversation Item。说明：向会话追加消息或工具项。 */
  create(conversationID: string, params: ConversationItemCreateParams): Promise<ConversationItem>;
  /** 获取 item。API：Retrieve Conversation Item。说明：读取单个 item。 */
  retrieve(conversationID: string, itemID: string, params?: ConversationItemRetrieveParams): Promise<ConversationItem>;
  /** 列出 items。API：List Conversation Items。说明：分页读取会话 items。 */
  list(conversationID: string, params?: ConversationItemListParams): Promise<ConversationItemListResponse>;
  /** 删除 item。API：Delete Conversation Item。说明：从会话中移除 item，返回更新后的 Conversation。 */
  delete(conversationID: string, itemID: string): Promise<Conversation>;
}

export class ConversationsResource implements OpenAIConversationsResource {
  items: OpenAIConversationItemsResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.items = new ConversationItemsResource(client);
  }

  async create(params: ConversationCreateParams): Promise<Conversation> {
    const body = await this.client.post('/conversations', params);
    return JSON.parse(body) as Conversation;
  }

  async retrieve(conversationID: string): Promise<Conversation> {
    const body = await this.client.get('/conversations/' + conversationID);
    return JSON.parse(body) as Conversation;
  }

  async update(conversationID: string, params: ConversationUpdateParams): Promise<Conversation> {
    const body = await this.client.post('/conversations/' + conversationID, params);
    return JSON.parse(body) as Conversation;
  }

  async delete(conversationID: string): Promise<ConversationDeleted> {
    const body = await this.client.delete('/conversations/' + conversationID);
    return JSON.parse(body) as ConversationDeleted;
  }
}

class ConversationItemsResource implements OpenAIConversationItemsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(conversationID: string, params: ConversationItemCreateParams): Promise<ConversationItem> {
    const body = await this.client.post('/conversations/' + conversationID + '/items', params);
    return JSON.parse(body) as ConversationItem;
  }

  async retrieve(conversationID: string, itemID: string, params?: ConversationItemRetrieveParams): Promise<ConversationItem> {
    const path = buildConversationItemRetrievePath('/conversations/' + conversationID + '/items/' + itemID, params);
    const body = await this.client.get(path);
    return JSON.parse(body) as ConversationItem;
  }

  async list(conversationID: string, params?: ConversationItemListParams): Promise<ConversationItemListResponse> {
    const path = buildConversationItemListPath('/conversations/' + conversationID + '/items', params);
    const body = await this.client.get(path);
    return JSON.parse(body) as ConversationItemListResponse;
  }

  async delete(conversationID: string, itemID: string): Promise<Conversation> {
    const body = await this.client.delete('/conversations/' + conversationID + '/items/' + itemID);
    return JSON.parse(body) as Conversation;
  }
}

function buildConversationItemListPath(path: string, params?: ConversationItemListParams): string {
  if (params === undefined) {
    return path;
  }
  const query: Array<string> = [];
  appendCursorQuery(query, params);
  appendIncludeQuery(query, params);
  return buildPathWithQuery(path, query);
}

function buildConversationItemRetrievePath(path: string, params?: ConversationItemRetrieveParams): string {
  if (params === undefined) {
    return path;
  }
  const query: Array<string> = [];
  appendIncludeQuery(query, params);
  return buildPathWithQuery(path, query);
}

function appendIncludeQuery(query: Array<string>, params: ConversationItemListParams | ConversationItemRetrieveParams): void {
  appendStringArrayQuery(query, 'include', params.include);
}
