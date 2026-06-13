import { EventBus } from '../runtime/EventBus';
import type {
	  CohereEmbeddingRequest, EmbeddingExportData, EmbeddingModelRecord,
	  EmbeddingModelRegisteredPayload, EmbeddingProvider,
	  EmbeddingResult, EmbeddingResultPayload, GoogleEmbeddingContent,
	  GoogleEmbeddingPart, GoogleEmbeddingRequest,
  OllamaEmbeddingRequest, OpenAIEmbeddingRequest,
} from './EmbeddingModels';

export class EmbeddingRuntime {
  private events: EventBus;
  private models: Map<string, EmbeddingModelRecord> = new Map();

  constructor(events: EventBus) { this.events = events; }

  // 注册模型
  registerModel(provider: EmbeddingProvider, modelName: string, dimensions: number, description: string): EmbeddingModelRecord {
    const modelId = `${provider}:${modelName}`;
    const record: EmbeddingModelRecord = { modelId, provider, modelName, dimensions, description, enabled: true };
    this.models.set(modelId, this.copyModel(record));
    this.events.publish<EmbeddingModelRegisteredPayload>('embedding.model.registered', { model: this.copyModel(record) });
    return this.copyModel(record);
  }

  // 获取模型
  getModel(modelId: string): EmbeddingModelRecord {
    const model = this.models.get(modelId);
    if (model === undefined) { throw new Error(`Embedding 模型未找到: ${modelId}`); }
    return this.copyModel(model);
  }

  // 列出模型
  listModels(provider?: EmbeddingProvider): Array<EmbeddingModelRecord> {
    const result = new Array<EmbeddingModelRecord>();
    const values = Array.from(this.models.values());
    for (let i = 0; i < values.length; i++) {
      if (provider === undefined || values[i].provider === provider) { result.push(this.copyModel(values[i])); }
    }
    return result;
  }

  // 删除模型
  removeModel(modelId: string): void {
    this.getModel(modelId);
    this.models.delete(modelId);
  }

  // 检查维度
  checkDimension(modelId: string, actualDimensions: number): boolean {
    const model = this.getModel(modelId);
    return model.dimensions === actualDimensions;
  }

  // 构建 OpenAI 请求
  buildOpenAIRequest(model: string, input: Array<string>): OpenAIEmbeddingRequest {
    return { model, input, encoding_format: 'float' };
  }

  // 构建 Ollama 请求
  buildOllamaRequest(model: string, prompt: string): OllamaEmbeddingRequest {
    return { model, prompt };
  }

  // 构建 Cohere 请求
  buildCohereRequest(model: string, texts: Array<string>): CohereEmbeddingRequest {
    return { model, texts, input_type: 'search_document' };
  }

  // 构建 Google 请求
  buildGoogleRequest(model: string, text: string): GoogleEmbeddingRequest {
    const part: GoogleEmbeddingPart = { text: text };
    const content: GoogleEmbeddingContent = { parts: [part] };
    return { model: model, content: content };
  }

  // 保存结果并发布事件
  saveResult(result: EmbeddingResult): void {
    this.events.publish<EmbeddingResultPayload>('embedding.result', { result: this.copyResult(result) });
  }

  // 导出
  exportData(): EmbeddingExportData { return { models: this.listModels() }; }

  // 导入
  importData(data: EmbeddingExportData): void {
    for (let i = 0; i < data.models.length; i++) {
      const model = this.copyModel(data.models[i]);
      this.models.set(model.modelId, model);
    }
  }

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

  private copyResult(result: EmbeddingResult): EmbeddingResult {
    return {
      provider: result.provider,
      model: result.model,
      vectors: this.copyVectors(result.vectors),
      dimensions: result.dimensions,
      usageTokens: result.usageTokens,
    };
  }

  private copyVectors(vectors: Array<Array<number>>): Array<Array<number>> {
    const copied = new Array<Array<number>>();
    for (let index = 0; index < vectors.length; index++) {
      copied.push(vectors[index].slice());
    }
    return copied;
  }
}
