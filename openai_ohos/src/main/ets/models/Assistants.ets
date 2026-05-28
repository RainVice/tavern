import type { CursorPageParams, JsonObject, Metadata, OpenAIListResponse, OpenAIModel } from './Common';

/**
 * Assistants v2 API model。
 *
 * API：`/v1/assistants`、`/v1/threads`。
 * 说明：Assistants v2 beta API，请求需带 `OpenAI-Beta: assistants=v2`。
 */

export type AssistantToolType = 'code_interpreter' | 'file_search' | 'function';
export type ThreadMessageRole = 'user' | 'assistant';
export type RunStatus = 'queued' | 'in_progress' | 'requires_action' | 'cancelling' | 'cancelled' | 'failed' | 'completed' | 'incomplete' | 'expired';
export type RunStepStatus = 'in_progress' | 'cancelled' | 'failed' | 'completed' | 'expired';

/** Assistant tool。API：Assistants。说明：助手可用工具。 */
export interface AssistantTool {
  /** 类型。API：Assistants。说明：code_interpreter、file_search 或 function。 */
  type: AssistantToolType;
  /** Function 定义。API：Assistants。说明：type=function 时使用。 */
  function?: JsonObject;
}

/** Tool resources。API：Assistants/Threads。说明：工具可访问文件或 vector store。 */
export interface AssistantToolResources {
  /** Code interpreter resources。API：Assistants/Threads。说明：包含 file_ids。 */
  code_interpreter?: JsonObject;
  /** File search resources。API：Assistants/Threads。说明：包含 vector_store_ids 或 vector_stores。 */
  file_search?: JsonObject;
}

/** 创建 Assistant 参数。API：Create Assistant。说明：创建 v2 assistant。 */
export interface AssistantCreateParams {
  /** 模型。API：Create Assistant。说明：assistant 默认模型。 */
  model: OpenAIModel;
  /** 名称。API：Create Assistant。说明：可选展示名。 */
  name?: string | null;
  /** 描述。API：Create Assistant。说明：可选说明。 */
  description?: string | null;
  /** 指令。API：Create Assistant。说明：系统指令。 */
  instructions?: string | null;
  /** 工具。API：Create Assistant。说明：可用工具列表。 */
  tools?: Array<AssistantTool>;
  /** 工具资源。API：Create Assistant。说明：工具可访问文件或向量库。 */
  tool_resources?: AssistantToolResources | null;
  /** 元数据。API：Create Assistant。说明：开发者自定义键值对。 */
  metadata?: Metadata | null;
}

/** 更新 Assistant 参数。API：Modify Assistant。说明：更新 assistant 配置，所有字段均可选。 */
export interface AssistantUpdateParams {
  /** 模型。API：Modify Assistant。说明：assistant 默认模型。 */
  model?: OpenAIModel;
  /** 名称。API：Modify Assistant。说明：可选展示名。 */
  name?: string | null;
  /** 描述。API：Modify Assistant。说明：可选说明。 */
  description?: string | null;
  /** 指令。API：Modify Assistant。说明：系统指令。 */
  instructions?: string | null;
  /** 工具。API：Modify Assistant。说明：可用工具列表。 */
  tools?: Array<AssistantTool>;
  /** 工具资源。API：Modify Assistant。说明：工具可访问文件或向量库。 */
  tool_resources?: AssistantToolResources | null;
  /** 元数据。API：Modify Assistant。说明：开发者自定义键值对。 */
  metadata?: Metadata | null;
  /** 温度。API：Modify Assistant。说明：采样温度 0-2。 */
  temperature?: number | null;
  /** top_p。API：Modify Assistant。说明：核采样概率。 */
  top_p?: number | null;
  /** 推理力度。API：Modify Assistant。说明：控制推理模型推理时间。 */
  reasoning_effort?: string | null;
  /** 响应格式。API：Modify Assistant。说明：指定输出格式。 */
  response_format?: JsonObject | null;
}

/** Assistant 对象。API：Assistants。说明：v2 assistant 配置。 */
export interface AssistantObject {
  id: string;
  object: 'assistant';
  created_at: number;
  name?: string | null;
  description?: string | null;
  model: string;
  instructions?: string | null;
  tools: Array<AssistantTool>;
  tool_resources?: AssistantToolResources | null;
  metadata?: Metadata | null;
}

/** Assistant 列表参数。API：List Assistants。说明：支持分页。 */
export interface AssistantListParams extends CursorPageParams {
}

export type AssistantListResponse = OpenAIListResponse<AssistantObject>;

/** 删除 Assistant 响应。API：Delete Assistant。说明：表示删除结果。 */
export interface AssistantDeleted {
  id: string;
  object: string;
  deleted: boolean;
}

/** 创建 Thread 参数。API：Create Thread。说明：创建会话线程，可带初始 messages。 */
export interface ThreadCreateParams {
  messages?: Array<MessageCreateParams>;
  tool_resources?: AssistantToolResources | null;
  metadata?: Metadata | null;
}

/** 更新 Thread 参数。API：Modify Thread。说明：更新工具资源或 metadata。 */
export interface ThreadUpdateParams {
  tool_resources?: AssistantToolResources | null;
  metadata?: Metadata | null;
}

/** Thread 对象。API：Threads。说明：Assistants 会话线程。 */
export interface AssistantThread {
  id: string;
  object: 'thread';
  created_at: number;
  tool_resources?: AssistantToolResources | null;
  metadata?: Metadata | null;
}

export interface AssistantThreadDeleted {
  id: string;
  object: string;
  deleted: boolean;
}

/** Message attachment。API：Create Message。说明：文件和可用工具。 */
export interface MessageAttachment {
  file_id: string;
  tools?: Array<AssistantTool>;
}

/** 创建 Message 参数。API：Create Message。说明：向 thread 添加用户或助手消息。 */
export interface MessageCreateParams {
  role: ThreadMessageRole;
  content: string;
  attachments?: Array<MessageAttachment> | null;
  metadata?: Metadata | null;
}

/** 更新 Message 参数。API：Modify Message。说明：更新 metadata。 */
export interface MessageUpdateParams {
  metadata?: Metadata | null;
}

/** Message text content。API：Messages。说明：文本内容和 annotations。 */
export interface ThreadMessageText {
  value: string;
  annotations?: Array<JsonObject>;
}

/** Message content part。API：Messages。说明：当前建模 text 常用结构。 */
export interface ThreadMessageContent {
  type: string;
  text?: ThreadMessageText;
  image_file?: JsonObject;
  image_url?: JsonObject;
}

/** Thread Message 对象。API：Messages。说明：thread 中单条消息。 */
export interface ThreadMessage {
  id: string;
  object: 'thread.message';
  created_at: number;
  thread_id: string;
  role: ThreadMessageRole;
  content: Array<ThreadMessageContent>;
  attachments?: Array<MessageAttachment>;
  assistant_id?: string | null;
  run_id?: string | null;
  metadata?: Metadata | null;
}

export interface ThreadMessageListParams extends CursorPageParams {
  run_id?: string;
}

export type ThreadMessageListResponse = OpenAIListResponse<ThreadMessage>;

export interface ThreadMessageDeleted {
  id: string;
  object: string;
  deleted: boolean;
}

/** 创建 Run 参数。API：Create Run。说明：在 thread 上运行 assistant。 */
export interface RunCreateParams {
  assistant_id: string;
  model?: OpenAIModel;
  instructions?: string | null;
  additional_instructions?: string | null;
  tools?: Array<AssistantTool> | null;
  metadata?: Metadata | null;
  /** 是否启用流式事件。API：Create Run。说明：SDK 的 createStream 会自动设置为 true。 */
  stream?: boolean | null;
}

/** Create thread and run 参数。API：Create Thread and Run。说明：创建 thread 并立即运行。 */
export interface ThreadAndRunCreateParams extends RunCreateParams {
  thread?: ThreadCreateParams;
}

/** Submit tool outputs 参数。API：Submit Tool Outputs。说明：提交工具调用结果继续 run。 */
export interface RunSubmitToolOutputsParams {
  tool_outputs: Array<JsonObject>;
  /** 是否启用流式事件。API：Submit Tool Outputs。说明：SDK 的 submitToolOutputsStream 会自动设置为 true。 */
  stream?: boolean | null;
}

/** Thread Run 对象。API：Runs。说明：一次 assistant 执行。 */
export interface ThreadRun {
  id: string;
  object: 'thread.run';
  created_at: number;
  thread_id: string;
  assistant_id: string;
  status: RunStatus;
  model: string;
  instructions?: string | null;
  tools: Array<AssistantTool>;
  metadata?: Metadata | null;
  required_action?: JsonObject | null;
  last_error?: JsonObject | null;
}

export interface ThreadRunListParams extends CursorPageParams {
}

export type ThreadRunListResponse = OpenAIListResponse<ThreadRun>;

/** Run step details。API：Run Steps。说明：message_creation 或 tool_calls 详情。 */
export interface RunStepDetails {
  type: string;
  message_creation?: JsonObject;
  tool_calls?: Array<JsonObject>;
}

/** Run Step 对象。API：Run Steps。说明：run 的单步执行记录。 */
export interface RunStep {
  id: string;
  object: 'thread.run.step';
  created_at: number;
  assistant_id: string;
  thread_id: string;
  run_id: string;
  type: string;
  status: RunStepStatus;
  step_details: RunStepDetails;
  last_error?: JsonObject | null;
  metadata?: Metadata | null;
}

export interface RunStepListParams extends CursorPageParams {
}

export type RunStepListResponse = OpenAIListResponse<RunStep>;

/** Assistant stream 事件类型。API：Assistants streaming。说明：覆盖 run/message/run_step 常见增量事件和 done。 */
export type AssistantStreamEventType =
  'thread.created' |
  'thread.run.created' |
  'thread.run.queued' |
  'thread.run.in_progress' |
  'thread.run.requires_action' |
  'thread.run.completed' |
  'thread.run.failed' |
  'thread.run.cancelling' |
  'thread.run.cancelled' |
  'thread.run.expired' |
  'thread.message.created' |
  'thread.message.in_progress' |
  'thread.message.delta' |
  'thread.message.completed' |
  'thread.message.incomplete' |
  'thread.run.step.created' |
  'thread.run.step.in_progress' |
  'thread.run.step.delta' |
  'thread.run.step.completed' |
  'thread.run.step.failed' |
  'thread.run.step.cancelled' |
  'thread.run.step.expired' |
  'error' |
  'done' |
  string;

/** Thread message delta。API：Assistants streaming `thread.message.delta`。说明：消息内容增量。 */
export interface ThreadMessageDeltaObject {
  /** 对象类型。API：Assistants streaming。说明：固定为 thread.message.delta。 */
  object?: 'thread.message.delta';
  /** 增量内容。API：Assistants streaming。说明：官方返回的 delta 字段。 */
  delta?: JsonObject;
}

/** Run step delta。API：Assistants streaming `thread.run.step.delta`。说明：run step 工具调用或消息创建增量。 */
export interface RunStepDeltaObject {
  /** 对象类型。API：Assistants streaming。说明：固定为 thread.run.step.delta。 */
  object?: 'thread.run.step.delta';
  /** 增量内容。API：Assistants streaming。说明：官方返回的 delta 字段。 */
  delta?: JsonObject;
}

/** Assistant stream 数据。API：Assistants streaming。说明：不同事件会携带 run、message、step 或 delta 对象。 */
export type AssistantStreamEventData = ThreadRun | ThreadMessage | RunStep | AssistantThread | ThreadMessageDeltaObject | RunStepDeltaObject | JsonObject;

/** Assistant stream 事件。API：Assistants streaming。说明：SDK 回调中暴露完整事件名和解析后的 data。 */
export interface AssistantStreamEvent {
  /** 事件名。API：Assistants streaming。说明：来自 SSE `event:` 行。 */
  event: AssistantStreamEventType;
  /** 事件数据。API：Assistants streaming。说明：`[DONE]` 会转换为 event=done。 */
  data: AssistantStreamEventData;
}
