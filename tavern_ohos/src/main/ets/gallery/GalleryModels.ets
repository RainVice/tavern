/**
 * 图库中单张图片的数据结构，涵盖元信息、内容描述和标签分类。
 */
export interface GalleryImage {
  /**
   * 图片唯一标识，格式如 "gallery-1"。
   */
  imageId: string; characterId: string; fileName: string; mimeType: string;
  /**
   * 图片文件在本地存储或外部存储中的绝对路径。
   */
  path: string; caption: string; tags: Array<string>; createdAt: number;
}
/**
 * 新增图片事件所携带的载荷，包含完整的图片数据。
 */
export interface GalleryImageAddedPayload {
  /**
   * 被新增的图片对象。
   */
  image: GalleryImage;
}
/**
 * 移除图片事件所携带的载荷，仅包含被移除图片的标识。
 */
export interface GalleryImageRemovedPayload {
  /**
   * 被移除的图片标识。
   */
  imageId: string;
}
/**
 * 图库模块导入 / 导出时使用的序列化数据格式。
 */
export interface GalleryExportData {
  /**
   * 待导出或已导入的全部图片列表。
   */
  images: Array<GalleryImage>;
}
