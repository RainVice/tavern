import type { ModelDeleted, ModelListResponse, ModelObject } from '../../models/Models';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import type { OpenAIRequestSettings } from '../core/Types';

/**
 * Models 资源入口。
 *
 * API：`GET /v1/models`。
 * 说明：与官方 SDK 的 `client.models.list()` 使用方式保持一致。
 */
export interface OpenAIModelsResource {
  /**
   * 请求模型列表。
   *
   * API：`GET /v1/models`。
   * 说明：返回当前 API key 可访问的模型列表。
   */
  list(options?: OpenAIRequestSettings): Promise<ModelListResponse>;

  /**
   * 获取模型。
   *
   * API：`GET /v1/models/{model}`。
   * 说明：返回指定模型的元数据。
   */
  retrieve(model: string): Promise<ModelObject>;

  /**
   * 删除模型。
   *
   * API：`DELETE /v1/models/{model}`。
   * 说明：通常只适用于可删除的 fine-tuned model。
   */
  delete(model: string): Promise<ModelDeleted>;
}

/**
 * Models 资源实现。
 *
 * API：`GET /v1/models`。
 * 说明：只关心模型 API 的 path 和响应模型，通用网络能力由 `OpenAIRequestClient` 提供。
 */
export class ModelsResource implements OpenAIModelsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(options?: OpenAIRequestSettings): Promise<ModelListResponse> {
    const body = await this.client.get('/models', undefined, options);
    return JSON.parse(body) as ModelListResponse;
  }

  async retrieve(model: string): Promise<ModelObject> {
    const body = await this.client.get('/models/' + encodeURIComponent(model));
    return JSON.parse(body) as ModelObject;
  }

  async delete(model: string): Promise<ModelDeleted> {
    const body = await this.client.delete('/models/' + encodeURIComponent(model));
    return JSON.parse(body) as ModelDeleted;
  }
}
