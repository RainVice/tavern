import type { Completion, CompletionCreateParams } from '../../models/Completions';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';

/**
 * Legacy Completions 资源入口。
 *
 * API：`POST /v1/completions`。
 * 说明：兼容旧式 prompt completion，用于旧项目和 batch endpoint。
 */
export interface OpenAICompletionsResource {
  /**
   * 创建 completion。
   *
   * API：`POST /v1/completions`。
   * 说明：发送 prompt 并返回旧式文本补全结果。
   */
  create(params: CompletionCreateParams): Promise<Completion>;
}

export class CompletionsResource implements OpenAICompletionsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: CompletionCreateParams): Promise<Completion> {
    const body = await this.client.post('/completions', params);
    return JSON.parse(body) as Completion;
  }
}
