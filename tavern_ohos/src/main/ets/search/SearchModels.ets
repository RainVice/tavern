/**
 * 描述搜索索引模块在运行时交换的数据结构。
 */
export interface SearchDocumentMetadata {
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * 字段值。
   */
  value: string;
}

/**
 * 描述搜索索引模块在运行时交换的数据结构。
 */
export interface SearchDocument {
  /**
   * 标识。
   */
  id: string;
  /**
   * domain 值，由当前实例内部维护。
   */
  domain: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * body 值，由当前实例内部维护。
   */
  body: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * 路径。
   */
  path: string;
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: Array<SearchDocumentMetadata>;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述搜索索引模块在运行时交换的数据结构。
 */
export interface SearchFilterEntity {
  /**
   * 标识。
   */
  id: string;
  /**
   * type 值，由当前实例内部维护。
   */
  type: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * body 值，由当前实例内部维护。
   */
  body: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * favorite 值，由当前实例内部维护。
   */
  favorite: boolean;
  /**
   * group 值，由当前实例内部维护。
   */
  group: boolean;
  /**
   * folder 值，由当前实例内部维护。
   */
  folder: boolean;
}

/**
 * 描述调用搜索索引能力时需要传入的参数。
 */
export interface SearchFilterInput {
  /**
   * search 值，由当前实例内部维护。
   */
  search: string;
  /**
   * selected Tags 列表，由当前实例内部维护。
   */
  selectedTags: Array<string>;
  /**
   * excluded Tags 列表，由当前实例内部维护。
   */
  excludedTags: Array<string>;
  /**
   * favorite Only 值，由当前实例内部维护。
   */
  favoriteOnly: boolean;
  /**
   * group Only 值，由当前实例内部维护。
   */
  groupOnly: boolean;
  /**
   * folder Only 值，由当前实例内部维护。
   */
  folderOnly: boolean;
}

/**
 * 描述搜索索引模块在运行时交换的数据结构。
 */
export interface SearchQuery {
  /**
   * 文本内容。
   */
  text: string;
  /**
   * domains 列表，由当前实例内部维护。
   */
  domains: Array<string>;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * metadata Key 值，由当前实例内部维护。
   */
  metadataKey: string;
  /**
   * metadata Value 值，由当前实例内部维护。
   */
  metadataValue: string;
  /**
   * limit 值，由当前实例内部维护。
   */
  limit: number;
}

/**
 * 描述搜索索引模块在运行时交换的数据结构。
 */
export interface SearchHit {
  /**
   * document 标识。
   */
  documentId: string;
  /**
   * domain 值，由当前实例内部维护。
   */
  domain: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * snippet 值，由当前实例内部维护。
   */
  snippet: string;
  /**
   * score 值，由当前实例内部维护。
   */
  score: number;
  /**
   * 路径。
   */
  path: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: Array<SearchDocumentMetadata>;
}

/**
 * 描述搜索索引操作完成后返回给调用方的结果。
 */
export interface SearchResult {
  /**
   * 查询条件。
   */
  query: SearchQuery;
  /**
   * total 值，由当前实例内部维护。
   */
  total: number;
  /**
   * hits 列表，由当前实例内部维护。
   */
  hits: Array<SearchHit>;
}

/**
 * 描述搜索索引事件发布时携带的数据结构。
 */
export interface SearchIndexedPayload {
  /**
   * document 值，由当前实例内部维护。
   */
  document: SearchDocument;
}

/**
 * 描述搜索索引事件发布时携带的数据结构。
 */
export interface SearchRemovedPayload {
  /**
   * document 标识。
   */
  documentId: string;
}
