/**
 * 限定图片元数据模块可接受的字符串取值范围。
 */
export type ImageFormat = 'png' | 'webp' | 'jpeg' | 'unknown';
/**
 * 描述图片元数据模块在运行时交换的数据结构。
 */
export interface ImageMetadataChunk {
  /**
   * 类型。
   */
  type: string;
  /**
   * 大小。
   */
  size: number;
}
/**
 * 描述图片元数据模块在运行时交换的数据结构。
 */
export interface ImageMetadata {
  /**
   * format 值，由当前实例内部维护。
   */
  format: ImageFormat; width: number; height: number;
  /**
   * has Character Card 值，由当前实例内部维护。
   */
  hasCharacterCard: boolean; rawChunks: Array<ImageMetadataChunk>;
}
/**
 * 描述图片元数据操作完成后返回给调用方的结果。
 */
export interface MetadataExtractResult {
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: ImageMetadata; characterCardJson: string;
}
/**
 * 描述调用图片元数据能力时需要传入的参数。
 */
export interface MetadataWriteParams {
  /**
   * format 值，由当前实例内部维护。
   */
  format: ImageFormat; characterCardJson: string; outputPath: string; sourceData?: ArrayBuffer;
}
/**
 * 描述图片元数据事件发布时携带的数据结构。
 */
export interface MetadataExtractedPayload {
  /**
   * 处理结果。
   */
  result: MetadataExtractResult;
}
