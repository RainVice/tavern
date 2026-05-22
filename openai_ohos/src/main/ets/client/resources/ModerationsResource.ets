import type { ModerationCreateParams, ModerationCreateResponse } from '../../models/Moderations';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';

/**
 * Moderations 资源入口。
 *
 * API：`POST /v1/moderations`。
 * 说明：审核文本或图片内容是否命中安全类别。
 */
export interface OpenAIModerationsResource {
  /**
   * 创建 moderation。
   *
   * API：`POST /v1/moderations`。
   * 说明：返回每条输入的分类结果和分数。
   */
  create(params: ModerationCreateParams): Promise<ModerationCreateResponse>;
}

export class ModerationsResource implements OpenAIModerationsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: ModerationCreateParams): Promise<ModerationCreateResponse> {
    const body = await this.client.post('/moderations', params);
    return JSON.parse(body) as ModerationCreateResponse;
  }
}
