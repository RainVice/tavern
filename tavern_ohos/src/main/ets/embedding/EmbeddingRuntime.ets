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
   * 事件总线。
   */
  private events: EventBus;
  /**
   * models 列表，由当前实例内部维护。
   */
  private models: Map<string, EmbeddingModelRecord> = new Map();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events = events; }

  /**
   * 注册Model 值，使其可被后续运行时流程使用。

   * @param modelName 模型名称。
   */
  registerModel(provider: EmbeddingProvider, modelName: string, dimensions: number, description: string): EmbeddingModelRecord {
    // model 标识。
    const modelId = `${provider}:${modelName}`;
    const record: EmbeddingModelRecord = { modelId, provider, modelName, dimensions, description, enabled: true };
    this.models.set(modelId, this.copyModel(record));
    this.events.publish<EmbeddingModelRegisteredPayload>('embedding.model.registered', { model: this.copyModel(record) });
    return this.copyModel(record);
  }

  /**
   * 读取指定Model，不存在时抛出错误。
   * @param modelId 目标模型标识。
   * @returns 更新或读取后的记录副本。
   */
  getModel(modelId: string): EmbeddingModelRecord {
    // 模型名称。
    const model = this.models.get(modelId);
    if (model === undefined) { throw new Error(`Embedding 模型未找到: ${modelId}`); }
    return this.copyModel(model);
  }

  /**
   * 读取Models列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 删除模型。
   * @param modelId 模型标识。
   */
  removeModel(modelId: string): void {
    this.getModel(modelId);
    this.models.delete(modelId);
  }

  /**
   * 检查Dimension是否满足当前规则。
   * @param modelId 目标模型标识。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  checkDimension(modelId: string, actualDimensions: number): boolean {
    // 模型名称。
    const model = this.getModel(modelId);
    return model.dimensions === actualDimensions;
  }

  /**
   * 根据入参构建Open AIRequest 值，仅生成数据结构，不直接执行外部请求。
   * @param model 模型名称。
   * @param input 待处理的输入对象。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  buildOpenAIRequest(model: string, input: Array<string>): OpenAIEmbeddingRequest {
    return { model, input, encoding_format: 'float' };
  }

  /**
   * 根据入参构建Ollama Request 值，仅生成数据结构，不直接执行外部请求。
   * @param model 模型名称。

   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildOllamaRequest(model: string, prompt: string): OllamaEmbeddingRequest {
    return { model, prompt };
  }

  /**
   * 根据入参构建Cohere Request 值，仅生成数据结构，不直接执行外部请求。
   * @param model 模型名称。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  buildCohereRequest(model: string, texts: Array<string>): CohereEmbeddingRequest {
    return { model, texts, input_type: 'search_document' };
  }

  /**
   * 根据入参构建Google Request 值，仅生成数据结构，不直接执行外部请求。
   * @param model 模型名称。
   * @param text 文本内容。
   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildGoogleRequest(model: string, text: string): GoogleEmbeddingRequest {
    const part: GoogleEmbeddingPart = { text: text };
    const content: GoogleEmbeddingContent = { parts: [part] };
    return { model: model, content: content };
  }

  /**
   * 保存结果并发布事件。
   * @param result 处理结果。
   */
  saveResult(result: EmbeddingResult): void {
    this.events.publish<EmbeddingResultPayload>('embedding.result', { result: this.copyResult(result) });
  }

  // 导出
  exportData(): EmbeddingExportData { return { models: this.listModels() }; }

  /**
   * 导入。
   * @param data 数据内容。
   */
  importData(data: EmbeddingExportData): void {
    for (let i = 0; i < data.models.length; i++) {
      // 模型名称。
      const model = this.copyModel(data.models[i]);
      this.models.set(model.modelId, model);
    }
  }

  /**
   * 复制Model 值，避免外部修改内部状态。
   * @param model 模型名称。
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
   * 复制Result 值，避免外部修改内部状态。
   * @param result 返回结果。
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
   * 复制Vectors 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyVectors(vectors: Array<Array<number>>): Array<Array<number>> {
    const copied = new Array<Array<number>>();
    for (let index = 0; index < vectors.length; index++) {
      copied.push(vectors[index].slice());
    }
    return copied;
  }
}
