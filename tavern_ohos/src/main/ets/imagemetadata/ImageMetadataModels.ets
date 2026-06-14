/**
 * 限定图片元数据模块可支持的图片格式类型。
 * 用于 detectFormat() 和 writeMetadata() 识别和校验图片格式，'unknown' 表示无法识别的格式。
 */
export type ImageFormat = 'png' | 'webp' | 'jpeg' | 'unknown';
/**
 * 描述图片中的单个数据块（chunk）信息，用于遍历和判断角色卡数据。
 * 用于 extractMetadata() 解析图片时记录每个 chunk 的类型和大小，供外部调用方判断图片内容结构。
 */
export interface ImageMetadataChunk {
  /**
   * 数据块类型标识，如 tEXt、EXIF、IEND，用于在扫描图片数据块时区分不同 chunk 类型。
   */
  type: string;
  /**
   * 数据块大小（字节），用于计算 chunk 的数据负载长度。
   */
  size: number;
}
/**
 * 描述从图片中提取的元数据信息。
 * 由 extractMetadata() 返回，用于判断图片是否包含角色卡数据以及图片的完整数据块结构。
 */
export interface ImageMetadata {
  /**
   * 图片格式，由 detectFormat() 根据文件头部魔数判断。
   */
  format: ImageFormat; width: number; height: number;
  /**
   * 图片中是否包含角色卡数据，通过检查 tEXt 块的关键字是否为 'chara' 或 'ccv3'（PNG）或 EXIF chunk 中是否包含角色卡标识（WebP）确定。
   */
  hasCharacterCard: boolean; rawChunks: Array<ImageMetadataChunk>;
}
/**
 * 描述图片元数据提取操作的返回结果。
 * 由 extractCharacterCard() 返回，用于在角色卡导入流程中获取元数据和角色卡 JSON 内容。
 */
export interface MetadataExtractResult {
  /**
   * 提取出的图片元数据，包含格式、数据块列表和角色卡标记。
   */
  metadata: ImageMetadata; characterCardJson: string;
}
/**
 * 描述写入图片元数据时需要传入的参数。
 * 用于 writeMetadata() 写入角色卡 JSON 到图片时的配置，由角色卡保存流程调用方提供。
 */
export interface MetadataWriteParams {
  /**
   * 目标图片格式，决定写入时使用 PNG 还是 WebP 的角色卡嵌入算法。
   */
  format: ImageFormat; characterCardJson: string; outputPath: string; sourceData?: ArrayBuffer;
}
/**
 * 描述图片元数据提取事件发布时携带的数据结构。
 * 用于元数据提取完成时发布 'metadata.extracted' 事件，通知 UI 层或其他模块获取提取结果。
 */
export interface MetadataExtractedPayload {
  /**
   * 元数据提取操作的结果，包含图片元数据和角色卡 JSON。
   */
  result: MetadataExtractResult;
}
