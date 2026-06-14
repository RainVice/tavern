// 向量提供商类型
export type EmbeddingProvider = 'openai' | 'ollama' | 'google' | 'cohere' | 'llamacpp' | 'vllm' | 'local_http';
// 向量请求
export interface EmbeddingRequest {
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: EmbeddingProvider; model: string; input: Array<string>;
  /**
   * dimensions 列表，由当前实例内部维护。
   */
  dimensions?: number;
}
// 向量结果
export interface EmbeddingResult {
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: EmbeddingProvider; model: string; vectors: Array<Array<number>>;
  /**
   * dimensions 列表，由当前实例内部维护。
   */
  dimensions: number; usageTokens: number;
}
// 模型元数据
export interface EmbeddingModelRecord {
  /**
   * model 标识。
   */
  modelId: string; provider: EmbeddingProvider; modelName: string;
  /**
   * dimensions 列表，由当前实例内部维护。
   */
  dimensions: number; description: string; enabled: boolean;
}
// 各提供商请求体
export interface OpenAIEmbeddingRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string; input: Array<string>; encoding_format: string;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface OllamaEmbeddingRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string; prompt: string;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface CohereEmbeddingRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string; texts: Array<string>; input_type: string;
}
/**
 * 描述Embedding模块在运行时交换的数据结构。
 */
export interface GoogleEmbeddingPart {
  /**
   * 文本内容。
   */
  text: string;
}
/**
 * 描述Embedding模块在运行时交换的数据结构。
 */
export interface GoogleEmbeddingContent {
  /**
   * parts 列表。
   */
  parts: Array<GoogleEmbeddingPart>;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface GoogleEmbeddingRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string; content: GoogleEmbeddingContent;
}
// 事件
export interface EmbeddingModelRegisteredPayload {
  /**
   * 模型记录。
   */
  model: EmbeddingModelRecord;
}
/**
 * 描述Embedding事件发布时携带的数据结构。
 */
export interface EmbeddingResultPayload {
  /**
   * 处理结果。
   */
  result: EmbeddingResult;
}
/**
 * 描述Embedding模块在运行时交换的数据结构。
 */
export interface EmbeddingExportData {
  /**
   * 模型列表。
   */
  models: Array<EmbeddingModelRecord>;
}
