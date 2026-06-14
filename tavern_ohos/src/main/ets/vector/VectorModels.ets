/**
 * 描述调用向量检索能力时需要传入的参数。
 */
export interface VectorCollectionCreateParams {
  /**
   * 集合唯一标识，用于创建和查询集合的键值，在向量检索系统中唯一确定一个集合。
   */
  id: string;
  /**
   * 向量化服务提供商名称（如 openai、local 等），用于记录向量生成的来源，供后续重新向量化匹配。
   */
  provider: string;
  /**
   * 向量化使用的模型名称，用于记录向量生成的模型来源，供后续重新向量化匹配。
   */
  model: string;
  /**
   * 向量维度，所有存入的向量必须匹配此维度，由使用的向量化模型决定，用于向量相似度计算的维度一致性校验。
   */
  dimension: number;
  /**
   * 元数据 JSON 字符串，保存附加信息，如配置参数或分类标签等扩展属性。
   */
  metadataJson: string;
}

/**
 * 描述向量集合的持久化记录，用于在文件系统和内存中维护每个集合的元数据。
 */
export interface VectorCollectionRecord {
  /**
   * 数据模式版本号，用于集合数据格式的兼容性检测和迁移。
   */
  schemaVersion: number;
  /**
   * 集合唯一标识，在跨模块引用和查询时作为定位依据。
   */
  id: string;
  /**
   * 向量化服务提供商名称，记录向量的来源服务。
   */
  provider: string;
  /**
   * 向量化模型名称，记录向量的生成模型。
   */
  model: string;
  /**
   * 向量维度，所有向量的嵌入长度必须匹配，用于向量相似度计算的维度一致性校验。
   */
  dimension: number;
  /**
   * 集合数据在文件系统中的存储路径，用于读写集合的元数据和向量数据文件。
   */
  path: string;
  /**
   * 元数据 JSON 字符串，保存用户自定义的附加属性。
   */
  metadataJson: string;
  /**
   * 集合创建时间戳（毫秒），用于集合生命周期追踪。
   */
  createdAt: number;
  /**
   * 集合最后更新时间戳（毫秒），用于记录集合最近修改时间。
   */
  updatedAt: number;
}

/**
 * 描述单个向量记录的持久化结构，包含文本、嵌入向量和关联标识。
 */
export interface VectorRecord {
  /**
   * 向量记录唯一标识，用于向量记录的查找、更新和删除操作。
   */
  id: string;
  /**
   * 关联的文档或资源标识，用于按文档维度批量删除向量，如删除某个文档的所有向量。
   */
  documentId: string;
  /**
   * 向量所属的作用域（如 chat、character 等），用于按作用域过滤查询结果。
   */
  scope: string;
  /**
   * 向量关联的文本内容，即被向量化的原始文本，在语义检索时用于展示原文。
   */
  text: string;
  /**
   * 向量嵌入数据（浮点数数组），由向量化模型生成，用于余弦相似度计算和语义匹配。
   */
  embedding: Array<number>;
  /**
   * 元数据 JSON 字符串，保存用户自定义的附加信息，如来源消息 ID 等。
   */
  metadataJson: string;
  /**
   * 向量创建时间戳（毫秒），用于记录向量的入库时间。
   */
  createdAt: number;
  /**
   * 向量最后更新时间戳（毫秒），用于记录向量的最近修改时间。
   */
  updatedAt: number;
}

/**
 * 描述向量检索的命中结果，供调用方查看匹配到的向量和相似度得分。
 */
export interface VectorHit {
  /**
   * 命中所属的集合标识，用于追溯命中结果来自哪个集合。
   */
  collectionId: string;
  /**
   * 命中的向量记录，包含文本内容和嵌入数据等完整信息。
   */
  vector: VectorRecord;
  /**
   * 余弦相似度得分（0-1 之间），反映查询向量与该向量的语义匹配程度，用于结果排序。
   */
  score: number;
}

/**
 * 描述执行向量语义查询时传入的参数，用于多集合检索和结果过滤。
 */
export interface VectorQueryParams {
  /**
   * 要查询的目标集合标识列表，支持跨集合检索。
   */
  collectionIds: Array<string>;
  /**
   * 查询的向量嵌入数据，用于与集合中的向量计算相似度。
   */
  embedding: Array<number>;
  /**
   * 返回的 top-k 命中数上限，用于控制查询结果的数量。
   */
  topK: number;
  /**
   * 相似度得分阈值，低于此值的命中将被过滤，用于排除低相关度的结果。
   */
  scoreThreshold: number;
  /**
   * 按作用域过滤（可选），仅返回匹配 scope 的向量，用于缩小查询范围如只查特定角色的向量。
   */
  scope: string;
}

/**
 * 描述向量查询操作完成后返回给调用方的结果，包含按得分排序的命中列表。
 */
export interface VectorQueryResult {
  /**
   * 查询命中的向量列表，按得分降序排列，供调用方获取语义匹配的内容。
   */
  hits: Array<VectorHit>;
}

/**
 * 描述向量插入或更新事件发布时携带的数据结构，供事件订阅方在向量变更时执行后续处理。
 */
export interface VectorUpsertPayload {
  /**
   * 发生变更的集合标识，供事件订阅方识别哪个集合被操作。
   */
  collectionId: string;
  /**
   * 被插入或更新的向量记录，供事件订阅方获取变更详情。
   */
  vector: VectorRecord;
}

/**
 * 描述向量删除事件发布时携带的数据结构，供事件订阅方在向量移除时执行后续处理。
 */
export interface VectorDeletedPayload {
  /**
   * 发生删除操作的集合标识，供事件订阅方识别哪个集合被操作。
   */
  collectionId: string;
  /**
   * 被删除的向量记录 ID 列表，供事件订阅方对被删除的向量进行后续处理。
   */
  deletedIds: Array<string>;
}
