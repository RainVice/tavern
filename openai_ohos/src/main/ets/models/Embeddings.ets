import type { OpenAIModel } from './Common';

/**
 * Embeddings 常见模型 ID。
 *
 * API：`POST /v1/embeddings`。
 * 说明：请求字段仍允许任意字符串，以兼容后续新 embedding 模型。
 */
export type EmbeddingModel = OpenAIModel | 'text-embedding-3-small' | 'text-embedding-3-large' | 'text-embedding-ada-002';

/**
 * Embedding 输入。
 *
 * API：`POST /v1/embeddings` 的 `input` 字段。
 * 说明：可传单条文本、多条文本、单条 token 数组或多条 token 数组。
 */
export type EmbeddingInput = string | Array<string> | Array<number> | Array<Array<number>>;

/**
 * 创建 Embedding 请求。
 *
 * API：`POST /v1/embeddings`。
 * 说明：用于把文本转换为向量。
 */
export interface EmbeddingCreateParams {
  /**
   * 输入内容。
   *
   * API：Embeddings。
   * 说明：不能是空字符串；批量输入会返回同等数量的 embedding。
   */
  input: EmbeddingInput;

  /**
   * 模型 ID。
   *
   * API：Embeddings。
   * 说明：常用 `text-embedding-3-small` 或 `text-embedding-3-large`。
   */
  model: EmbeddingModel;

  /**
   * 输出维度。
   *
   * API：Embeddings。
   * 说明：仅部分 `text-embedding-3` 及后续模型支持降维输出。
   */
  dimensions?: number;

  /**
   * 向量编码格式。
   *
   * API：Embeddings。
   * 说明：`float` 返回数字数组，`base64` 返回 base64 编码向量。
   */
  encoding_format?: 'float' | 'base64';

  /**
   * 终端用户标识。
   *
   * API：Embeddings。
   * 说明：用于 OpenAI 滥用检测，建议传匿名 ID。
   */
  user?: string;
}

/**
 * Embedding 对象。
 *
 * API：Embeddings 响应。
 * 说明：表示某条输入对应的向量。
 */
export interface Embedding {
  /**
   * 对象类型。
   *
   * API：Embeddings 响应。
   * 说明：固定为 `embedding`。
   */
  object: 'embedding';

  /**
   * 向量数组或 base64 字符串。
   *
   * API：Embeddings 响应。
   * 说明：由请求的 `encoding_format` 决定。
   */
  embedding: Array<number> | string;

  /**
   * 输入索引。
   *
   * API：Embeddings 响应。
   * 说明：用于把响应向量映射回原始输入顺序。
   */
  index: number;
}

/**
 * Embeddings token 用量。
 *
 * API：Embeddings 响应。
 * 说明：统计 embedding 请求消耗的 token。
 */
export interface EmbeddingUsage {
  /**
   * 输入 token 数。
   *
   * API：Embeddings 响应。
   * 说明：所有输入文本合计的 token 数。
   */
  prompt_tokens: number;

  /**
   * 总 token 数。
   *
   * API：Embeddings 响应。
   * 说明：embedding API 通常等于 `prompt_tokens`。
   */
  total_tokens: number;
}

/**
 * 创建 Embedding 响应。
 *
 * API：`POST /v1/embeddings`。
 * 说明：包含向量列表、模型和用量。
 */
export interface CreateEmbeddingResponse {
  /**
   * 对象类型。
   *
   * API：Embeddings 响应。
   * 说明：固定为 `list`。
   */
  object: 'list';

  /**
   * embedding 列表。
   *
   * API：Embeddings 响应。
   * 说明：顺序与输入顺序一致。
   */
  data: Array<Embedding>;

  /**
   * 模型 ID。
   *
   * API：Embeddings 响应。
   * 说明：实际使用的 embedding 模型。
   */
  model: string;

  /**
   * token 用量。
   *
   * API：Embeddings 响应。
   * 说明：用于成本统计。
   */
  usage: EmbeddingUsage;
}
