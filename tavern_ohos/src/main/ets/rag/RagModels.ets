import type { VectorHit } from '../vector/VectorModels';

/**
 * 描述RAG 检索模块在运行时交换的数据结构。
 */
export interface RagChatMessage {
  /**
   * 消息角色（如 user、assistant、system），用于标识消息来源以便提取用户查询。
   */
  role: string;
  /**
   * 消息文本内容，RAG 查询构建时从此字段提取用户输入或对话上下文。
   */
  content: string;
}

/**
 * 描述调用RAG 检索能力时需要传入的参数。
 */
export interface RagRetrievalInput {
  /**
   * 查询文本，用于构建 RAG 检索的输入。可为用户最后一条消息或近期对话摘要。
   */
  query: string;
  /**
   * 查询文本的向量嵌入表示，由 Embedding 模块生成，用于向量相似度检索。
   */
  queryEmbedding: Array<number>;
  /**
   * 检索范围：目标向量集合的标识列表，限定搜索仅在指定的集合内进行。
   */
  collectionIds: Array<string>;
  /**
   * 检索返回的最相似结果数，控制检索精度和后续拼接的上下文量。
   */
  topK: number;
  /**
   * 向量相似度过滤阈值，低于该值的命中将被丢弃，用于保证检索结果的相关性。
   */
  scoreThreshold: number;
  /**
   * 检索作用域（如 global、character 等），用于配合向量数据库的作用域过滤机制。
   */
  scope: string;
  /**
   * 将检索结果拼接后使用的 Prompt 模板，其中 ${text} 会被替换为拼接文本——用于生成最终的 RAG 提示词。
   */
  promptTemplate: string;
}

/**
 * 描述RAG 检索模块在运行时交换的数据结构。
 */
export interface RagChunk {
  /**
   * 该文本片段所属向量集合标识，用于追踪检索结果来源。
   */
  collectionId: string;
  /**
   * 该文本片段在向量库中的标识，用于关联原始向量记录。
   */
  vectorId: string;
  /**
   * 该文本片段所属文档标识，用于关联该片段的原始文档来源。
   */
  documentId: string;
  /**
   * 作用域标识，用于标识该片段的业务归属范围（如角色或全局）。
   */
  scope: string;
  /**
   * 检索命中的文本内容，将被拼接后注入生成 Prompt。
   */
  text: string;
  /**
   * 与查询向量的相似度得分，用于排序和过滤检索结果。
   */
  score: number;
  /**
   * 关联的元数据 JSON 字符串，携带该片段的额外属性供调用方使用。
   */
  metadataJson: string;
}

/**
 * 描述RAG 检索操作完成后返回给调用方的结果。
 */
export interface RagRetrievalResult {
  /**
   * 原始查询文本，用于关联检索输入与输出。
   */
  query: string;
  /**
   * 检索命中的文本片段列表，按相似度降序排列。
   */
  chunks: Array<RagChunk>;
  /**
   * 各命中片段对应的相似度得分列表，与 chunks 按索引一一对应。
   */
  scores: Array<number>;
  /**
   * 将命中文本拼接后应用 Prompt 模板生成的最终提示文本，用于注入 LLM 请求。
   */
  promptText: string;
  /**
   * 调试追踪信息，格式为 "collectionId:vectorId:score" 的换行拼接——用于调试和日志。
   */
  debugTrace: string;
}

/**
 * 描述RAG 检索事件发布时携带的数据结构。
 */
export interface RagRetrievedPayload {
  /**
   * 原始查询文本，用于通知监听方本次检索的输入。
   */
  query: string;
  /**
   * 检索命中的文本片段列表副本，用于通知监听方检索到的上下文内容。
   */
  chunks: Array<RagChunk>;
  /**
   * 各命中片段对应的相似度得分列表副本，用于通知监听方检索结果的质量。
   */
  scores: Array<number>;
  /**
   * 应用 Prompt 模板后生成的提示文本，用于通知监听方最终注入 LLM 的内容。
   */
  promptText: string;
}

/**
 * 描述RAG 检索模块在运行时交换的数据结构。
 */
export interface RagVectorHitSource {
  /**
   * 向量检索的原始命中结果，提供从 RAG 上下文访问底层向量命中数据的入口。
   */
  hit: VectorHit;
}
