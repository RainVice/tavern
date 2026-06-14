import type { TavernScope } from '../contracts/PublicContracts';

/**
 * 描述调用Data Bank 文档能力时需要传入的参数。
 */
export interface DataBankDocumentCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * source Type 值，由当前实例内部维护。
   */
  sourceType: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
}

/**
 * 描述Data Bank 文档持久化或内存索引中的一条记录。
 */
export interface DataBankDocumentRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * source Type 值，由当前实例内部维护。
   */
  sourceType: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * 路径。
   */
  path: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
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
 * 描述Data Bank 文档模块在运行时交换的数据结构。
 */
export interface DataBankExportData {
  /**
   * documents 列表，由当前实例内部维护。
   */
  documents: Array<DataBankDocumentRecord>;
}

/**
 * 描述Data Bank 文档事件发布时携带的数据结构。
 */
export interface DataBankUpdatedPayload {
  /**
   * document 标识。
   */
  documentId: string;
  /**
   * document 值，由当前实例内部维护。
   */
  document: DataBankDocumentRecord;
}

/**
 * 描述Data Bank 文档事件发布时携带的数据结构。
 */
export interface DataBankDeletedPayload {
  /**
   * document 标识。
   */
  documentId: string;
}
