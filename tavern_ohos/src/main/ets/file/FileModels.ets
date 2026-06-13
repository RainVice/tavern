/**
 * 描述调用上传文件能力时需要传入的参数。
 */
export interface FileUploadParams {
  /**
   * 标识。
   */
  id: string;
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
   * attachment 标识。
   */
  attachmentId: string;
  /**
   * attachment Target Type 值，由当前实例内部维护。
   */
  attachmentTargetType: string;
  /**
   * attachment Target 标识。
   */
  attachmentTargetId: string;
  /**
   * include In Prompt 值，由当前实例内部维护。
   */
  includeInPrompt: boolean;
  /**
   * include In Rag 值，由当前实例内部维护。
   */
  includeInRag: boolean;
  /**
   * data Bank Document 标识。
   */
  dataBankDocumentId: string;
  /**
   * data Bank Scope 值，由当前实例内部维护。
   */
  dataBankScope: string;
  /**
   * data Bank Tags 列表，由当前实例内部维护。
   */
  dataBankTags: Array<string>;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 描述上传文件持久化或内存索引中的一条记录。
 */
export interface FileRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
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
   * attachment 标识。
   */
  attachmentId: string;
  /**
   * data Bank Document 标识。
   */
  dataBankDocumentId: string;
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
 * 描述上传文件操作完成后返回给调用方的结果。
 */
export interface FileVerifyResult {
  /**
   * 路径。
   */
  path: string;
  /**
   * exists 列表，由当前实例内部维护。
   */
  exists: boolean;
}

/**
 * 描述上传文件事件发布时携带的数据结构。
 */
export interface FileUploadedPayload {
  /**
   * file 值，由当前实例内部维护。
   */
  file: FileRecord;
}

/**
 * 描述上传文件事件发布时携带的数据结构。
 */
export interface FileDeletedPayload {
  /**
   * file 标识。
   */
  fileId: string;
  /**
   * 路径。
   */
  path: string;
}

/**
 * 描述上传文件模块在运行时交换的数据结构。
 */
export interface FileIndexData {
  /**
   * 文件存储适配器。
   */
  files: Array<FileRecord>;
}
