// 向量提供商类型
export type EmbeddingProvider = 'openai' | 'ollama' | 'google' | 'cohere' | 'llamacpp' | 'vllm' | 'local_http';
// 向量请求
export interface EmbeddingRequest {
  provider: EmbeddingProvider; model: string; input: Array<string>;
  dimensions?: number;
}
// 向量结果
export interface EmbeddingResult {
  provider: EmbeddingProvider; model: string; vectors: Array<Array<number>>;
  dimensions: number; usageTokens: number;
}
// 模型元数据
export interface EmbeddingModelRecord {
  modelId: string; provider: EmbeddingProvider; modelName: string;
  dimensions: number; description: string; enabled: boolean;
}
// 各提供商请求体
export interface OpenAIEmbeddingRequest {
  model: string; input: Array<string>; encoding_format: string;
}
export interface OllamaEmbeddingRequest {
  model: string; prompt: string;
}
export interface CohereEmbeddingRequest {
  model: string; texts: Array<string>; input_type: string;
}
export interface GoogleEmbeddingPart { text: string; }
export interface GoogleEmbeddingContent { parts: Array<GoogleEmbeddingPart>; }
export interface GoogleEmbeddingRequest {
  model: string; content: GoogleEmbeddingContent;
}
// 事件
export interface EmbeddingModelRegisteredPayload { model: EmbeddingModelRecord; }
export interface EmbeddingResultPayload { result: EmbeddingResult; }
export interface EmbeddingExportData { models: Array<EmbeddingModelRecord>; }
