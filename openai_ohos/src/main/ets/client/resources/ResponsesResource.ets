import type { ResponseCreateParams, ResponseObject } from '../../models/Responses';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';

/**
 * Responses 资源入口。
 *
 * API：`POST /v1/responses`。
 * 说明：官方推荐的新一代文本、多模态和工具调用统一入口。
 */
export interface OpenAIResponsesResource {
  /**
   * 创建 Response。
   *
   * API：`POST /v1/responses`。
   * 说明：发送输入给模型并返回完整非流式响应对象。
   */
  create(params: ResponseCreateParams): Promise<ResponseObject>;

  /**
   * 获取 Response。
   *
   * API：`GET /v1/responses/{response_id}`。
   * 说明：用于读取已存储或后台运行的 response。
   */
  retrieve(responseID: string): Promise<ResponseObject>;

  /**
   * 删除 Response。
   *
   * API：`DELETE /v1/responses/{response_id}`。
   * 说明：删除已存储的 response。
   */
  delete(responseID: string): Promise<void>;

  /**
   * 取消后台 Response。
   *
   * API：`POST /v1/responses/{response_id}/cancel`。
   * 说明：仅对 `background: true` 创建的 response 有效。
   */
  cancel(responseID: string): Promise<ResponseObject>;
}

interface EmptyRequestBody {
}

export class ResponsesResource implements OpenAIResponsesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: ResponseCreateParams): Promise<ResponseObject> {
    const body = await this.client.post('/responses', params);
    return JSON.parse(body) as ResponseObject;
  }

  async retrieve(responseID: string): Promise<ResponseObject> {
    const body = await this.client.get('/responses/' + responseID);
    return JSON.parse(body) as ResponseObject;
  }

  async delete(responseID: string): Promise<void> {
    await this.client.delete('/responses/' + responseID);
  }

  async cancel(responseID: string): Promise<ResponseObject> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post('/responses/' + responseID + '/cancel', requestBody);
    return JSON.parse(body) as ResponseObject;
  }
}
