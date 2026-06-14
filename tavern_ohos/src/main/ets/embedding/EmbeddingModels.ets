/**
 * 向量提供商类型 —— 标识支持的文本嵌入服务商，决定请求体格式和 API 调用方式。
 */
export type EmbeddingProvider = 'openai' | 'ollama' | 'google' | 'cohere' | 'llamacpp' | 'vllm' | 'local_http';
/**
 * 向量计算请求的通用格式，包含提供商、模型、输入文本和可选维度，由调用方在发起向量计算前组装。
 */
export interface EmbeddingRequest {
  /** 向量计算使用的提供商，决定使用哪个构建方法生成具体格式的请求体（如 buildOpenAIRequest / buildOllamaRequest）。 */
  provider: EmbeddingProvider;
  /** 使用的模型名称，应与注册时 modelName 一致。 */
  model: string;
  /** 待生成向量表示的一个或多个输入文本，每个文本对应一个输出向量。 */
  input: Array<string>;
  /** 输出的向量维度（各提供商支持不同，部分模型可配置），如不指定则使用模型默认维度。 */
  dimensions?: number;
}
/**
 * 向量计算的结果，包含提供商、模型、向量数据和 Token 用量，由 saveResult 发布给订阅方。
 */
export interface EmbeddingResult {
  /** 结果对应的提供商，与请求中的 provider 一致。 */
  provider: EmbeddingProvider;
  /** 结果对应的模型名称，与请求中的 model 一致。 */
  model: string;
  /** 每个输入文本生成的向量数组，向量维度由模型决定（如 OpenAI text-embedding-3-small 为 1536 维）。 */
  vectors: Array<Array<number>>;
  /** 输出向量的维度数，可通过 checkDimension 与注册记录进行一致性校验。 */
  dimensions: number;
  /** 本次请求消耗的 Token 数，用于用量统计和成本控制。 */
  usageTokens: number;
}
/**
 * 注册的向量模型元数据记录，由 registerModel 创建，用于管理各提供商的嵌入模型配置。
 */
export interface EmbeddingModelRecord {
  /** 模型的唯一标识（格式为 "provider:modelName"），如 "openai:text-embedding-3-small"。 */
  modelId: string;
  /** 模型所属的提供商，影响构建请求体时的格式选择。 */
  provider: EmbeddingProvider;
  /** 模型名称，如 "text-embedding-3-small"、"nomic-embed-text"。 */
  modelName: string;
  /** 模型输出的向量维度，用于向量的维度一致性和列族匹配检查。 */
  dimensions: number;
  /** 模型的功能描述，记录模型的来源信息和使用场景说明。 */
  description: string;
  /** 模型是否已启用，决定该模型是否可被用于向量计算。 */
  enabled: boolean;
}
/**
 * 发送给 OpenAI API 的向量计算请求体格式，由 buildOpenAIRequest 构建。
 */
export interface OpenAIEmbeddingRequest {
  /** 模型名称（如 "text-embedding-3-small"），标识使用的嵌入模型。 */
  model: string;
  /** 待处理的一个或多个输入文本，API 会为每个文本返回一个向量。 */
  input: Array<string>;
  /** 编码格式（固定为 "float"），指定返回向量的数据类型。 */
  encoding_format: string;
}
/**
 * 发送给 Ollama API 的向量计算请求体格式，由 buildOllamaRequest 构建。
 */
export interface OllamaEmbeddingRequest {
  /** 模型名称（如 "nomic-embed-text"），标识使用的嵌入模型。 */
  model: string;
  /** 待处理的提示文本，Ollama API 每次调用只支持单个文本。 */
  prompt: string;
}
/**
 * 发送给 Cohere API 的向量计算请求体格式，由 buildCohereRequest 构建。
 */
export interface CohereEmbeddingRequest {
  /** 模型名称（如 "embed-english-v3.0"），标识使用的嵌入模型。 */
  model: string;
  /** 待处理的一个或多个文本，API 会为每个文本返回一个向量。 */
  texts: Array<string>;
  /** 输入类型（如 "search_document" / "search_query"），Cohere API 需要此参数区分检索场景。 */
  input_type: string;
}
/**
 * Google Embedding 请求中的内容片段，包含单个文本块。
 */
export interface GoogleEmbeddingPart {
  /** 文本内容，作为向量计算的一个输入片段。 */
  text: string;
}
/**
 * Google Embedding 请求中的内容结构，包含一个或多个片段，由 buildGoogleRequest 构建。
 */
export interface GoogleEmbeddingContent {
  /** 文本片段列表，每个片段为一个输入文本，组合成完整的输入内容。 */
  parts: Array<GoogleEmbeddingPart>;
}
/**
 * 发送给 Google API 的向量计算请求体格式，由 buildGoogleRequest 构建。
 */
export interface GoogleEmbeddingRequest {
  /** 模型名称（如 "text-embedding-004"），标识使用的嵌入模型。 */
  model: string;
  /** 待处理的内容结构，包含文本片段列表。 */
  content: GoogleEmbeddingContent;
}
/**
 * 模型注册时发布的事件负载，由 registerModel 触发，通知订阅方（如 UI 模型列表）有新模型可用。
 */
export interface EmbeddingModelRegisteredPayload {
  /** 新注册的模型记录，供订阅方更新模型列表。 */
  model: EmbeddingModelRecord;
}
/**
 * 向量计算完成并保存结果时发布的事件负载，由 saveResult 触发，供订阅方（如向量数据库、检索模块）接收计算结果。
 */
export interface EmbeddingResultPayload {
  /** 向量计算结果，包含各输入文本对应的向量数组和用量信息。 */
  result: EmbeddingResult;
}
/**
 * Embedding 模块完整状态导出格式，用于备份或迁移，包含所有已注册模型记录的快照。
 */
export interface EmbeddingExportData {
  /** 所有已注册的模型记录列表，由 exportData 生成，供 importData 恢复使用。 */
  models: Array<EmbeddingModelRecord>;
}
