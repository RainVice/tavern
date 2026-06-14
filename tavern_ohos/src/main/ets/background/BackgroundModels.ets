import type { ThumbnailDimensions } from '../thumbnail/ThumbnailModels';

/**
 * 描述调用背景图能力时需要传入的参数。
 */
export interface BackgroundImportParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * 文件的 MIME 类型（如 image/png）。
   */
  mimeType: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * 是否为动图（如 GIF）。
   */
  isAnimated: boolean;
  /**
   * folder 标识列表。
   */
  folderIds: Array<string>;
  /**
   * 缩略图内容（base64 编码）。
   */
  thumbnailContent: string;
}

/**
 * 描述背景图持久化或内存索引中的一条记录。
 */
export interface BackgroundRecord {
  /**
   * 记录结构的 schema 版本号。
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
   * 路径。
   */
  path: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * 文件的 MIME 类型（如 image/png）。
   */
  mimeType: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * 是否为动图（如 GIF）。
   */
  isAnimated: boolean;
  /**
   * folder 标识列表。
   */
  folderIds: Array<string>;
  /**
   * thumbnail 路径。
   */
  thumbnailPath: string;
  /**
   * 记录创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录最近更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述列表中单张背景图的摘要信息。
 */
export interface BackgroundListItem {
  /**
   * 文件名。
   */
  filename: string;
  /**
   * 是否为动图（如 GIF）。
   */
  isAnimated: boolean;
}

/**
 * 描述文件夹维度聚合的记录。
 */
export interface BackgroundFolderRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
}

/**
 * 描述背景图操作完成后返回给调用方的结果。
 */
export interface BackgroundListResult {
  /**
   * 背景图摘要列表。
   */
  images: Array<BackgroundListItem>;
  /**
   * 缩略图尺寸配置。
   */
  config: ThumbnailDimensions;
}

/**
 * 描述背景图事件发布时携带的数据结构。
 */
export interface BackgroundImportedPayload {
  /**
   * 背景图记录。
   */
  background: BackgroundRecord;
}

/**
 * 描述背景图事件发布时携带的数据结构。
 */
export interface BackgroundRenamedPayload {
  /**
   * old File 名称。
   */
  oldFileName: string;
  /**
   * 背景图记录。
   */
  background: BackgroundRecord;
}

/**
 * 描述背景图事件发布时携带的数据结构。
 */
export interface BackgroundDeletedPayload {
  /**
   * background 标识。
   */
  backgroundId: string;
  /**
   * file 名称。
   */
  fileName: string;
}

/**
 * 描述背景图模块在运行时交换的数据结构。
 */
export interface BackgroundIndexData {
  /**
   * 背景图记录列表。
   */
  backgrounds: Array<BackgroundRecord>;
}
