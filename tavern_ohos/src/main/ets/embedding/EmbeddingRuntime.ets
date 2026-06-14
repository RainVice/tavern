import { EventBus } from '../runtime/EventBus';
import type {
	  CohereEmbeddingRequest, EmbeddingExportData, EmbeddingModelRecord,
	  EmbeddingModelRegisteredPayload, EmbeddingProvider,
	  EmbeddingResult, EmbeddingResultPayload, GoogleEmbeddingContent,
	  GoogleEmbeddingPart, GoogleEmbeddingRequest,
  OllamaEmbeddingRequest, OpenAIEmbeddingRequest,
} from './EmbeddingModels';

/**
 * 提供Embedding相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class EmbeddingRuntime {
  /**
   * 事件总线实例。
   */
  private events: EventBus;
  /**
   * 模型注册表，键为 `${provider}:${modelName}` 格式的模型标识。
   */
  private models: Map<string, EmbeddingModelRecord> = new Map();

  /**
   * 初始化运行时实例。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) { this.events = events; }

  /**
   * 注册一个向量模型，使其可被后续流程使用并发布注册事件。
   * @param provider 服务提供商类型。
   * @param modelName 模型名称。
   * @param dimensions 向量维度。
   * @param description 模型描述。
   * @returns 注册后的模型记录副本。
   */
  registerModel(provider: EmbeddingProvider, modelName: string, dimensions: number, description: string): EmbeddingModelRecord {
    // 生成模型唯一标识
    const modelId = `${provider}:${modelName}`;
    const record: EmbeddingModelRecord = { modelId, provider, modelName, dimensions, description, enabled: true };
    this.models.set(modelId, this.copyModel(record));
    this.events.publish<EmbeddingModelRegisteredPayload>('embedding.model.registered', { model: this.copyModel(record) });
    return this.copyModel(record);
  }

  /**
   * 读取指定模型记录，不存在时抛出错误。
   * @param modelId 模型标识。
   * @returns 模型记录副本。
   */
  getModel(modelId: string): EmbeddingModelRecord {
    // 从注册表中查找
    const model = this.models.get(modelId);
    if (model === undefined) { throw new Error(`Embedding 模型未找到: ${modelId}`); }
    return this.copyModel(model);
  }

  /**
   * 返回模型注册表中所有记录的副本列表，可按提供商过滤。
   * @param provider 可选，仅返回指定提供商的模型。
   * @returns 模型记录副本列表；修改返回值不会影响内部状态。
   */
  listModels(provider?: EmbeddingProvider): Array<EmbeddingModelRecord> {
    const result = new Array<EmbeddingModelRecord>();
    const values = Array.from(this.models.values());
    for (let i = 0; i < values.length; i++) {
      if (provider === undefined || values[i].provider === provider) { result.push(this.copyModel(values[i])); }
    }
    return result;
  }

  /**
   * 删除指定模型。模型不存在时抛出错误。
   * @param modelId 模型标识。
   */
  removeModel(modelId: string): void {
    this.getModel(modelId);
    this.models.delete(modelId);
  }

  /**
   * 验证实际向量维度是否与模型注册的维度一致。
   * @param modelId 模型标识。
   * @param actualDimensions 实际返回的向量维度。
   * @returns 维度一致时返回 true，否则返回 false。
   */
  checkDimension(modelId: string, actualDimensions: number): boolean {
    const model = this.getModel(modelId);
    return model.dimensions === actualDimensions;
  }

  /**
   * 构建 OpenAI Embeddings API 请求体，仅生成数据结构，不发起网络请求。
   * @param model 模型名称。
   * @param input 待编码的文本数组。
   * @returns OpenAI 格式的请求体。
   */
  buildOpenAIRequest(model: string, input: Array<string>): OpenAIEmbeddingRequest {
    return { model, input, encoding_format: 'float' };
  }

  /**
   * 构建 Ollama Embeddings 请求体，仅生成数据结构，不发起网络请求。
   * @param model 模型名称。
   * @param prompt 待编码的文本。
   * @returns Ollama 格式的请求体。
   */
  buildOllamaRequest(model: string, prompt: string): OllamaEmbeddingRequest {
    return { model, prompt };
  }

  /**
   * 构建 Cohere Embed API 请求体，仅生成数据结构，不发起网络请求。
   * @param model 模型名称。
   * @param texts 待编码的文本数组。
   * @returns Cohere 格式的请求体。
   */
  buildCohereRequest(model: string, texts: Array<string>): CohereEmbeddingRequest {
    return { model, texts, input_type: 'search_document' };
  }

  /**
   * 构建 Google Gemini Embeddings 请求体，仅生成数据结构，不发起网络请求。
   * @param model 模型名称。
   * @param text 待编码的文本。
   * @returns Google 格式的请求体（含 GoogleEmbeddingContent 包装）。
   */
  buildGoogleRequest(model: string, text: string): GoogleEmbeddingRequest {
    const part: GoogleEmbeddingPart = { text: text };
    const content: GoogleEmbeddingContent = { parts: [part] };
    return { model: model, content: content };
  }

  /**
   * 保存向量化结果并发布 embedding.result 事件。
   * @param result 向量化处理结果。
   */
  saveResult(result: EmbeddingResult): void {
    this.events.publish<EmbeddingResultPayload>('embedding.result', { result: this.copyResult(result) });
  }

  /**
   * 导出当前所有已注册的模型记录。
   * @returns 可供持久化或传输的导出数据。
   */
  exportData(): EmbeddingExportData { return { models: this.listModels() }; }

  /**
   * 从导出数据中导入模型记录，合并到当前注册表。
   * @param data 待导入的导出数据。
   */
  importData(data: EmbeddingExportData): void {
    for (let i = 0; i < data.models.length; i++) {
      const model = this.copyModel(data.models[i]);
      this.models.set(model.modelId, model);
    }
  }

  /**
   * 创建模型记录的深拷贝，防止外部修改影响内部状态。
   * @param model 待复制的模型记录。
   * @returns 独立的副本。
   */
  private copyModel(model: EmbeddingModelRecord): EmbeddingModelRecord {
    return {
      modelId: model.modelId,
      provider: model.provider,
      modelName: model.modelName,
      dimensions: model.dimensions,
      description: model.description,
      enabled: model.enabled,
    };
  }

  /**
   * 创建向量化结果的深拷贝，防止外部修改影响内部状态。
   * @param result 待复制的处理结果。
   * @returns 独立的副本。
   */
  private copyResult(result: EmbeddingResult): EmbeddingResult {
    return {
      provider: result.provider,
      model: result.model,
      vectors: this.copyVectors(result.vectors),
      dimensions: result.dimensions,
      usageTokens: result.usageTokens,
    };
  }

  /**
   * 创建多维向量数组的深拷贝，防止外部修改影响内部状态。
   * @param vectors 待复制的向量数组。
   * @returns 独立的副本。
   */
  private copyVectors(vectors: Array<Array<number>>): Array<Array<number>> {
    const copied = new Array<Array<number>>();
    for (let index = 0; index < vectors.length; index++) {
      copied.push(vectors[index].slice());
    }
    return copied;
  }
}
