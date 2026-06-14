import type { ThumbnailType } from '../contracts/PublicContracts';

/**
 * 描述调用缩略图能力时需要传入的参数。
 */
export interface ThumbnailCreateParams {
  /**
   * type 值，由当前实例内部维护。
   */
  type: ThumbnailType;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * source 路径。
   */
  sourcePath: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * width 值，由当前实例内部维护。
   */
  width: number;
  /**
   * height 值，由当前实例内部维护。
   */
  height: number;
  /**
   * animated 值，由当前实例内部维护。
   */
  animated: boolean;
}

/**
 * 描述缩略图模块在运行时交换的数据结构。
 */
export interface ThumbnailDimensions {
  /**
   * width 值，由当前实例内部维护。
   */
  width: number;
  /**
   * height 值，由当前实例内部维护。
   */
  height: number;
}

/**
 * 描述缩略图持久化或内存索引中的一条记录。
 */
export interface ThumbnailRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * type 值，由当前实例内部维护。
   */
  type: ThumbnailType;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * source 路径。
   */
  sourcePath: string;
  /**
   * 路径。
   */
  path: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * width 值，由当前实例内部维护。
   */
  width: number;
  /**
   * height 值，由当前实例内部维护。
   */
  height: number;
  /**
   * aspect Ratio 值，由当前实例内部维护。
   */
  aspectRatio: number;
  /**
   * resolution 值，由当前实例内部维护。
   */
  resolution: number;
  /**
   * animated 值，由当前实例内部维护。
   */
  animated: boolean;
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
 * 描述缩略图事件发布时携带的数据结构。
 */
export interface ThumbnailGeneratedPayload {
  /**
   * thumbnail 值，由当前实例内部维护。
   */
  thumbnail: ThumbnailRecord;
}

/**
 * 描述缩略图事件发布时携带的数据结构。
 */
export interface ThumbnailInvalidatedPayload {
  /**
   * type 值，由当前实例内部维护。
   */
  type: ThumbnailType;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * 路径。
   */
  path: string;
}

/**
 * 描述缩略图模块在运行时交换的数据结构。
 */
export interface ThumbnailIndexData {
  /**
   * thumbnails 列表，由当前实例内部维护。
   */
  thumbnails: Array<ThumbnailRecord>;
}
