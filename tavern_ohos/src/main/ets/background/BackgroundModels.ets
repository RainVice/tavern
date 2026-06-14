import type { ThumbnailDimensions } from '../thumbnail/ThumbnailModels';

/**
 * 描述调用背景图能力时需要传入的参数，用于在背景图管理（图库）中导入新背景时提供完整信息。
 */
export interface BackgroundImportParams {
  /**
   * 背景图的唯一标识，用于关联 Asset 和内存索引中的记录。
   */
  id: string;
  /**
   * 背景图文件名，用于存储和索引标识。
   */
  fileName: string;
  /**
   * 背景图文件内容（base64 编码），用于写入磁盘和后续渲染。
   */
  content: string;
  /**
   * 图片的 MIME 类型（如 image/png），用于存储时识别格式。
   */
  mimeType: string;
  /**
   * 背景图的元数据 JSON 字符串，用于序列化和持久化额外描述信息。
   */
  metadataJson: string;
  /**
   * 是否为动图（GIF/WebP 动画），用于缩略图生成和 UI 展示标记。
   */
  isAnimated: boolean;
  /**
   * 背景图所属的文件夹标识列表，用于按文件夹分类和筛选背景图。
   */
  folderIds: Array<string>;
  /**
   * 背景缩略图的 Base64 编码数据，用于快速生成缩略图而不必解码原图。
   */
  thumbnailContent: string;
}

/**
 * 描述背景图持久化或内存索引中的一条记录，用于在背景图管理、主题设置和 UI 展示中提供完整背景元数据。
 */
export interface BackgroundRecord {
  /**
   * 数据模式版本号，用于索引数据的向前兼容性检查。
   */
  schemaVersion: number;
  /**
   * 背景图的唯一标识，用于关联 Asset 资源记录。
   */
  id: string;
  /**
   * 背景图文件名，用于存储、索引和 UI 展示。
   */
  fileName: string;
  /**
   * 背景图文件在存储中的路径，用于读写文件内容。
   */
  path: string;
  /**
   * 背景图文件内容（base64 编码），用于快速加载和渲染。
   */
  content: string;
  /**
   * 图片的 MIME 类型（如 image/png），用于渲染时识别格式。
   */
  mimeType: string;
  /**
   * 背景图元数据的 JSON 字符串，用于描述图片来源、标签等额外信息。
   */
  metadataJson: string;
  /**
   * 是否为动图（GIF/WebP 动画），用于缩略图生成和 UI 中显示动图标记。
   */
  isAnimated: boolean;
  /**
   * 背景图所属的文件夹标识列表，用于按文件夹管理和筛选背景图。
   */
  folderIds: Array<string>;
  /**
   * 背景缩略图文件路径，用于在列表中以缩略图形式快速预览。
   */
  thumbnailPath: string;
  /**
   * 记录创建时的时间戳（毫秒），用于排序和记录历史。
   */
  createdAt: number;
  /**
   * 记录最近更新时的时间戳（毫秒），用于变更检测。
   */
  updatedAt: number;
}

/**
 * 背景图列表中的单条摘要记录，包含前端渲染所需的概要信息，用于 UI 快速展示背景图列表。
 */
export interface BackgroundListItem {
  /**
   * 背景图片文件名，用于列表项显示和区分不同背景。
   */
  filename: string;
  /**
   * 是否为动图（GIF/WebP 动画），用于在列表项中显示动画标记。
   */
  isAnimated: boolean;
}

/**
 * 描述背景图持久化或内存索引中的一条记录，用于文件夹分类管理。
 */
export interface BackgroundFolderRecord {
  /**
   * 文件夹的唯一标识，用于筛选和分组背景图。
   */
  id: string;
  /**
   * 文件夹名称，用于 UI 展示。
   */
  name: string;
}

/**
 * 背景图列表的返回值，包含图片摘要列表和缩略图配置，用于 UI 渲染背景图选择面板。
 */
export interface BackgroundListResult {
  /**
   * 背景图片摘要列表，供 UI 渲染每个背景图项。
   */
  images: Array<BackgroundListItem>;
  /**
   * 缩略图尺寸配置，供 UI 按统一尺寸渲染缩略图。
   */
  config: ThumbnailDimensions;
}

/**
 * 背景导入事件发布时携带的数据结构，包含导入后的背景记录，用于通知其他模块背景图已更新。
 */
export interface BackgroundImportedPayload {
  /**
   * 导入完成后的背景图记录，供事件订阅者获取完整的背景元数据。
   */
  background: BackgroundRecord;
}

/**
 * 背景重命名事件发布时携带的数据结构，包含旧文件名和重命名后的记录，用于通知其他模块更新相关引用。
 */
export interface BackgroundRenamedPayload {
  /**
   * 重命名前的旧文件名，供事件订阅者失效旧缓存或引用。
   */
  oldFileName: string;
  /**
   * 重命名后的背景图记录，供事件订阅者获取新的名称和路径。
   */
  background: BackgroundRecord;
}

/**
 * 背景删除事件发布时携带的数据结构，包含被删除背景的标识和文件名，用于通知其他模块清理关联引用。
 */
export interface BackgroundDeletedPayload {
  /**
   * 被删除的背景图唯一标识，供事件订阅者定位需要清理的记录。
   */
  backgroundId: string;
  /**
   * 被删除背景图的文件名，供事件订阅者清理文件系统缓存或引用。
   */
  fileName: string;
}

/**
 * 背景图模块持久化索引的顶层数据结构，用于将全部背景记录序列化到 index.json 文件。
 */
export interface BackgroundIndexData {
  /**
   * 所有背景图记录的完整列表，用于启动时重建内存背景索引。
   */
  backgrounds: Array<BackgroundRecord>;
}
