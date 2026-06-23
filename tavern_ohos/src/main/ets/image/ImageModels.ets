import { MediaFormat, TavernScope, ThumbnailType } from "../contracts/PublicContracts";

/**
 * 上传图片时需传入的参数。
 */
export interface ImageUploadParams {
  /**
   * 图片唯一标识。
   */
  id: string;
  /**
   * 原始文件名。
   */
  fileName: string;
  /**
   * 图片格式（如 png、jpg）。
   */
  format: MediaFormat;
  /**
   * 文件夹名称，用于分组归类。
   */
  folderName: string;
  /**
   * MIME 类型（如 image/png）。
   */
  mimeType: string;
  /**
   * Base64 编码的图片内容。
   */
  content: string;
  /**
   * 缩略图类型。
   */
  thumbnailType: ThumbnailType;
  /**
   * Base64 编码的缩略图内容。
   */
  thumbnailContent: string;
  /**
   * 缩略图宽度（像素）。
   */
  thumbnailWidth: number;
  /**
   * 缩略图高度（像素）。
   */
  thumbnailHeight: number;
  /**
   * 关联的附件唯一标识。
   */
  attachmentId: string;
  /**
   * 附件关联的目标作用域类型。
   */
  attachmentTargetType: TavernScope;
  /**
   * 附件关联的目标唯一标识。
   */
  attachmentTargetId: string;
  /**
   * 是否在 Prompt 中包含此图片。
   */
  includeInPrompt: boolean;
  /**
   * 是否在 RAG 检索中包含此图片。
   */
  includeInRag: boolean;
}

/**
 * 持久化或内存索引中的一条图片记录。
 */
export interface ImageRecord {
  /**
   * 数据模式版本号。
   */
  schemaVersion: number;
  /**
   * 图片唯一标识。
   */
  id: string;
  /**
   * 规范化后的文件名。
   */
  fileName: string;
  /**
   * 图片格式（如 png、jpg）。
   */
  format: MediaFormat;
  /**
   * 文件夹名称，用于分组归类。
   */
  folderName: string;
  /**
   * MIME 类型（如 image/png）。
   */
  mimeType: string;
  /**
   * 图片文件存储路径。
   */
  path: string;
  /**
   * Base64 编码的图片内容。
   */
  content: string;
  /**
   * 缩略图类型。
   */
  thumbnailType: ThumbnailType;
  /**
   * 缩略图文件存储路径。
   */
  thumbnailPath: string;
  /**
   * 关联的附件唯一标识。
   */
  attachmentId: string;
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
 * 图片上传事件发布时携带的数据。
 */
export interface ImageUploadedPayload {
  /**
   * 已上传的图片记录。
   */
  image: ImageRecord;
}

/**
 * 图片删除事件发布时携带的数据。
 */
export interface ImageDeletedPayload {
  /**
   * 被删除图片的唯一标识。
   */
  imageId: string;
  /**
   * 被删除图片的文件路径。
   */
  path: string;
}

/**
 * 运行时图片索引快照，用于持久化保存。
 */
export interface ImageIndexData {
  /**
   * 所有图片记录的列表。
   */
  images: Array<ImageRecord>;
}
