import type { VectorHit } from '../vector/VectorModels';
import type {
  ChatMessageRole,
  TavernScope,
} from '../contracts/PublicContracts';

/**
 * 表示RAG 检索中单条聊天消息，包含角色和内容。
 */
export interface RagChatMessage {
  /**
   * 消息角色（user/assistant/system），标识消息发送者身份。
   */
  role: ChatMessageRole;
  /**
   * 内容。
   */
  content: string;
}

/**
 * 描述调用RAG 检索能力时需要传入的参数。
 */
export interface RagRetrievalInput {
  /**
   * 查询条件。
   */
  query: string;
  /**
   * 查询文本的向量嵌入，用于语义相似度检索。
   */
  queryEmbedding: Array<number>;
  /**
   * collection 标识列表。
   */
  collectionIds: Array<string>;
  /**
   * 返回的 top-K 命中数上限，控制检索结果的条目数量。
   */
  topK: number;
  /**
   * 检索结果的最小相似度阈值，低于该值的命中将被过滤。
   */
  scoreThreshold: number;
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 用于注入检索结果的 Prompt 模板，拼入最终上下文。
   */
  promptTemplate: string;
}

/**
 * 表示检索命中的向量片段，包含来源和得分信息。
 */
export interface RagChunk {
  /**
   * collection 标识。
   */
  collectionId: string;
  /**
   * vector 标识。
   */
  vectorId: string;
  /**
   * document 标识。
   */
  documentId: string;
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 文本内容。
   */
  text: string;
  /**
   * 相似度得分，由余弦相似度计算得出。
   */
  score: number;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 表示RAG 检索完成后的最终结果，包含命中的片段、得分和生成的 prompt 文本。
 */
export interface RagRetrievalResult {
  /**
   * 查询条件。
   */
  query: string;
  /**
   * 检索命中的文本片段列表，按相关性排序。
   */
  chunks: Array<RagChunk>;
  /**
   * 各命中片段对应的相似度得分列表，与 chunks 按索引对应。
   */
  scores: Array<number>;
  /**
   * 生成的 Prompt 文本，将命中片段按模板拼入后供模型使用。
   */
  promptText: string;
  /**
   * 检索过程的调试追踪信息，用于排查检索链路问题。
   */
  debugTrace: string;
}

/**
 * 表示RAG 检索事件发布时携带的数据结构，供外部订阅者消费。
 */
export interface RagRetrievedPayload {
  /**
   * 查询条件。
   */
  query: string;
  /**
   * 检索命中的文本片段列表，按相关性排序。
   */
  chunks: Array<RagChunk>;
  /**
   * 各命中片段对应的相似度得分列表，与 chunks 按索引对应。
   */
  scores: Array<number>;
  /**
   * 生成的 Prompt 文本，将命中片段按模板拼入后供模型使用。
   */
  promptText: string;
}

/**
 * 包装单条向量检索命中结果，为RAG 层提供适配后的数据视图。
 */
export interface RagVectorHitSource {
  /**
   * 向量检索的命中结果，包含集合标识、向量记录和相似度得分。
   */
  hit: VectorHit;
}
