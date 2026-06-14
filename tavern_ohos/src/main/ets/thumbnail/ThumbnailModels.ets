import type { ThumbnailType } from '../contracts/PublicContracts';

/**
 * 描述调用缩略图能力时需要传入的参数。
 */
export interface ThumbnailCreateParams {
  /**
   * 缩略图类型。
   */
  type: ThumbnailType;
  /**
   * 原始文件名。
   */
  fileName: string;
  /**
   * 原始文件路径。
   */
  sourcePath: string;
  /**
   * 缩略图内容（Base64 或 JSON 序列化数据）。
   */
  content: string;
  /**
   * 缩略图宽度，单位 px。
   */
  width: number;
  /**
   * 缩略图高度，单位 px。
   */
  height: number;
  /**
   * 该缩略图是否包含动画帧。
   */
  animated: boolean;
}

/**
 * 描述缩略图的尺寸配置。
 */
export interface ThumbnailDimensions {
  /**
   * 缩略图宽度，单位 px。
   */
  width: number;
  /**
   * 缩略图高度，单位 px。
   */
  height: number;
}

/**
 * 描述缩略图持久化或内存索引中的一条记录。
 */
export interface ThumbnailRecord {
  /**
   * Schema 版本号。
   */
  schemaVersion: number;
  /**
   * 缩略图类型。
   */
  type: ThumbnailType;
  /**
   * 原始文件名。
   */
  fileName: string;
  /**
   * 原始文件路径。
   */
  sourcePath: string;
  /**
   * 缩略图文件存储路径。
   */
  path: string;
  /**
   * 缩略图内容（Base64 或 JSON 序列化数据）。
   */
  content: string;
  /**
   * 缩略图宽度，单位 px。
   */
  width: number;
  /**
   * 缩略图高度，单位 px。
   */
  height: number;
  /**
   * 宽高比。
   */
  aspectRatio: number;
  /**
   * 分辨率（宽 * 高）。
   */
  resolution: number;
  /**
   * 该缩略图是否包含动画帧。
   */
  animated: boolean;
  /**
   * 记录创建时间戳（单位 ms）。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（单位 ms）。
   */
  updatedAt: number;
}

/**
 * 描述缩略图事件发布时携带的数据结构：缩略图已生成。
 */
export interface ThumbnailGeneratedPayload {
  /**
   * 已生成的缩略图记录。
   */
  thumbnail: ThumbnailRecord;
}

/**
 * 描述缩略图事件发布时携带的数据结构：缩略图已失效。
 */
export interface ThumbnailInvalidatedPayload {
  /**
   * 失效的缩略图类型。
   */
  type: ThumbnailType;
  /**
   * 失效的原始文件名。
   */
  fileName: string;
  /**
   * 失效的缩略图文件路径。
   */
  path: string;
}

/**
 * 描述缩略图索引持久化时的数据格式。
 */
export interface ThumbnailIndexData {
  /**
   * 所有缩略图记录列表。
   */
  thumbnails: Array<ThumbnailRecord>;
}
