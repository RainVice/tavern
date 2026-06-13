/**
 * 描述调用附件能力时需要传入的参数。
 */
export interface AttachmentCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * kind 值，由当前实例内部维护。
   */
  kind: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * storage 路径。
   */
  storagePath: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * include In Prompt 值，由当前实例内部维护。
   */
  includeInPrompt: boolean;
  /**
   * include In Rag 值，由当前实例内部维护。
   */
  includeInRag: boolean;
  /**
   * caption Text 值，由当前实例内部维护。
   */
  captionText: string;
  /**
   * translation Text 值，由当前实例内部维护。
   */
  translationText: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 描述附件持久化或内存索引中的一条记录。
 */
export interface AttachmentRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * kind 值，由当前实例内部维护。
   */
  kind: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * storage 路径。
   */
  storagePath: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * include In Prompt 值，由当前实例内部维护。
   */
  includeInPrompt: boolean;
  /**
   * include In Rag 值，由当前实例内部维护。
   */
  includeInRag: boolean;
  /**
   * caption Text 值，由当前实例内部维护。
   */
  captionText: string;
  /**
   * translation Text 值，由当前实例内部维护。
   */
  translationText: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * 删除结果，由当前实例内部维护。
   */
  deleted: boolean;
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
 * 描述附件持久化或内存索引中的一条记录。
 */
export interface AttachmentBindingRecord {
  /**
   * attachment 标识。
   */
  attachmentId: string;
  /**
   * target Type 值，由当前实例内部维护。
   */
  targetType: string;
  /**
   * target 标识。
   */
  targetId: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
}

/**
 * 描述附件持久化或内存索引中的一条记录。
 */
export interface AttachmentPromptRecord {
  /**
   * attachment 标识。
   */
  attachmentId: string;
  /**
   * kind 值，由当前实例内部维护。
   */
  kind: string;
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
}

/**
 * 描述附件模块在运行时交换的数据结构。
 */
export interface AttachmentExportData {
  /**
   * attachment 值，由当前实例内部维护。
   */
  attachment: AttachmentRecord;
  /**
   * bindings 列表，由当前实例内部维护。
   */
  bindings: Array<AttachmentBindingRecord>;
}

/**
 * 描述附件事件发布时携带的数据结构。
 */
export interface AttachmentAddedPayload {
  /**
   * attachment 标识。
   */
  attachmentId: string;
  /**
   * target Type 值，由当前实例内部维护。
   */
  targetType: string;
  /**
   * target 标识。
   */
  targetId: string;
  /**
   * attachment 值，由当前实例内部维护。
   */
  attachment: AttachmentRecord;
}

/**
 * 描述附件事件发布时携带的数据结构。
 */
export interface AttachmentDeletedPayload {
  /**
   * attachment 标识。
   */
  attachmentId: string;
}

/**
 * 描述附件事件发布时携带的数据结构。
 */
export interface AttachmentUpdatedPayload {
  /**
   * attachment 值，由当前实例内部维护。
   */
  attachment: AttachmentRecord;
}
