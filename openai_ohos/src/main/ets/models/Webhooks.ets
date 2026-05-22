import type { JsonObject } from './Common';

/**
 * Webhook 事件类型。
 *
 * API：Webhook Events。
 * 说明：覆盖官方当前列出的 response、batch、fine-tuning、eval 和 realtime SIP 来电事件；仍允许字符串兼容后续新增事件。
 */
export type OpenAIWebhookEventType =
  'response.completed' |
  'response.cancelled' |
  'response.failed' |
  'response.incomplete' |
  'batch.completed' |
  'batch.cancelled' |
  'batch.expired' |
  'batch.failed' |
  'fine_tuning.job.succeeded' |
  'fine_tuning.job.failed' |
  'fine_tuning.job.cancelled' |
  'eval.run.succeeded' |
  'eval.run.failed' |
  'eval.run.canceled' |
  'realtime.call.incoming' |
  string;

/**
 * Webhook 通用 ID 载荷。
 *
 * API：response/batch/fine-tuning/eval webhook events。
 * 说明：多数事件的 `data` 只包含相关资源 ID，例如 response ID、batch ID 或 fine-tuning job ID。
 */
export interface OpenAIWebhookIDData {
  /**
   * 资源 ID。
   *
   * API：Webhook Events。
   * 说明：事件关联的资源 ID，例如 `resp_...`、`batch_...`、`ftjob_...`、`evalrun_...`。
   */
  id: string;
}

/**
 * SIP header。
 *
 * API：`realtime.call.incoming` webhook event。
 * 说明：OpenAI 收到 SIP 来电后，会把 SIP INVITE 中的部分 header 放入事件数据。
 */
export interface OpenAIWebhookSipHeader {
  /**
   * Header 名称。
   *
   * API：`realtime.call.incoming`。
   * 说明：例如 `From`、`To`、`Call-ID` 或 `Content-Type`。
   */
  name: string;

  /**
   * Header 值。
   *
   * API：`realtime.call.incoming`。
   * 说明：原始 SIP header 的字符串值。
   */
  value: string;
}

/**
 * Realtime SIP 来电事件载荷。
 *
 * API：`realtime.call.incoming`。
 * 说明：服务端可使用 `call_id` 连接 Realtime sideband WebSocket，并读取 SIP headers 做业务路由。
 */
export interface OpenAIWebhookRealtimeCallIncomingData {
  /**
   * 来电 ID。
   *
   * API：`realtime.call.incoming`。
   * 说明：用于建立对应 Realtime 会话控制连接的 call ID。
   */
  call_id: string;

  /**
   * SIP headers。
   *
   * API：`realtime.call.incoming`。
   * 说明：来自 SIP INVITE 的 header 列表。
   */
  sip_headers: Array<OpenAIWebhookSipHeader>;
}

/**
 * Webhook 事件基础结构。
 *
 * API：Webhook Events。
 * 说明：所有 OpenAI webhook 事件都使用 `event` 外层对象，包含事件 ID、类型、创建时间和数据。
 */
export interface OpenAIWebhookEventBase<TData> {
  /**
   * 事件 ID。
   *
   * API：Webhook Events。
   * 说明：事件唯一标识，可用于日志追踪；幂等推荐优先使用请求头 `webhook-id`。
   */
  id: string;

  /**
   * 事件类型。
   *
   * API：Webhook Events。
   * 说明：例如 `response.completed`、`batch.failed`、`realtime.call.incoming`。
   */
  type: OpenAIWebhookEventType;

  /**
   * 创建时间。
   *
   * API：Webhook Events。
   * 说明：Unix 秒级时间戳。
   */
  created_at: number;

  /**
   * 事件数据。
   *
   * API：Webhook Events。
   * 说明：不同事件类型的数据结构不同。
   */
  data: TData;

  /**
   * 对象类型。
   *
   * API：Webhook Events。
   * 说明：官方事件对象通常为 `event`。
   */
  object?: 'event' | string;
}

/**
 * Realtime SIP 来电 webhook 事件。
 *
 * API：`realtime.call.incoming`。
 * 说明：收到 SIP 来电时触发。
 */
export interface OpenAIWebhookRealtimeCallIncomingEvent
  extends OpenAIWebhookEventBase<OpenAIWebhookRealtimeCallIncomingData> {
  type: 'realtime.call.incoming';
}

/**
 * 通用资源 ID webhook 事件。
 *
 * API：response/batch/fine-tuning/eval webhook events。
 * 说明：适用于 `data` 只有 `id` 的官方事件。
 */
export interface OpenAIWebhookResourceEvent extends OpenAIWebhookEventBase<OpenAIWebhookIDData> {
}

/**
 * 未知或未来新增 webhook 事件。
 *
 * API：Webhook Events。
 * 说明：保留动态 `data`，避免官方新增事件时 SDK 立刻失效。
 */
export interface OpenAIWebhookGenericEvent extends OpenAIWebhookEventBase<JsonObject> {
}

/**
 * OpenAI webhook 事件。
 *
 * API：Webhook Events。
 * 说明：SDK `client.webhooks.parse()` 和 `client.webhooks.unwrap()` 返回该联合类型。
 */
export type OpenAIWebhookEvent =
  OpenAIWebhookRealtimeCallIncomingEvent |
  OpenAIWebhookResourceEvent |
  OpenAIWebhookGenericEvent;

/**
 * Webhook 请求头。
 *
 * API：Webhook signature verification。
 * 说明：OpenAI webhook 使用 Standard Webhooks 头：`webhook-id`、`webhook-timestamp`、`webhook-signature`。
 */
export interface OpenAIWebhookHeaders {
  /**
   * Webhook 投递 ID。
   *
   * API：Webhook signature verification。
   * 说明：对应 HTTP header `webhook-id`，可作为幂等键去重重复投递。
   */
  webhookId?: string;

  /**
   * Webhook 时间戳。
   *
   * API：Webhook signature verification。
   * 说明：对应 HTTP header `webhook-timestamp`，参与签名校验，通常为 Unix 秒级时间戳字符串。
   */
  webhookTimestamp?: string;

  /**
   * Webhook 签名。
   *
   * API：Webhook signature verification。
   * 说明：对应 HTTP header `webhook-signature`，格式类似 `v1,<base64-signature>`，可包含多个空格分隔的签名值。
   */
  webhookSignature?: string;
}
