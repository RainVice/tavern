import type { TavernScope } from '../contracts/PublicContracts';

/**
 * 创建 Data Bank 文档时需提供的参数集合。
 */
export interface DataBankDocumentCreateParams {
  /**
   * 文档唯一标识，全局不重复。
   */
  id: string;
  /**
   * 文档所属的 Tavern 作用域（如 chat、character），用于隔离不同模块的数据。
   */
  scope: TavernScope;
  /**
   * 文档来源的类型标识，由创建方传入，用于区分不同插件或模块产生的文档。
   */
  sourceType: string;
  /**
   * 文档对应的文件名，用于向用户展示。
   */
  fileName: string;
  /**
   * 文档内容的 MIME 类型，由创建方传入，用于区分纯文本、JSON 等格式。
   */
  mimeType: string;
  /**
   * 文档正文内容。
   */
  content: string;
  /**
   * 附加的标签列表，用于分类和按标签检索。
   */
  tags: Array<string>;
  /**
   * 自定义元数据的 JSON 字符串，用于存储与具体业务相关的扩展字段。
   */
  metadataJson: string;
  /**
   * 文档是否启用，禁用的文档在常规查询中会被过滤。
   */
  enabled: boolean;
}

/**
 * Data Bank 文档在持久化存储和内存索引中的完整记录结构。
 */
export interface DataBankDocumentRecord {
  /**
   * 记录结构的 schema 版本号，用于将来格式迁移时做兼容判断。
   */
  schemaVersion: number;
  /**
   * 文档唯一标识，全局不重复。
   */
  id: string;
  /**
   * 文档所属的 Tavern 作用域。
   */
  scope: TavernScope;
  /**
   * 文档来源的类型标识，由创建方传入。
   */
  sourceType: string;
  /**
   * 文档对应的文件名，用于向用户展示。
   */
  fileName: string;
  /**
   * 文档内容的 MIME 类型，由创建方传入。
   */
  mimeType: string;
  /**
   * 文档内容在文件系统中的存储路径。
   */
  path: string;
  /**
   * 文档正文内容。
   */
  content: string;
  /**
   * 附加的标签列表，用于分类和按标签检索。
   */
  tags: Array<string>;
  /**
   * 自定义元数据的 JSON 字符串，用于存储扩展字段。
   */
  metadataJson: string;
  /**
   * 文档是否启用，禁用的文档在常规查询中会被过滤。
   */
  enabled: boolean;
  /**
   * 记录创建时的时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录最近一次更新的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 导入或导出 Data Bank 全部文档时使用的数据容器。
 */
export interface DataBankExportData {
  /**
   * 所有文档记录的数组。
   */
  documents: Array<DataBankDocumentRecord>;
}

/**
 * Data Bank 文档更新事件发布时携带的数据结构。
 */
export interface DataBankUpdatedPayload {
  /**
   * 发生变更的文档标识。
   */
  documentId: string;
  /**
   * 变更后的文档记录副本。
   */
  document: DataBankDocumentRecord;
}

/**
 * Data Bank 文档删除事件发布时携带的数据结构。
 */
export interface DataBankDeletedPayload {
  /**
   * 被删除的文档标识。
   */
  documentId: string;
}
