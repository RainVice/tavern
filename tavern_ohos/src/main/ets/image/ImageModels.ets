/**
 * 描述调用图片资源能力时需要传入的参数。
 */
export interface ImageUploadParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * format 值，由当前实例内部维护。
   */
  format: string;
  /**
   * folder 名称。
   */
  folderName: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * thumbnail Type 值，由当前实例内部维护。
   */
  thumbnailType: string;
  /**
   * thumbnail Content 值，由当前实例内部维护。
   */
  thumbnailContent: string;
  /**
   * thumbnail Width 值，由当前实例内部维护。
   */
  thumbnailWidth: number;
  /**
   * thumbnail Height 值，由当前实例内部维护。
   */
  thumbnailHeight: number;
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
}

/**
 * 描述图片资源持久化或内存索引中的一条记录。
 */
export interface ImageRecord {
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
   * format 值，由当前实例内部维护。
   */
  format: string;
  /**
   * folder 名称。
   */
  folderName: string;
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
   * thumbnail Type 值，由当前实例内部维护。
   */
  thumbnailType: string;
  /**
   * thumbnail 路径。
   */
  thumbnailPath: string;
  /**
   * attachment 标识。
   */
  attachmentId: string;
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
 * 描述图片资源事件发布时携带的数据结构。
 */
export interface ImageUploadedPayload {
  /**
   * image 值，由当前实例内部维护。
   */
  image: ImageRecord;
}

/**
 * 描述图片资源事件发布时携带的数据结构。
 */
export interface ImageDeletedPayload {
  /**
   * image 标识。
   */
  imageId: string;
  /**
   * 路径。
   */
  path: string;
}

/**
 * 描述图片资源模块在运行时交换的数据结构。
 */
export interface ImageIndexData {
  /**
   * images 列表，由当前实例内部维护。
   */
  images: Array<ImageRecord>;
}
