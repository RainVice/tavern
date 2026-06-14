import type { SearchResultType } from '../contracts/PublicContracts';

/**
 * 搜索文档中可附加的元数据键值对，用于存储文档的额外属性。
 */
export interface SearchDocumentMetadata {
  /**
   * 元数据键名，用于标识该条目的含义。
   */
  key: string;
  /**
   * 元数据键名对应的值。
   */
  value: string;
}

/**
 * 表示需要被索引的完整文档单元，包含搜索所需的所有字段与元数据。
 */
export interface SearchDocument {
  /**
   * 文档唯一标识。
   */
  id: string;
  /**
   * 文档所属领域分类，用于按范围过滤搜索结果。
   */
  domain: string;
  /**
   * 文档标题，用作搜索匹配及结果展示。
   */
  title: string;
  /**
   * 文档正文全文，用于关键词匹配与摘要生成。
   */
  body: string;
  /**
   * 文档关联的标签列表，用于按标签筛选和计分。
   */
  tags: Array<string>;
  /**
   * 文档在系统中的存储路径。
   */
  path: string;
  /**
   * 文档附加元数据列表，用于按元数据过滤索引。
   */
  metadata: Array<SearchDocumentMetadata>;
  /**
   * 文档最后更新时间戳，用于增量同步或过期判断。
   */
  updatedAt: number;
}

/**
 * 表示可参与本地过滤的实体对象，包含搜索展示与按类型筛选所需的字段。
 */
export interface SearchFilterEntity {
  /**
   * 实体唯一标识。
   */
  id: string;
  /**
   * 实体搜索结果类型，影响图标、排序及分组行为。
   */
  type: SearchResultType;
  /**
   * 实体标题，用于搜索匹配与展示。
   */
  title: string;
  /**
   * 实体正文，参与搜索关键词计分。
   */
  body: string;
  /**
   * 实体关联标签，支持按标签包含或排除过滤。
   */
  tags: Array<string>;
  /**
   * 是否被标记为收藏。
   */
  favorite: boolean;
  /**
   * 是否为群组类型实体。
   */
  group: boolean;
  /**
   * 是否为文件夹类型实体。
   */
  folder: boolean;
}

/**
 * 调用本地搜索过滤功能时需传入的参数集合。
 */
export interface SearchFilterInput {
  /**
   * 搜索关键词，用于匹配实体标题、正文与标签。
   */
  search: string;
  /**
   * 必须包含的标签列表，实体需命中其中至少一个标签。
   */
  selectedTags: Array<string>;
  /**
   * 必须排除的标签列表，包含其中任一标签的实体将被过滤掉。
   */
  excludedTags: Array<string>;
  /**
   * 是否仅返回标记为收藏的实体。
   */
  favoriteOnly: boolean;
  /**
   * 是否仅返回群组类型的实体。
   */
  groupOnly: boolean;
  /**
   * 是否仅返回文件夹类型的实体。
   */
  folderOnly: boolean;
}

/**
 * 提交给搜索索引引擎的查询条件，用于精准定位索引中文档。
 */
export interface SearchQuery {
  /**
   * 搜索关键词，用于对文档标题、正文、路径等字段进行全文匹配与计分。
   */
  text: string;
  /**
   * 按领域分类过滤，命中指定 domain 的文档才会被返回；为空时不作限制。
   */
  domains: Array<string>;
  /**
   * 要求文档必须包含的标签列表，非空时所有标签必须全部命中。
   */
  tags: Array<string>;
  /**
   * 元数据键名过滤条件，配合 metadataValue 按元数据精确筛选。
   */
  metadataKey: string;
  /**
   * 元数据值过滤条件，与 metadataKey 配合使用；为空时不校验值。
   */
  metadataValue: string;
  /**
   * 返回结果数量上限。
   */
  limit: number;
}

/**
 * 一次搜索命中记录，包含匹配到的文档摘要与相关性分数。
 */
export interface SearchHit {
  /**
   * 命中文档的唯一标识。
   */
  documentId: string;
  /**
   * 命中文档所属领域分类。
   */
  domain: string;
  /**
   * 命中文档的标题。
   */
  title: string;
  /**
   * 根据查询文本生成的匹配摘要片段。
   */
  snippet: string;
  /**
   * 相关性评分，数值越高表示匹配度越高。
   */
  score: number;
  /**
   * 命中文档在系统中的存储路径。
   */
  path: string;
  /**
   * 命中文档的标签列表。
   */
  tags: Array<string>;
  /**
   * 命中文档的附加元数据。
   */
  metadata: Array<SearchDocumentMetadata>;
}

/**
 * 搜索操作完成后的结构化结果，包含原始查询与命中文档集合。
 */
export interface SearchResult {
  /**
   * 产生该结果所使用的原始查询条件副本。
   */
  query: SearchQuery;
  /**
   * 满足条件的文档总数（不受 limit 影响）。
   */
  total: number;
  /**
   * 本次返回的命中记录列表（受 limit 截断）。
   */
  hits: Array<SearchHit>;
}

/**
 * 搜索索引完成事件负载，包含被索引的完整文档。
 */
export interface SearchIndexedPayload {
  /**
   * 已被写入索引的文档对象副本。
   */
  document: SearchDocument;
}

/**
 * 搜索索引移除事件负载，包含被移除文档的唯一标识。
 */
export interface SearchRemovedPayload {
  /**
   * 被移除文档的唯一标识。
   */
  documentId: string;
}
