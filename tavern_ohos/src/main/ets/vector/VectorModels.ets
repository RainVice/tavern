import type {
  ProviderId,
  TavernScope,
} from '../contracts/PublicContracts';

/**
 * 创建向量集合时需要传入的参数。
 */
export interface VectorCollectionCreateParams {
  /**
   * 集合的唯一标识符。
   */
  id: string;
  /**
   * 向量计算服务对应的 provider 标识，由运行时自动填充。
   */
  provider: ProviderId;
  /**
   * 创建集合时使用的模型名称，由运行时自动填充。
   */
  model: string;
  /**
   * 集合中向量的维度数，由运行时自动填充。
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
   * 数据格式版本号，用于迁移兼容。
   */
  schemaVersion: number;
  /**
   * 集合的唯一标识符。
   */
  id: string;
  /**
   * 向量计算服务对应的 provider 标识。
   */
  provider: ProviderId;
  /**
   * 创建集合时使用的模型名称。
   */
  model: string;
  /**
   * 集合中向量的维度数。
   */
  dimension: number;
  /**
   * 集合数据持久化存储的路径。
   */
  path: string;
  /**
   * JSON 格式的元数据字符串。
   */
  metadataJson: string;
  /**
   * 集合的创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 集合的最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 持久化或内存索引中的一条向量记录。
 */
export interface VectorRecord {
  /**
   * 向量记录的唯一标识符。
   */
  id: string;
  /**
   * 归属的文档标识符。
   */
  documentId: string;
  /**
   * 向量所属的作用域，用于查询过滤。
   */
  scope: TavernScope;
  /**
   * 向量关联的文本内容。
   */
  text: string;
  /**
   * 向量数据的数值数组，由嵌入模型生成。
   */
  embedding: Array<number>;
  /**
   * JSON 格式的元数据字符串。
   */
  metadataJson: string;
  /**
   * 记录的创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录的最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 向量检索返回的一条匹配结果，包含记录及相似度分数。
 */
export interface VectorHit {
  /**
   * 命中记录所属的集合标识。
   */
  collectionId: string;
  /**
   * 命中的向量记录。
   */
  vector: VectorRecord;
  /**
   * 与查询向量的余弦相似度分数。
   */
  score: number;
}

/**
 * 查询向量集合时需要传入的参数。
 */
export interface VectorQueryParams {
  /**
   * 要搜索的目标集合标识列表。
   */
  collectionIds: Array<string>;
  /**
   * 查询用的向量数值数组。
   */
  embedding: Array<number>;
  /**
   * 返回的 Top-K 结果数量。
   */
  topK: number;
  /**
   * 相似度分数阈值，低于此值的记录会被过滤。
   */
  scoreThreshold: number;
  /**
   * 查询作用域，用于按作用域过滤。
   */
  scope: TavernScope;
}

/**
 * 向量查询操作完成后返回的结果集。
 */
export interface VectorQueryResult {
  /**
   * 匹配的命中结果列表。
   */
  hits: Array<VectorHit>;
}

/**
 * 向量 upsert 事件发布时携带的数据载荷。
 */
export interface VectorUpsertPayload {
  /**
   * 写入操作的目标集合标识。
   */
  collectionId: string;
  /**
   * 写入的向量记录。
   */
  vector: VectorRecord;
}

/**
 * 向量删除事件发布时携带的数据载荷。
 */
export interface VectorDeletedPayload {
  /**
   * 删除操作的目标集合标识。
   */
  collectionId: string;
  /**
   * 被删除的向量记录标识列表。
   */
  deletedIds: Array<string>;
}
