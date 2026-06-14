import { EventBus } from '../runtime/EventBus';
import type {
	  CohereEmbeddingRequest, EmbeddingExportData, EmbeddingModelRecord,
	  EmbeddingModelRegisteredPayload, EmbeddingProvider,
	  EmbeddingResult, EmbeddingResultPayload, GoogleEmbeddingContent,
	  GoogleEmbeddingPart, GoogleEmbeddingRequest,
    OllamaEmbeddingRequest, OpenAIEmbeddingRequest,
} from './EmbeddingModels';

/**
 * 提供 Embedding 相关的无 UI 运行时能力，负责模型注册、请求构建和结果发布。
 * 供向量计算流程、模型管理模块和外部集成方调用，贯穿模型注册到向量结果分发的完整链路。
 */
export class EmbeddingRuntime {
  /** 事件总线，用于发布模型注册和计算结果事件，通知订阅方（如向量数据库、检索模块、UI 管理面板）状态变化。 */
  private events: EventBus;
  /** 按 modelId 索引的已注册向量模型集合，运行时核心状态，所有模型查找和校验基于此 Map。 */
  private models: Map<string, EmbeddingModelRecord> = new Map();

  /**
   * 初始化当前运行时实例。通常在应用启动或 Embedding 模块初始化时调用。
   * @param events 用于发布向量相关事件的事件总线实例，供调用方在构造时传入。
   */
  constructor(events: EventBus) { this.events = events; }

  /**
   * 注册一个新的向量模型到运行时中，并发布注册事件。供模型管理流程在配置嵌入模型时调用。
   * @param provider 模型所属的向量提供商（openai / ollama / google / cohere 等），影响后续请求体格式选择。
   * @param modelName 模型名称，如 "text-embedding-3-small"，与提供商组合构成唯一 modelId。
   * @param dimensions 模型输出向量的维度，用于后续 checkDimension 校验计算结果的维度一致性。
   * @param description 模型的功能描述，记录来源信息和使用场景说明。
   * @returns 新建模型记录的深拷贝。
   */
  registerModel(provider: EmbeddingProvider, modelName: string, dimensions: number, description: string): EmbeddingModelRecord {
    const modelId = `${provider}:${modelName}`;
    const record: EmbeddingModelRecord = { modelId, provider, modelName, dimensions, description, enabled: true };
    this.models.set(modelId, this.copyModel(record));
    this.events.publish<EmbeddingModelRegisteredPayload>('embedding.model.registered', { model: this.copyModel(record) });
    return this.copyModel(record);
  }

  /**
   * 根据标识获取已注册的模型记录。供外部模块在按 modelId 查询模型配置时调用。
   * @param modelId 模型标识（格式为 "provider:modelName"），如 "openai:text-embedding-3-small"。
   * @returns 模型记录深拷贝，不存在时抛出异常。
   */
  getModel(modelId: string): EmbeddingModelRecord {
    const model = this.models.get(modelId);
    if (model === undefined) { throw new Error(`Embedding 模型未找到: ${modelId}`); }
    return this.copyModel(model);
  }

  /**
   * 按提供商筛选并返回所有已注册模型的深拷贝列表。供 UI 模型管理界面按提供商分组展示时调用。
   * @param provider 可选，指定后只返回该提供商的模型记录；不传时返回全部模型。
   * @returns 模型记录列表副本。
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
   * 从运行时中移除指定模型。供模型管理流程在删除或更新模型配置时调用。
   * @param modelId 要移除的模型标识，移除后无法通过 getModel 或 listModels 获取。
   */
  removeModel(modelId: string): void {
    this.getModel(modelId);
    this.models.delete(modelId);
  }

  /**
   * 检查模型注册的维度是否与实际计算得到的维度一致。供向量计算流程在收到结果后校验维度合法性。
   * @param modelId 目标模型标识，必须是已注册的模型。
   * @param actualDimensions 实际计算得到的向量维度，来自 EmbeddingResult.dimensions。
   * @returns 维度一致时返回 true，否则 false。
   */
  checkDimension(modelId: string, actualDimensions: number): boolean {
    const model = this.getModel(modelId);
    return model.dimensions === actualDimensions;
  }

  /**
   * 构建 OpenAI 格式的向量请求体，不直接发起网络请求。供 OpenAIVectorService 在调用 API 前组装请求参数。
   * @param model 模型名称，如 "text-embedding-3-small"。
   * @param input 待处理的输入文本列表，每个元素对应一个输入。
   * @returns OpenAI 格式的请求数据结构。
   */
  buildOpenAIRequest(model: string, input: Array<string>): OpenAIEmbeddingRequest {
    return { model, input, encoding_format: 'float' };
  }

  /**
   * 构建 Ollama 格式的向量请求体，不直接发起网络请求。供 OllamaVectorService 在调用 API 前组装请求参数。
   * @param model 模型名称，如 "nomic-embed-text"。
   * @param prompt 待处理的提示文本，Ollama 的嵌入 API 只接受单个 prompt。
   * @returns Ollama 格式的请求数据结构。
   */
  buildOllamaRequest(model: string, prompt: string): OllamaEmbeddingRequest {
    return { model, prompt };
  }

  /**
   * 构建 Cohere 格式的向量请求体，不直接发起网络请求。供 CohereVectorService 在调用 API 前组装请求参数。
   * @param model 模型名称，如 "embed-english-v3.0"。
   * @param texts 待处理的输入文本列表，每个元素对应一个输入。
   * @returns Cohere 格式的请求数据结构。
   */
  buildCohereRequest(model: string, texts: Array<string>): CohereEmbeddingRequest {
    return { model, texts, input_type: 'search_document' };
  }

  /**
   * 构建 Google 格式的向量请求体，不直接发起网络请求。供 GoogleVectorService 在调用 API 前组装请求参数。
   * @param model 模型名称，如 "text-embedding-004"。
   * @param text 待处理的文本内容，Google 的嵌入 API 将文本包装在 content.parts 结构中。
   * @returns Google 格式的请求数据结构。
   */
  buildGoogleRequest(model: string, text: string): GoogleEmbeddingRequest {
    const part: GoogleEmbeddingPart = { text: text };
    const content: GoogleEmbeddingContent = { parts: [part] };
    return { model: model, content: content };
  }

  /**
   * 保存向量计算结果并通过事件总线发布给订阅方。供各向量服务在收到 API 响应后调用，将结果分发给检索模块或向量数据库。
   * @param result 向量计算结果，包含各输入文本的向量数组、维度和 Token 用量。
   */
  saveResult(result: EmbeddingResult): void {
    this.events.publish<EmbeddingResultPayload>('embedding.result', { result: this.copyResult(result) });
  }

  /**
   * 导出所有已注册的模型记录，用于备份或迁移。供数据备份恢复流程在保存模型配置时调用。
   * @returns 包含所有模型记录的导出数据结构，供 importData 恢复使用。
   */
  exportData(): EmbeddingExportData { return { models: this.listModels() }; }

  /**
   * 从外部数据导入模型记录，追加到当前运行时中。供数据恢复或批量配置流程在加载模型配置时调用。
   * @param data 包含模型记录列表的导入数据，通常来自之前 exportData 的输出或外部配置。
   */
  importData(data: EmbeddingExportData): void {
    for (let i = 0; i < data.models.length; i++) {
      const model = this.copyModel(data.models[i]);
      this.models.set(model.modelId, model);
    }
  }

  /**
   * 深拷贝模型记录，防止外部修改内部状态。所有对外返回 EmbeddingModelRecord 的方法均通过此方法生成副本。
   * @param model 要拷贝的模型记录。
   * @returns 模型记录的深拷贝。
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
   * 深拷贝向量结果，包含向量数据的深拷贝。供 saveResult 在发布事件前生成数据副本。
   * @param result 要拷贝的向量结果。
   * @returns 向量结果的深拷贝。
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
   * 深拷贝二维向量数组，每个内部数组独立拷贝以防外部修改。被 copyResult 在构建结果深拷贝时调用。
   * @param vectors 原始二维向量数组。
   * @returns 二维向量数组的深拷贝。
   */
  private copyVectors(vectors: Array<Array<number>>): Array<Array<number>> {
    const copied = new Array<Array<number>>();
    for (let index = 0; index < vectors.length; index++) {
      copied.push(vectors[index].slice());
    }
    return copied;
  }
}
