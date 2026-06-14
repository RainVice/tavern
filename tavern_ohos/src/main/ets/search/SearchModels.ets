/**
 * 描述搜索索引模块在运行时交换的数据结构。
 * 用于为 SearchDocument 提供键值对形式的额外信息，可在元数据搜索中按 key/value 进行匹配。
 */
export interface SearchDocumentMetadata {
  /**
   * 元数据键名，用于在按元数据搜索（searchMetadata）时作为筛选条件 key，
   * 也用于索引和展示文档的附加属性。
   */
  key: string;
  /**
   * 元数据字段值，与 key 配合使用，在 searchMetadata 中按指定键名的值进行精确匹配。
   */
  value: string;
}

/**
 * 描述搜索索引模块在运行时交换的数据结构。
 * 代表被索引的一条文档记录，由 SearchRuntime.upsertDocument 写入索引，
 * 供全文搜索（search、searchText）和元数据搜索（searchMetadata）使用。
 */
export interface SearchDocument {
  /**
   * 文档标识，在索引中作为唯一键，用于 upsertDocument 覆盖写入和 removeDocument 移除操作。
   */
  id: string;
  /**
   * 所属领域，在搜索时通过 query.domains 进行领域限定，用于按领域隔离搜索结果（如人物、聊天记录等）。
   */
  domain: string;
  /**
   * 文档标题，在匹配过程中被赋予最高权重（5分），同时出现在 SearchHit 中供结果展示使用。
   */
  title: string;
  /**
   * 文档正文内容，在匹配过程中被赋予中等权重（2分），同时也是 SearchHit.snippet 摘要的原始来源。
   */
  body: string;
  /**
   * 文档关联标签列表，在按标签搜索（searchByTag）和全文搜索时作为匹配字段（权重3分），也用于按标签筛选。
   */
  tags: Array<string>;
  /**
   * 文档路径，指向文件存储中的具体位置，在 SearchHit 中传递以供 UI 跳转或文件读取使用。
   */
  path: string;
  /**
   * 文档元数据列表，在按元数据搜索（searchMetadata）或全文搜索时作为附加匹配字段（权重1分）。
   */
  metadata: Array<SearchDocumentMetadata>;
  /**
   * 文档最近更新的时间戳（毫秒），用于排序或在搜索结果中标识文档的新鲜程度。
   */
  updatedAt: number;
}

/**
 * 描述搜索索引模块在运行时交换的数据结构。
 * 代表 UI 侧可搜索/筛选的实体对象，由 filterEntities 进行多条件匹配和评分排序。
 */
export interface SearchFilterEntity {
  /**
   * 过滤实体的唯一标识，用于在筛选结果中唯一确定该实体。
   */
  id: string;
  /**
   * 实体类型（如角色、群组等），在 filterEntities 中通过 filter.groupOnly/filter.folderOnly 进行类型筛选。
   */
  type: string;
  /**
   * 实体标题，在 filterEntities 评分体系中权重最高（5分），也用于结果排序时的字母顺序。
   */
  title: string;
  /**
   * 实体正文内容，在 filterEntities 评分体系中权重次之（2分），与搜索关键字进行模糊匹配。
   */
  body: string;
  /**
   * 实体关联的标签列表，在 filterEntities 中既作为选中标签匹配条件（必须全部包含），也作为排除标签的过滤条件，
   * 同时在评分体系中权重为3分。
   */
  tags: Array<string>;
  /**
   * 是否已收藏，在 filterEntities 中通过 filter.favoriteOnly 进行筛选。
   */
  favorite: boolean;
  /**
   * 是否为群组类型，在 filterEntities 中通过 filter.groupOnly 进行筛选。
   */
  group: boolean;
  /**
   * 是否为文件夹类型，在 filterEntities 中通过 filter.folderOnly 进行筛选。
   */
  folder: boolean;
}

/**
 * 描述调用搜索索引能力时需要传入的参数。
 * 由 UI 层的搜索/筛选控件收集用户输入后传入 filterEntities 方法进行多条件过滤。
 */
export interface SearchFilterInput {
  /**
   * 搜索关键字，在 filterEntities 中用于对实体标题（5分）、标签（3分）和正文（2分）进行模糊匹配。
   */
  search: string;
  /**
   * 必须包含的标签列表，在 filterEntities 中作为必要条件，实体必须包含所有选中的标签才被纳入结果。
   */
  selectedTags: Array<string>;
  /**
   * 需要排除的标签列表，在 filterEntities 中作为过滤条件，包含任一排除标签的实体将被过滤掉。
   */
  excludedTags: Array<string>;
  /**
   * 是否只显示已收藏的实体，在 filterEntities 中控制 favorite 属性的筛选开关。
   */
  favoriteOnly: boolean;
  /**
   * 是否只显示群组类型的实体，在 filterEntities 中控制 group 属性的筛选开关。
   */
  groupOnly: boolean;
  /**
   * 是否只显示文件夹类型的实体，在 filterEntities 中控制 folder 属性的筛选开关。
   */
  folderOnly: boolean;
}

/**
 * 描述搜索索引模块在运行时交换的数据结构。
 * 由外部模块调用 search、searchText、searchByTag、searchMetadata 方法时传入，
 * 定义搜索的各项限定条件和上限。
 */
export interface SearchQuery {
  /**
   * 搜索查询的文本内容，在 scoreDocument 中与文档标题（5分）、正文（2分）、路径（1分）、
   * 标签（3分）和元数据（1分）进行模糊匹配，并用于生成 SearchHit.snippet 摘要。
   */
  text: string;
  /**
   * 限定搜索的领域列表，在 matchesDomains 中逐个匹配，为空表示不限制。
   * 用于按领域隔离搜索结果（如只搜索聊天记录或只搜索角色）。
   */
  domains: Array<string>;
  /**
   * 限定搜索的标签列表，在 matchesTags 中逐个检查文档是否包含所有指定标签，为空表示不限制。
   * 匹配标签的文档在评分中额外获得 3*标签数 的加分。
   */
  tags: Array<string>;
  /**
   * 元数据筛选的键名，与 metadataValue 配合使用，在 matchesMetadata 中进行精确匹配。
   * 为空字符串表示不做元数据筛选。
   */
  metadataKey: string;
  /**
   * 元数据筛选的值，与 metadataKey 配合使用，在 matchesMetadata 中执行精确匹配。
   * 为空时只检查键名存在性。
   */
  metadataValue: string;
  /**
   * 搜索结果返回的最大条数，在 applyLimit 中截断结果列表，小于等于 0 表示不限制。
   */
  limit: number;
}

/**
 * 描述搜索索引模块在运行时交换的数据结构。
 * 代表一次搜索命中结果的单个条目，由 search 方法生成并返回给调用方（如 UI 或 ProviderRuntime）。
 */
export interface SearchHit {
  /**
   * 匹配到的文档标识，用于关联原始文档或执行后续操作（如跳转、打开文件）。
   */
  documentId: string;
  /**
   * 文档所属领域，用于在搜索结果列表中标识文档来源类型。
   */
  domain: string;
  /**
   * 文档标题，直接展示在搜索结果列表中供用户识别和点击。
   */
  title: string;
  /**
   * 搜索结果摘要文本，由 makeSnippet 从文档 body 中截取关键字上下文片段（前后各20-40字符），
   * 用于在搜索结果列表中展示匹配位置。
   */
  snippet: string;
  /**
   * 匹配得分，在 scoreDocument 中根据标题/正文/标签/路径/元数据各项累加得出，
   * 用于搜索结果排序，分数越高相关性越强。
   */
  score: number;
  /**
   * 文档路径，供 UI 跳转或文件读取时使用，指向文件存储中的具体位置。
   */
  path: string;
  /**
   * 文档标签列表，在搜索结果中展示文档的分类标签。
   */
  tags: Array<string>;
  /**
   * 文档元数据列表，在搜索结果中展示文档的附加属性信息。
   */
  metadata: Array<SearchDocumentMetadata>;
}

/**
 * 描述搜索索引操作完成后返回给调用方的结果。
 * 由 search 方法在完成搜索后构建并发布 "search.result" 事件，
 * 供宿主或其他 Runtime 监听和使用。
 */
export interface SearchResult {
  /**
   * 本次搜索使用的查询条件，冗余保存以便调用方追溯本次搜索使用的具体参数。
   */
  query: SearchQuery;
  /**
   * 匹配到的结果总数（在 applyLimit 截断前的数量），用于 UI 分页或显示总结果数。
   */
  total: number;
  /**
   * 匹配到的搜索结果条目列表，按分数降序排列且受 query.limit 限制。
   */
  hits: Array<SearchHit>;
}

/**
 * 描述搜索索引事件发布时携带的数据结构。
 * 当文档被 upsertDocument 方法写入或更新索引时，通过事件总线发送给宿主或其他模块。
 */
export interface SearchIndexedPayload {
  /**
   * 被索引的文档对象副本，宿主可监听 "search.indexed" 事件来同步 UI 或执行持久化。
   */
  document: SearchDocument;
}

/**
 * 描述搜索索引事件发布时携带的数据结构。
 * 当文档被 removeDocument 方法从索引中移除时，通过事件总线发送给宿主或其他模块。
 */
export interface SearchRemovedPayload {
  /**
   * 被移除的文档标识，宿主可监听 "search.removed" 事件来同步 UI 或清理相关缓存。
   */
  documentId: string;
}
