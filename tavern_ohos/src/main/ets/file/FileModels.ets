/**
 * 上传文件时需要提供的参数集合，包含文件元数据、关联附件和知识库文档所需的信息。
 */
export interface FileUploadParams {
  /**
   * 要上传的文件唯一标识。
   */
  id: string;
  /**
   * 文件的原始名称，包含扩展名。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型，由调用方根据文件内容设置。
   */
  mimeType: string;
  /**
   * 文件内容，通常为 Base64 或纯文本数据。
   */
  content: string;
  /**
   * 关联的附件唯一标识，空字符串表示不关联附件。
   */
  attachmentId: string;
  /**
   * 关联附件所属的目标类型（如 "message"、"character"）。
   */
  attachmentTargetType: string;
  /**
   * 关联附件所属的目标标识。
   */
  attachmentTargetId: string;
  /**
   * 上传完成后是否将文件内容包含在 Prompt 上下文中。
   */
  includeInPrompt: boolean;
  /**
   * 上传完成后是否将文件内容纳入 RAG 索引。
   */
  includeInRag: boolean;
  /**
   * 关联的知识库文档唯一标识，空字符串表示不关联知识库文档。
   */
  dataBankDocumentId: string;
  /**
   * 知识库文档的作用域标识。
   */
  dataBankScope: string;
  /**
   * 知识库文档的标签列表。
   */
  dataBankTags: Array<string>;
  /**
   * 附加的自定义元数据 JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 已上传文件的持久化记录，包含文件的元数据、内容、关联信息和时间戳。
 */
export interface FileRecord {
  /**
   * 数据结构的 schema 版本号，用于向上兼容。
   */
  schemaVersion: number;
  /**
   * 文件记录的唯一标识。
   */
  id: string;
  /**
   * 文件的原始名称，包含扩展名。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型。
   */
  mimeType: string;
  /**
   * 文件在存储中的相对路径。
   */
  path: string;
  /**
   * 文件内容，通常为 Base64 或纯文本数据。
   */
  content: string;
  /**
   * 关联的附件唯一标识，空字符串表示未关联。
   */
  attachmentId: string;
  /**
   * 关联的知识库文档唯一标识，空字符串表示未关联。
   */
  dataBankDocumentId: string;
  /**
   * 附加的自定义元数据 JSON 字符串。
   */
  metadataJson: string;
  /**
   * 记录创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 文件存在性检查的结果，供调用方判断文件是否可用。
 */
export interface FileVerifyResult {
  /**
   * 被检查的文件路径。
   */
  path: string;
  /**
   * 文件是否存在于存储中。
   */
  exists: boolean;
}

/**
 * 文件上传事件发布时携带的数据。
 */
export interface FileUploadedPayload {
  /**
   * 上传完成的文件记录对象。
   */
  file: FileRecord;
}

/**
 * 文件删除事件发布时携带的数据。
 */
export interface FileDeletedPayload {
  /**
   * 被删除文件的唯一标识。
   */
  fileId: string;
  /**
   * 被删除文件在存储中的路径。
   */
  path: string;
}

/**
 * 文件索引持久化数据，用于在存储中保存和恢复所有文件记录的状态。
 */
export interface FileIndexData {
  /**
   * 所有已上传文件的记录列表。
   */
  files: Array<FileRecord>;
}
