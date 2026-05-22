import type { CursorPageParams, JsonObject, Metadata, OpenAIListResponse } from './Common';

/**
 * Conversations API model。
 *
 * API：`/v1/conversations`、`/v1/conversations/{conversation_id}/items`。
 * 说明：用于在 Responses API 调用之间存储和读取会话状态。
 */

/** Conversation item include 参数。API：List/Retrieve Conversation Items。说明：请求额外返回工具调用细节。 */
export type ConversationItemInclude =
  'web_search_call.action.sources' | 'code_interpreter_call.outputs' |
  'computer_call_output.output.image_url' | 'file_search_call.results';

/** Conversation message role。API：Conversation Items。说明：消息在指令层级中的角色。 */
export type ConversationMessageRole = 'developer' | 'system' | 'user' | 'assistant';

/** Conversation item 状态。API：Conversation Items。说明：表示 item 是否完成处理。 */
export type ConversationItemStatus = 'in_progress' | 'completed' | 'incomplete';

/**
 * Conversation 对象。
 *
 * API：Create/Retrieve/Update Conversation。
 * 说明：表示一段可持久保存的会话上下文。
 */
export interface Conversation {
  /** Conversation ID。API：Conversations。说明：后续 item 管理和 Responses 调用引用该 ID。 */
  id: string;
  /** 对象类型。API：Conversations。说明：固定为 `conversation`。 */
  object: 'conversation';
  /** 创建时间。API：Conversations。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 元数据。API：Conversations。说明：开发者自定义键值对。 */
  metadata?: Metadata | null;
}

/**
 * 创建 Conversation 参数。
 *
 * API：`POST /v1/conversations`。
 * 说明：可创建空会话，也可附带最多 20 个初始 items。
 */
export interface ConversationCreateParams {
  /** 初始 items。API：Create Conversation。说明：创建时加入会话上下文的消息或工具项。 */
  items?: Array<ConversationItemInput>;
  /** 元数据。API：Create Conversation。说明：开发者自定义键值对。 */
  metadata?: Metadata;
}

/**
 * 更新 Conversation 参数。
 *
 * API：`POST /v1/conversations/{conversation_id}`。
 * 说明：当前官方主要支持更新 metadata。
 */
export interface ConversationUpdateParams {
  /** 元数据。API：Update Conversation。说明：替换会话上的自定义键值对。 */
  metadata: Metadata;
}

/** 删除 Conversation 响应。API：Delete Conversation。说明：表示删除是否成功。 */
export interface ConversationDeleted {
  /** Conversation ID。API：Delete Conversation。说明：被删除的会话 ID。 */
  id: string;
  /** 对象类型。API：Delete Conversation。说明：通常为 `conversation.deleted`。 */
  object: string;
  /** 删除结果。API：Delete Conversation。说明：`true` 表示已删除。 */
  deleted: boolean;
}

/**
 * Conversation 输入文本内容。
 *
 * API：Create Conversation Item。
 * 说明：作为 user/developer/system/assistant message 的文本内容片段。
 */
export interface ConversationInputTextContent {
  /** 内容类型。API：Conversation Items。说明：固定为 `input_text`。 */
  type: 'input_text';
  /** 文本。API：Conversation Items。说明：消息中的文本内容。 */
  text: string;
}

/**
 * Conversation 输出文本内容。
 *
 * API：Retrieve/List Conversation Items。
 * 说明：assistant 历史输出中可能返回的文本内容。
 */
export interface ConversationOutputTextContent {
  /** 内容类型。API：Conversation Items。说明：固定为 `output_text`。 */
  type: 'output_text';
  /** 文本。API：Conversation Items。说明：模型输出文本。 */
  text: string;
  /** 注解。API：Conversation Items。说明：引用、文件路径等附加标注。 */
  annotations?: Array<JsonObject>;
}

/** Conversation item 内容。API：Conversation Items。说明：当前 SDK 先建模常用文本内容。 */
export type ConversationItemContent = ConversationInputTextContent | ConversationOutputTextContent;

/**
 * Conversation message 输入。
 *
 * API：Create Conversation、Create Conversation Item。
 * 说明：添加到会话中的消息。
 */
export interface ConversationMessageInput {
  /** 类型。API：Conversation Items。说明：固定为 `message`。 */
  type: 'message';
  /** 角色。API：Conversation Items。说明：system/developer 指令优先级高于 user。 */
  role: ConversationMessageRole;
  /** 内容。API：Conversation Items。说明：可以是纯文本或内容数组。 */
  content: string | Array<ConversationItemContent>;
}

/** Conversation item 输入。API：Create Conversation Item。说明：当前覆盖 message，其他工具项可后续扩展。 */
export type ConversationItemInput = ConversationMessageInput;

/**
 * Conversation Item 对象。
 *
 * API：Retrieve/List/Create Conversation Item。
 * 说明：表示会话中的单个消息或工具调用项。
 */
export interface ConversationItem {
  /** 类型。API：Conversation Items。说明：例如 `message`。 */
  type: string;
  /** Item ID。API：Conversation Items。说明：用于 retrieve/delete 单个 item。 */
  id: string;
  /** 状态。API：Conversation Items。说明：completed 表示该 item 已完成。 */
  status?: ConversationItemStatus;
  /** 角色。API：Conversation Items。说明：message item 会包含该字段。 */
  role?: ConversationMessageRole;
  /** 内容。API：Conversation Items。说明：message item 的内容数组。 */
  content?: Array<ConversationItemContent>;
}

/**
 * 创建 Conversation Item 参数。
 *
 * API：`POST /v1/conversations/{conversation_id}/items`。
 * 说明：向已有会话追加一个 item。
 */
export interface ConversationItemCreateParams {
  /** Item。API：Create Conversation Item。说明：要加入会话的消息或工具项。 */
  item: ConversationItemInput;
}

/**
 * Conversation Item 列表参数。
 *
 * API：`GET /v1/conversations/{conversation_id}/items`。
 * 说明：支持游标分页和 include 扩展字段。
 */
export interface ConversationItemListParams extends CursorPageParams {
  /** Include 字段。API：List Conversation Items。说明：请求额外返回工具调用细节。 */
  include?: Array<ConversationItemInclude>;
}

/**
 * 获取 Conversation Item 参数。
 *
 * API：`GET /v1/conversations/{conversation_id}/items/{item_id}`。
 * 说明：支持 include 扩展字段。
 */
export interface ConversationItemRetrieveParams {
  /** Include 字段。API：Retrieve Conversation Item。说明：请求额外返回工具调用细节。 */
  include?: Array<ConversationItemInclude>;
}

/** Conversation Item 列表响应。API：List Conversation Items。说明：列表元素为 Conversation Item。 */
export type ConversationItemListResponse = OpenAIListResponse<ConversationItem>;
