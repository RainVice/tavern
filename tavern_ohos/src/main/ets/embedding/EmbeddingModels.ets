/**
 * 支持的向量化服务提供商类型。
 * - openai: OpenAI Embeddings API
 * - ollama: Ollama 本地模型服务
 * - google: Google Gemini Embeddings API
 * - cohere: Cohere Embed API
 * - llamacpp: llama.cpp 内嵌向量化
 * - vllm: vLLM 推理框架
 * - local_http: 自定义 HTTP 端点
 */
export type EmbeddingProvider = 'openai' | 'ollama' | 'google' | 'cohere' | 'llamacpp' | 'vllm' | 'local_http';
/**
 * 向量化请求参数。
 */
export interface EmbeddingRequest {
  /**
   * 服务提供商类型。
   */
  provider: EmbeddingProvider; model: string; input: Array<string>;
  /**
   * 输出向量的维度数。未指定时由服务端决定。
   */
  dimensions?: number;
}

/**
 * 向量化处理结果。
 */
export interface EmbeddingResult {
  /**
   * 服务提供商类型。
   */
  provider: EmbeddingProvider; model: string; vectors: Array<Array<number>>;
  /**
   * 输出向量的维度数。
   */
  dimensions: number; usageTokens: number;
}

/**
 * 向量模型在系统中的注册记录。
 */
export interface EmbeddingModelRecord {
  /**
   * 模型唯一标识，格式为 `${provider}:${modelName}`。
   */
  modelId: string; provider: EmbeddingProvider; modelName: string;
  /**
   * 模型输出向量的维度数。
   */
  dimensions: number; description: string; enabled: boolean;
}

/**
 * OpenAI Embeddings API 的请求体结构。
 */
export interface OpenAIEmbeddingRequest {
  /**
   * 模型名称。
   */
  model: string; input: Array<string>; encoding_format: string;
}

/**
 * Ollama Embeddings API 的请求体结构。
 */
export interface OllamaEmbeddingRequest {
  /**
   * 模型名称。
   */
  model: string; prompt: string;
}

/**
 * Cohere Embed API 的请求体结构。
 */
export interface CohereEmbeddingRequest {
  /**
   * 模型名称。
   */
  model: string; texts: Array<string>; input_type: string;
}

/**
 * Google Gemini Embeddings 请求中的文本片段。
 */
export interface GoogleEmbeddingPart {
  /**
   * 文本内容。
   */
  text: string;
}

/**
 * Google Gemini Embeddings 请求中的内容容器，包含多个文本片段。
 */
export interface GoogleEmbeddingContent {
  /**
   * 文本片段列表。
   */
  parts: Array<GoogleEmbeddingPart>;
}

/**
 * Google Gemini Embeddings API 的请求体结构。
 */
export interface GoogleEmbeddingRequest {
  /**
   * 模型名称。
   */
  model: string; content: GoogleEmbeddingContent;
}

/**
 * 模型注册事件携带的数据。
 */
export interface EmbeddingModelRegisteredPayload {
  /**
   * 已注册的模型记录。
   */
  model: EmbeddingModelRecord;
}

/**
 * 向量化结果事件携带的数据。
 */
export interface EmbeddingResultPayload {
  /**
   * 向量化处理结果。
   */
  result: EmbeddingResult;
}

/**
 * Embedding 模块导出数据的结构。
 */
export interface EmbeddingExportData {
  /**
   * 所有已注册的模型记录列表。
   */
  models: Array<EmbeddingModelRecord>;
}
