import type {
  ProviderId,
  TavernScope,
} from '../contracts/PublicContracts';

/**
 * 描述调用向量检索能力时需要传入的参数。
 */
export interface VectorCollectionCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: ProviderId;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * dimension 值，由当前实例内部维护。
   */
  dimension: number;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 描述向量检索持久化或内存索引中的一条记录。
 */
export interface VectorCollectionRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: ProviderId;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * dimension 值，由当前实例内部维护。
   */
  dimension: number;
  /**
   * 路径。
   */
  path: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述向量检索持久化或内存索引中的一条记录。
 */
export interface VectorRecord {
  /**
   * 标识。
   */
  id: string;
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
   * 向量数据，由当前实例内部维护。
   */
  embedding: Array<number>;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述向量检索模块在运行时交换的数据结构。
 */
export interface VectorHit {
  /**
   * collection 标识。
   */
  collectionId: string;
  /**
   * vector 值，由当前实例内部维护。
   */
  vector: VectorRecord;
  /**
   * score 值，由当前实例内部维护。
   */
  score: number;
}

/**
 * 描述调用向量检索能力时需要传入的参数。
 */
export interface VectorQueryParams {
  /**
   * collection 标识列表。
   */
  collectionIds: Array<string>;
  /**
   * 向量数据，由当前实例内部维护。
   */
  embedding: Array<number>;
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
}

/**
 * 描述向量检索操作完成后返回给调用方的结果。
 */
export interface VectorQueryResult {
  /**
   * hits 列表，由当前实例内部维护。
   */
  hits: Array<VectorHit>;
}

/**
 * 描述向量检索事件发布时携带的数据结构。
 */
export interface VectorUpsertPayload {
  /**
   * collection 标识。
   */
  collectionId: string;
  /**
   * vector 值，由当前实例内部维护。
   */
  vector: VectorRecord;
}

/**
 * 描述向量检索事件发布时携带的数据结构。
 */
export interface VectorDeletedPayload {
  /**
   * collection 标识。
   */
  collectionId: string;
  /**
   * deleted 标识列表。
   */
  deletedIds: Array<string>;
}
