import type { VectorHit } from '../vector/VectorModels';
import type {
  ChatMessageRole,
  TavernScope,
} from '../contracts/PublicContracts';

/**
 * 描述RAG 检索模块在运行时交换的数据结构。
 */
export interface RagChatMessage {
  /**
   * role 值，由当前实例内部维护。
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
   * query Embedding 值，由当前实例内部维护。
   */
  queryEmbedding: Array<number>;
  /**
   * collection 标识列表。
   */
  collectionIds: Array<string>;
  /**
   * top K 值，由当前实例内部维护。
   */
  topK: number;
  /**
   * score Threshold 值，由当前实例内部维护。
   */
  scoreThreshold: number;
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * prompt Template 值，由当前实例内部维护。
   */
  promptTemplate: string;
}

/**
 * 描述RAG 检索模块在运行时交换的数据结构。
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
   * score 值，由当前实例内部维护。
   */
  score: number;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 描述RAG 检索操作完成后返回给调用方的结果。
 */
export interface RagRetrievalResult {
  /**
   * 查询条件。
   */
  query: string;
  /**
   * chunks 列表，由当前实例内部维护。
   */
  chunks: Array<RagChunk>;
  /**
   * scores 列表，由当前实例内部维护。
   */
  scores: Array<number>;
  /**
   * prompt Text 值，由当前实例内部维护。
   */
  promptText: string;
  /**
   * debug Trace 值，由当前实例内部维护。
   */
  debugTrace: string;
}

/**
 * 描述RAG 检索事件发布时携带的数据结构。
 */
export interface RagRetrievedPayload {
  /**
   * 查询条件。
   */
  query: string;
  /**
   * chunks 列表，由当前实例内部维护。
   */
  chunks: Array<RagChunk>;
  /**
   * scores 列表，由当前实例内部维护。
   */
  scores: Array<number>;
  /**
   * prompt Text 值，由当前实例内部维护。
   */
  promptText: string;
}

/**
 * 描述RAG 检索模块在运行时交换的数据结构。
 */
export interface RagVectorHitSource {
  /**
   * hit 值，由当前实例内部维护。
   */
  hit: VectorHit;
}
