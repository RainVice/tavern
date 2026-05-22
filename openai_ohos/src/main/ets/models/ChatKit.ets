import type { CursorPageParams, JsonFieldValue, OpenAIListResponse } from './Common';

/**
 * ChatKit API model。
 *
 * API：`/v1/chatkit/sessions`、`/v1/chatkit/threads`。
 * 说明：ChatKit 仍是 beta API，请求需带 `OpenAI-Beta: chatkit_beta=v1`。
 */

/** ChatKit session 状态。API：ChatKit Sessions。说明：表示 session 是否可继续使用。 */
export type ChatKitSessionStatus = 'active' | 'cancelled' | 'expired' | string;

/** ChatKit thread status 类型。API：ChatKit Threads。说明：线程可处于 active、locked、closed。 */
export type ChatKitThreadStatusType = 'active' | 'locked' | 'closed';

/** ChatKit thread item 类型。API：ChatKit Thread Items。说明：当前常见为 user/assistant/tool 消息。 */
export type ChatKitThreadItemType = 'user_message' | 'assistant_message' | 'tool_call' | 'tool_result' | 'widget' | 'task' | 'task_group' | string;

/** ChatKit 内容类型。API：ChatKit Thread Items。说明：当前常见 input_text/output_text。 */
export type ChatKitContentType = 'input_text' | 'output_text' | string;

/** ChatKit workflow trace 配置。API：Create ChatKit session。说明：控制 Agent Builder workflow tracing。 */
export interface ChatKitWorkflowTracing {
  /** 是否启用 tracing。API：Create ChatKit session。说明：默认启用。 */
  enabled?: boolean;
}

/**
 * ChatKit workflow 配置。
 *
 * API：Create ChatKit session。
 * 说明：指定驱动 ChatKit session 的 workflow。
 */
export interface ChatKitWorkflow {
  /** Workflow ID。API：Create ChatKit session。说明：Agent Builder workflow 标识。 */
  id: string;
  /** Workflow 版本。API：Create ChatKit session。说明：不传则使用最新部署版本。 */
  version?: string;
  /** 状态变量。API：Create ChatKit session。说明：传给 workflow 的 primitive 变量。 */
  state_variables?: Record<string, JsonFieldValue>;
  /** Tracing 配置。API：Create ChatKit session。说明：覆盖 workflow tracing 行为。 */
  tracing?: ChatKitWorkflowTracing;
}

/** ChatKit 自动标题配置。API：Create ChatKit session。说明：控制线程标题自动生成。 */
export interface ChatKitAutomaticThreadTitling {
  /** 是否启用。API：Create ChatKit session。说明：默认启用。 */
  enabled?: boolean;
}

/** ChatKit 文件上传配置。API：Create ChatKit session。说明：控制 session 内文件上传能力。 */
export interface ChatKitFileUploadConfiguration {
  /** 是否启用上传。API：Create ChatKit session。说明：默认关闭。 */
  enabled?: boolean;
  /** 最大单文件大小。API：Create ChatKit session。说明：单位 MB。 */
  max_file_size?: number;
  /** 最大文件数。API：Create ChatKit session。说明：session 内允许上传的文件数量。 */
  max_files?: number;
}

/** ChatKit 上传策略。API：ChatKit file upload。说明：当前官方 SDK 未暴露服务端 `chatkit.files.upload` 方法。 */
export interface ChatKitUploadStrategy {
  /** 策略类型。API：ChatKit file upload。说明：frontend 表示由 ChatKit 前端完成上传，server 表示业务服务自行处理。 */
  type: 'frontend' | 'server';
  /** 策略说明。API：ChatKit file upload。说明：用于文档或业务配置展示。 */
  description?: string;
}

/** ChatKit 历史配置。API：Create ChatKit session。说明：控制历史线程可见性。 */
export interface ChatKitHistoryConfiguration {
  /** 是否启用历史。API：Create ChatKit session。说明：默认启用。 */
  enabled?: boolean;
  /** 最近线程数。API：Create ChatKit session。说明：为空表示不限制。 */
  recent_threads?: number | null;
}

/** ChatKit runtime 配置。API：Create ChatKit session。说明：控制标题、文件上传、历史能力。 */
export interface ChatKitConfiguration {
  /** 自动标题。API：Create ChatKit session。说明：控制自动生成 thread title。 */
  automatic_thread_titling?: ChatKitAutomaticThreadTitling;
  /** 文件上传。API：Create ChatKit session。说明：控制上传限制。 */
  file_upload?: ChatKitFileUploadConfiguration;
  /** 历史。API：Create ChatKit session。说明：控制历史可见性。 */
  history?: ChatKitHistoryConfiguration;
}

/** ChatKit session 过期配置。API：Create ChatKit session。说明：控制 client secret 过期时间。 */
export interface ChatKitSessionExpiresAfter {
  /** 锚点。API：Create ChatKit session。说明：当前固定 `created_at`。 */
  anchor: 'created_at';
  /** 秒数。API：Create ChatKit session。说明：从创建起多久过期。 */
  seconds: number;
}

/** ChatKit rate limit 配置。API：Create ChatKit session。说明：限制 session 请求频率。 */
export interface ChatKitRateLimits {
  /** 每分钟最大请求数。API：Create ChatKit session。说明：默认通常为 10。 */
  max_requests_per_1_minute?: number;
}

/**
 * 创建 ChatKit session 参数。
 *
 * API：`POST /v1/chatkit/sessions`。
 * 说明：创建嵌入式 ChatKit UI 使用的短期 session。
 */
export interface ChatKitSessionCreateParams {
  /** 用户 ID。API：Create ChatKit session。说明：自由字符串，用于隔离用户可访问对象。 */
  user: string;
  /** Workflow。API：Create ChatKit session。说明：驱动 ChatKit 的 Agent Builder workflow。 */
  workflow: ChatKitWorkflow;
  /** ChatKit 配置。API：Create ChatKit session。说明：覆盖 runtime 功能。 */
  chatkit_configuration?: ChatKitConfiguration;
  /** 过期策略。API：Create ChatKit session。说明：控制 session 过期。 */
  expires_after?: ChatKitSessionExpiresAfter;
  /** Rate limits。API：Create ChatKit session。说明：覆盖 session 请求限流。 */
  rate_limits?: ChatKitRateLimits;
}

/**
 * ChatKit session 对象。
 *
 * API：Create/Cancel ChatKit session。
 * 说明：包含客户端使用的 ChatKit secret。
 */
export interface ChatKitSession {
  /** Session ID。API：ChatKit Sessions。说明：用于 cancel session。 */
  id?: string;
  /** 对象类型。API：ChatKit Sessions。说明：通常为 `chatkit.session`。 */
  object?: 'chatkit.session';
  /** 客户端密钥。API：ChatKit Sessions。说明：前端初始化 ChatKit 使用。 */
  client_secret: string;
  /** 过期时间。API：ChatKit Sessions。说明：Unix 秒级时间戳。 */
  expires_at: number;
  /** Workflow。API：ChatKit Sessions。说明：实际使用的 workflow 配置。 */
  workflow: ChatKitWorkflow;
  /** 用户 ID。API：ChatKit Sessions。说明：拥有该 session 的 end user。 */
  user?: string;
  /** 状态。API：ChatKit Sessions。说明：active、cancelled、expired 等。 */
  status?: ChatKitSessionStatus;
  /** Rate limits。API：ChatKit Sessions。说明：实际限流配置。 */
  rate_limits?: ChatKitRateLimits;
  /** 便捷每分钟请求数。API：ChatKit Sessions。说明：官方响应可能直接返回。 */
  max_requests_per_1_minute?: number;
  /** 取消时间。API：Cancel ChatKit session。说明：Unix 秒级时间戳。 */
  cancelled_at?: number;
  /** ChatKit 配置。API：ChatKit Sessions。说明：实际 runtime 配置。 */
  chatkit_configuration?: ChatKitConfiguration;
  /** 文件上传配置。API：ChatKit Sessions。说明：官方响应可能展开为独立字段。 */
  file_upload?: ChatKitSessionFileUpload;
}

/** ChatKit session 实际文件上传限制。API：ChatKit Sessions。说明：表示服务端接受后的上传开关和限制。 */
export interface ChatKitSessionFileUpload {
  /** 是否启用上传。API：ChatKit Sessions。说明：false 表示当前 session 不接受用户上传。 */
  enabled: boolean;
  /** 最大单文件大小。API：ChatKit Sessions。说明：单位 MB；null 表示使用服务端默认。 */
  max_file_size: number | null;
  /** 最大文件数。API：ChatKit Sessions。说明：null 表示使用服务端默认。 */
  max_files: number | null;
}

/** ChatKit thread 状态。API：ChatKit Threads。说明：active 无 reason，locked/closed 可有 reason。 */
export interface ChatKitThreadStatus {
  /** 状态类型。API：ChatKit Threads。说明：active、locked、closed。 */
  type: ChatKitThreadStatusType;
  /** 原因。API：ChatKit Threads。说明：locked/closed 时可能返回。 */
  reason?: string | null;
}

/** ChatKit 内容片段。API：ChatKit Thread Items。说明：渲染消息文本。 */
export interface ChatKitThreadItemContent {
  /** 类型。API：ChatKit Thread Items。说明：input_text 或 output_text。 */
  type: ChatKitContentType;
  /** 文本。API：ChatKit Thread Items。说明：消息文本。 */
  text: string;
}

/** ChatKit 附件。API：ChatKit Thread Items。说明：用户消息可包含文件附件。 */
export interface ChatKitThreadItemAttachment {
  /** 附件 ID。API：ChatKit Thread Items。说明：附件标识。 */
  id: string;
  /** 附件类型。API：ChatKit Thread Items。说明：常见为 image 或 file。 */
  type?: 'image' | 'file';
  /** MIME 类型。API：ChatKit Thread Items。说明：附件内容类型。 */
  mime_type?: string;
  /** 名称。API：ChatKit Thread Items。说明：原始显示名称。 */
  name?: string;
  /** 预览 URL。API：ChatKit Thread Items。说明：前端 inline 预览。 */
  preview_url?: string;
}

/** ChatKit response output text 文件注解来源。API：ChatKit Thread Items。说明：指向输出文本引用的上传文件。 */
export interface ChatKitResponseOutputTextFileSource {
  /** 来源类型。API：ChatKit annotations。说明：固定为 file。 */
  type: 'file';
  /** 文件名。API：ChatKit annotations。说明：用于 UI 展示和引用定位。 */
  filename: string;
}

/** ChatKit response output text 文件注解。API：ChatKit Thread Items。说明：表示输出文本中引用了某个文件。 */
export interface ChatKitResponseOutputTextFileAnnotation {
  /** 注解类型。API：ChatKit annotations。说明：固定为 file。 */
  type: 'file';
  /** 文件来源。API：ChatKit annotations。说明：包含文件名等 metadata。 */
  source: ChatKitResponseOutputTextFileSource;
}

/** ChatKit response output text 注解。API：ChatKit Thread Items。说明：后续可扩展非文件注解。 */
export type ChatKitResponseOutputTextAnnotation = ChatKitResponseOutputTextFileAnnotation;

/** ChatKit 输出文本。API：ChatKit Thread Items。说明：assistant 输出中的文本和注解。 */
export interface ChatKitResponseOutputText {
  /** 内容类型。API：ChatKit Thread Items。说明：通常为 output_text。 */
  type: 'output_text';
  /** 文本。API：ChatKit Thread Items。说明：实际展示给用户的输出。 */
  text: string;
  /** 注解。API：ChatKit Thread Items。说明：可引用上传文件等外部对象。 */
  annotations?: Array<ChatKitResponseOutputTextAnnotation>;
}

/** ChatKit thread item。API：ChatKit Thread Items。说明：线程里的消息或工具项。 */
export interface ChatKitThreadItem {
  /** Item ID。API：ChatKit Thread Items。说明：线程项标识。 */
  id: string;
  /** 对象类型。API：ChatKit Thread Items。说明：固定 `chatkit.thread_item`。 */
  object: 'chatkit.thread_item';
  /** 类型。API：ChatKit Thread Items。说明：user_message、assistant_message 等。 */
  type: ChatKitThreadItemType;
  /** 内容。API：ChatKit Thread Items。说明：可渲染文本内容。 */
  content?: Array<ChatKitThreadItemContent>;
  /** 附件。API：ChatKit Thread Items。说明：用户上传文件。 */
  attachments?: Array<ChatKitThreadItemAttachment>;
}

/** ChatKit thread 对象。API：ChatKit Threads。说明：代表一段 ChatKit 对话。 */
export interface ChatKitThread {
  /** Thread ID。API：ChatKit Threads。说明：获取 items、删除 thread 使用。 */
  id: string;
  /** 对象类型。API：ChatKit Threads。说明：固定 `chatkit.thread`。 */
  object: 'chatkit.thread';
  /** 创建时间。API：ChatKit Threads。说明：Unix 秒级时间戳。 */
  created_at?: number;
  /** 标题。API：ChatKit Threads。说明：可由自动标题生成。 */
  title?: string | null;
  /** 状态。API：ChatKit Threads。说明：active、locked、closed。 */
  status?: ChatKitThreadStatus;
  /** 用户 ID。API：ChatKit Threads。说明：所属 end user。 */
  user?: string;
  /** Items。API：Retrieve ChatKit thread。说明：retrieve 响应可能内联最近 items。 */
  items?: ChatKitThreadItemListResponse;
}

/** ChatKit thread 列表参数。API：List ChatKit threads。说明：支持 user 过滤和游标分页。 */
export interface ChatKitThreadListParams extends CursorPageParams {
  /** 用户 ID。API：List ChatKit threads。说明：过滤属于某个用户的 threads。 */
  user?: string;
}

/** ChatKit thread 列表响应。API：List ChatKit threads。说明：列表元素为 ChatKit thread。 */
export type ChatKitThreadListResponse = OpenAIListResponse<ChatKitThread>;

/** ChatKit thread item 列表参数。API：List ChatKit thread items。说明：支持游标分页。 */
export interface ChatKitThreadItemListParams extends CursorPageParams {
}

/** ChatKit thread item 列表响应。API：List ChatKit thread items。说明：列表元素为 ChatKit thread item。 */
export type ChatKitThreadItemListResponse = OpenAIListResponse<ChatKitThreadItem>;

/** 删除 ChatKit thread 响应。API：Delete ChatKit thread。说明：表示 thread 删除结果。 */
export interface ChatKitThreadDeleted {
  /** Thread ID。API：Delete ChatKit thread。说明：被删除的 thread ID。 */
  id: string;
  /** 对象类型。API：Delete ChatKit thread。说明：通常为 `chatkit.thread.deleted`。 */
  object: string;
  /** 删除结果。API：Delete ChatKit thread。说明：`true` 表示已删除。 */
  deleted: boolean;
}
