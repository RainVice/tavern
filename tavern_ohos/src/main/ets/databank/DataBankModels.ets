/**
 * 调用 DataBank 创建文档时所需的参数集合，由调用方在发起 createDocument 前准备。
 */
export interface DataBankDocumentCreateParams {
  /** 文档的唯一标识，供调用方指定，需要在当前 DataBank 范围内不重复。 */
  id: string;
  /** 文档所属作用域（用于逻辑分组），按 scope 筛选文档时作为过滤条件（如 "user-data"、"chat-context"）。 */
  scope: string;
  /** 来源类型，标识文档来自文件导入、手动创建还是同步，用于记录来源归属。 */
  sourceType: string;
  /** 源文件名，不含路径，用于文件系统记录和 UI 展示。 */
  fileName: string;
  /** 文档的 MIME 类型（如 text/plain、application/json），决定内容处理方式。 */
  mimeType: string;
  /** 文档的文本内容，写入文件存储并记录在索引中，是 DataBank 的核心数据。 */
  content: string;
  /** 文档关联的标签列表，用于分类和搜索，通过 listByTag 可按照标签筛选文档。 */
  tags: Array<string>;
  /** 附加元数据的 JSON 字符串，可存储非结构化信息（如来源 URL、处理参数等）。 */
  metadataJson: string;
  /** 文档是否已启用，后续可通过 setDocumentEnabled 切换状态，禁用后默认不会被 listDocuments 返回。 */
  enabled: boolean;
}

/**
 * DataBank 中文档的持久化记录，包含索引元信息和内容，用于文档的查找、读写和状态管理。
 */
export interface DataBankDocumentRecord {
  /** 数据模式的版本号，用于向前兼容，当前固定为 1。 */
  schemaVersion: number;
  /** 文档的唯一标识，在内存索引中作为 Map 键使用。 */
  id: string;
  /** 文档所属作用域，用于逻辑分组和 listByScope 筛选。 */
  scope: string;
  /** 来源类型，记录文档的来源方式（文件导入 / 手动创建 / 同步）。 */
  sourceType: string;
  /** 源文件名，不含路径，用于记录原始文件名。 */
  fileName: string;
  /** MIME 类型，标识内容格式。 */
  mimeType: string;
  /** 文档内容的文件存储路径，由 documentPath 方法生成，供文件存储适配器读写。 */
  path: string;
  /** 文档的文本内容，初始化时写入文件，通过 readDocumentContent 读取。 */
  content: string;
  /** 关联的标签列表，供 listByTag 按标签筛选使用。 */
  tags: Array<string>;
  /** 附加元数据的 JSON 字符串，通过 updateMetadata 更新。 */
  metadataJson: string;
  /** 文档是否已启用，禁用后默认过滤在 listDocuments / listByScope / listByTag 的返回结果之外。 */
  enabled: boolean;
  /** 记录创建时间戳（毫秒），首次写入时设置，更新时保持不变。 */
  createdAt: number;
  /** 记录最近一次更新的时间戳（毫秒），每次状态或内容变更时刷新。 */
  updatedAt: number;
}

/**
 * DataBank 完整状态导出格式，用于备份或迁移，包含所有文档记录的快照。
 */
export interface DataBankExportData {
  /** 所有文档记录的列表，供 exportData 生成备份和 importData 恢复数据使用。 */
  documents: Array<DataBankDocumentRecord>;
}

/**
 * DataBank 文档被创建或更新时发布的事件负载，由 createDocument / updateMetadata / setDocumentEnabled 触发。
 */
export interface DataBankUpdatedPayload {
  /** 被更新文档的标识，供订阅方定位被操作的具体文档。 */
  documentId: string;
  /** 更新后的文档记录深拷贝，供订阅方获取最新状态（如刷新 UI 列表）。 */
  document: DataBankDocumentRecord;
}

/**
 * DataBank 文档被删除时发布的事件负载，由 deleteDocument 触发。
 */
export interface DataBankDeletedPayload {
  /** 被删除文档的标识，供订阅方同步清理关联的 UI 或缓存数据。 */
  documentId: string;
}
