/**
 * 模型提供商
 */
export interface ModelProvider {
  id: string;
  name: string;
  baseUrl: string;
  apiKey: string;
  modelDefinitions: ModelDefinition[];
}

/**
 * 模型定义
 */
export interface ModelDefinition {
  modelId: string;
}