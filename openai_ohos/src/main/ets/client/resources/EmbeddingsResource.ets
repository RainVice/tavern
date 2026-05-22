import type { CreateEmbeddingResponse, EmbeddingCreateParams } from '../../models/Embeddings';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';

/**
 * Embeddings 资源入口。
 *
 * API：`POST /v1/embeddings`。
 * 说明：将文本转换为向量。
 */
export interface OpenAIEmbeddingsResource {
  /**
   * 创建 embedding。
   *
   * API：`POST /v1/embeddings`。
   * 说明：返回输入文本对应的向量列表和 token 用量。
   */
  create(params: EmbeddingCreateParams): Promise<CreateEmbeddingResponse>;
}

export class EmbeddingsResource implements OpenAIEmbeddingsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: EmbeddingCreateParams): Promise<CreateEmbeddingResponse> {
    const body = await this.client.post('/embeddings', params);
    return JSON.parse(body) as CreateEmbeddingResponse;
  }
}
