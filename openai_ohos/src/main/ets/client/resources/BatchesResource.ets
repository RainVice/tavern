import type { BatchCreateParams, BatchListResponse, BatchObject } from '../../models/Batches';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { encodePathParam } from '../core/RequestUtils';

interface EmptyRequestBody {
}

/**
 * Batches 资源入口。
 *
 * API：`/v1/batches`。
 * 说明：提交和管理异步批处理任务。
 */
export interface OpenAIBatchesResource {
  /**
   * 创建 batch。
   *
   * API：`POST /v1/batches`。
   * 说明：使用 purpose 为 `batch` 的 JSONL 文件创建异步批处理。
   */
  create(params: BatchCreateParams): Promise<BatchObject>;

  /**
   * 获取 batch。
   *
   * API：`GET /v1/batches/{batch_id}`。
   * 说明：读取批处理任务状态。
   */
  retrieve(batchID: string): Promise<BatchObject>;

  /**
   * 列出 batch。
   *
   * API：`GET /v1/batches`。
   * 说明：返回批处理任务列表。
   */
  list(): Promise<BatchListResponse>;

  /**
   * 取消 batch。
   *
   * API：`POST /v1/batches/{batch_id}/cancel`。
   * 说明：请求取消进行中的批处理任务。
   */
  cancel(batchID: string): Promise<BatchObject>;
}

export class BatchesResource implements OpenAIBatchesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: BatchCreateParams): Promise<BatchObject> {
    const body = await this.client.post('/batches', params);
    return JSON.parse(body) as BatchObject;
  }

  async retrieve(batchID: string): Promise<BatchObject> {
    const body = await this.client.get('/batches/' + encodePathParam(batchID));
    return JSON.parse(body) as BatchObject;
  }

  async list(): Promise<BatchListResponse> {
    const body = await this.client.get('/batches');
    return JSON.parse(body) as BatchListResponse;
  }

  async cancel(batchID: string): Promise<BatchObject> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post('/batches/' + encodePathParam(batchID) + '/cancel', requestBody);
    return JSON.parse(body) as BatchObject;
  }
}
