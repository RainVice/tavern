/**
 * 描述角色图库模块在运行时交换的数据结构。
 */
export interface GalleryImage {
  /**
   * image 标识。
   */
  imageId: string; characterId: string; fileName: string; mimeType: string;
  /**
   * 路径。
   */
  path: string; caption: string; tags: Array<string>; createdAt: number;
}
/**
 * 描述角色图库事件发布时携带的数据结构。
 */
export interface GalleryImageAddedPayload {
  /**
   * 图片数据。
   */
  image: GalleryImage;
}
/**
 * 描述角色图库事件发布时携带的数据结构。
 */
export interface GalleryImageRemovedPayload {
  /**
   * 图片标识。
   */
  imageId: string;
}
/**
 * 描述角色图库模块在运行时交换的数据结构。
 */
export interface GalleryExportData {
  /**
   * 图片列表。
   */
  images: Array<GalleryImage>;
}
