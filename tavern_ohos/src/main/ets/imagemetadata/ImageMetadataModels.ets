/**
 * 限定图片元数据模块可接受的图片编码格式，用于标识待解析文件的容器类型。
 */
export type ImageFormat = 'png' | 'webp' | 'jpeg' | 'unknown';
/**
 * 图片文件中元数据块的类型标识符。
 * 对于 PNG 文件为四字符 chunk type（如 tEXt、IEND），
 * 对于 WebP 文件为四字符 chunk type（如 EXIF、VP8），
 * 对于 JPEG 文件为 Marker 标识符。
 */
export type ImageMetadataChunkType = string;
/**
 * 图片文件中单个元数据块的摘要信息，包含类型和原始大小。
 */
export interface ImageMetadataChunk {
  /**
   * 元数据块类型标识符，对应文件容器格式中的 chunk type。
   */
  type: ImageMetadataChunkType;
  /**
   * 元数据块在文件中占用的数据长度（字节数），不含 chunk 头部和 CRC 尾部。
   */
  size: number;
}
/**
 * 图片元数据提取结果，描述图片的编码格式、尺寸、原始 chunk 列表以及是否包含角色卡数据。
 */
export interface ImageMetadata {
  /**
   * 图片编码格式（png / webp / jpeg / unknown），由 extractMetadata 检测得出。
   */
  format: ImageFormat; width: number; height: number;
  /**
   * 图片中是否包含角色卡（chara / ccv3）元数据块。
   */
  hasCharacterCard: boolean; rawChunks: Array<ImageMetadataChunk>;
}
/**
 * 图片元数据提取操作的完整返回结果，包含元数据摘要及角色卡 JSON 原文。
 */
export interface MetadataExtractResult {
  /**
   * 图片元数据摘要信息，包含格式、尺寸、chunk 列表及角色卡存在标记。
   */
  metadata: ImageMetadata; characterCardJson: string;
}
/**
 * 写入图片元数据时所需的全部参数，包括目标格式、角色卡 JSON、输出路径及可选源数据。
 */
export interface MetadataWriteParams {
  /**
   * 目标图片编码格式，决定写入时采用何种容器格式解析策略。
   */
  format: ImageFormat; characterCardJson: string; outputPath: string; sourceData?: ArrayBuffer;
}
/**
 * 图片元数据提取事件发布时携带的数据载荷。
 */
export interface MetadataExtractedPayload {
  /**
   * 元数据提取操作的完整结果对象。
   */
  result: MetadataExtractResult;
}
