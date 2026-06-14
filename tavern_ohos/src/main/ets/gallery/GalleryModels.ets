/**
 * 描述角色图库模块在运行时交换的数据结构，
 * 用于存储角色相关的图片元数据，供 UI 图库界面展示和表情/外观管理使用。
 */
export interface GalleryImage {
  /**
   * 图库图片的唯一标识，格式为 'gallery-{自增数字}'，
   * 由 GalleryRuntime.addImage 自动生成，用于在运行时索引中唯一标记一张图片。
   */
  imageId: string; characterId: string; fileName: string; mimeType: string;
  /**
   * 图片在存储中的文件路径，
   * 用于在需要展示或处理图片时从磁盘读取文件内容。
   */
  path: string; caption: string; tags: Array<string>; createdAt: number;
}

/**
 * 描述角色图库事件发布时携带的数据结构，
   * 用于在图片添加到图库后通过 EventBus 通知 UI 图库面板和其他模块。
 */
export interface GalleryImageAddedPayload {
  /**
   * 被添加的图片完整数据，
   * 供监听方（如 UI 图库列表）基于此数据在界面中增加新图片项。
   */
  image: GalleryImage;
}

/**
 * 描述角色图库事件发布时携带的数据结构，
 * 用于在图片从图库移除后通过 EventBus 通知 UI 图库面板和其他模块。
 */
export interface GalleryImageRemovedPayload {
  /**
   * 被移除的图片标识，
   * 供监听方据此从 UI 列表或本地缓存中移除对应条目。
   */
  imageId: string;
}

/**
 * 描述角色图库模块在运行时交换的数据结构，
 * 用于在备份、迁移或与 SillyTavern 数据互通时导出/导入全部图库图片数据。
 */
export interface GalleryExportData {
  /**
   * 当前运行时中所有角色的全部图库图片列表，
   * 作为导出/导入操作的数据载体，包含所有图片的元数据记录。
   */
  images: Array<GalleryImage>;
}
