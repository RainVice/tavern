import type { CursorPageParams, JsonObject, Metadata, OpenAIListResponse } from './Common';

/**
 * Batch 支持的 endpoint。
 *
 * API：`POST /v1/batches`。
 * 说明：官方 batch 支持多个异步处理 endpoint；核心层保留常见核心端点。
 */
export type BatchEndpoint = '/v1/responses' | '/v1/chat/completions' | '/v1/embeddings' | '/v1/completions' | '/v1/moderations';

/**
 * 创建 Batch 请求。
 *
 * API：`POST /v1/batches`。
 * 说明：提交 JSONL 输入文件进行异步批处理。
 */
export interface BatchCreateParams {
  /**
   * 输入文件 ID。
   *
   * API：Batches。
   * 说明：必须是通过 Files API 上传且 purpose 为 `batch` 的 JSONL 文件。
   */
  input_file_id: string;

  /**
   * 批处理 endpoint。
   *
   * API：Batches。
   * 说明：JSONL 每行请求会发往该 endpoint。
   */
  endpoint: BatchEndpoint;

  /**
   * 完成窗口。
   *
   * API：Batches。
   * 说明：官方当前常用 `24h`。
   */
  completion_window: '24h';

  /**
   * 元数据。
   *
   * API：Batches。
   * 说明：用于标记业务批次。
   */
  metadata?: Metadata | null;
}

/**
 * Batch 列表请求。
 *
 * API：`GET /v1/batches`。
 * 说明：查询批处理任务列表。
 */
export interface BatchListParams extends CursorPageParams {
}

/**
 * 请求计数。
 *
 * API：Batches 响应。
 * 说明：描述批处理中请求总数和不同状态数量。
 */
export interface BatchRequestCounts {
  /**
   * 总请求数。
   *
   * API：Batches 响应。
   * 说明：输入 JSONL 行数。
   */
  total: number;

  /**
   * 已完成请求数。
   *
   * API：Batches 响应。
   * 说明：成功处理的请求数量。
   */
  completed: number;

  /**
   * 失败请求数。
   *
   * API：Batches 响应。
   * 说明：处理失败的请求数量。
   */
  failed: number;
}

/**
 * Batch 对象。
 *
 * API：`POST /v1/batches`、`GET /v1/batches/{batch_id}`、`GET /v1/batches`、`POST /v1/batches/{batch_id}/cancel`。
 * 说明：表示一个异步批处理任务。
 */
export interface BatchObject {
  /**
   * Batch ID。
   *
   * API：Batches。
   * 说明：用于 retrieve 和 cancel。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Batches。
   * 说明：固定为 `batch`。
   */
  object: 'batch';

  /**
   * endpoint。
   *
   * API：Batches。
   * 说明：该 batch 实际处理的 API endpoint。
   */
  endpoint: BatchEndpoint;

  /**
   * 错误列表。
   *
   * API：Batches。
   * 说明：批次级错误信息；单行请求错误通常写入 error file。
   */
  errors?: JsonObject | null;

  /**
   * 输入文件 ID。
   *
   * API：Batches。
   * 说明：提交时使用的 JSONL 文件。
   */
  input_file_id: string;

  /**
   * 完成窗口。
   *
   * API：Batches。
   * 说明：例如 `24h`。
   */
  completion_window: string;

  /**
   * 状态。
   *
   * API：Batches。
   * 说明：表示批次生命周期状态。
   */
  status: 'validating' | 'failed' | 'in_progress' | 'finalizing' | 'completed' | 'expired' | 'cancelling' | 'cancelled';

  /**
   * 输出文件 ID。
   *
   * API：Batches。
   * 说明：成功结果 JSONL 文件 ID。
   */
  output_file_id?: string | null;

  /**
   * 错误文件 ID。
   *
   * API：Batches。
   * 说明：失败结果 JSONL 文件 ID。
   */
  error_file_id?: string | null;

  /**
   * 创建时间。
   *
   * API：Batches。
   * 说明：Unix 秒级时间戳。
   */
  created_at: number;

  /**
   * 进行中时间。
   *
   * API：Batches。
   * 说明：进入 `in_progress` 状态的时间。
   */
  in_progress_at?: number | null;

  /**
   * 过期时间。
   *
   * API：Batches。
   * 说明：批次过期的时间。
   */
  expires_at?: number | null;

  /**
   * 完成时间。
   *
   * API：Batches。
   * 说明：批次完成的时间。
   */
  completed_at?: number | null;

  /**
   * 失败时间。
   *
   * API：Batches。
   * 说明：批次失败的时间。
   */
  failed_at?: number | null;

  /**
   * 请求计数。
   *
   * API：Batches。
   * 说明：统计 total、completed、failed。
   */
  request_counts?: BatchRequestCounts;

  /**
   * 元数据。
   *
   * API：Batches。
   * 说明：创建请求传入的业务键值。
   */
  metadata?: Metadata | null;
}

/**
 * Batch 列表响应。
 *
 * API：`GET /v1/batches`。
 * 说明：返回批处理任务列表。
 */
export type BatchListResponse = OpenAIListResponse<BatchObject>;
