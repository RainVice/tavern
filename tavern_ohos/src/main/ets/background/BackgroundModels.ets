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
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * is Animated 值，由当前实例内部维护。
   */
  isAnimated: boolean;
  /**
   * folder 标识列表。
   */
  folderIds: Array<string>;
  /**
   * thumbnail Content 值，由当前实例内部维护。
   */
  thumbnailContent: string;
}

/**
 * 描述背景图持久化或内存索引中的一条记录。
 */
export interface BackgroundRecord {
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
   * 路径。
   */
  path: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * is Animated 值，由当前实例内部维护。
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
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述背景图持久化或内存索引中的一条记录。
 */
export interface BackgroundListItem {
  /**
   * filename 值，由当前实例内部维护。
   */
  filename: string;
  /**
   * is Animated 值，由当前实例内部维护。
   */
  isAnimated: boolean;
}

/**
 * 描述背景图持久化或内存索引中的一条记录。
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
   * images 列表，由当前实例内部维护。
   */
  images: Array<BackgroundListItem>;
  /**
   * config 值，由当前实例内部维护。
   */
  config: ThumbnailDimensions;
}

/**
 * 描述背景图事件发布时携带的数据结构。
 */
export interface BackgroundImportedPayload {
  /**
   * background 值，由当前实例内部维护。
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
   * background 值，由当前实例内部维护。
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
   * backgrounds 列表，由当前实例内部维护。
   */
  backgrounds: Array<BackgroundRecord>;
}
