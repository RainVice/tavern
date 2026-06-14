/**
 * 描述调用缩略图能力时需要传入的参数。
 * 在生成缩略图时传入，包含源文件信息和生成的尺寸要求。
 */
export interface ThumbnailCreateParams {
  /**
   * 缩略图类型（如 "avatar" / "bg" / "persona"），用于分类存储和按类型查询。
   */
  type: string;
  /**
   * 源文件名称，在 ThumbnailRuntime 中与 type 组合为复合键，用于定位和去重。
   */
  fileName: string;
  /**
   * 源文件路径，记录原始文件的存储位置，供后续引用或重新生成使用。
   */
  sourcePath: string;
  /**
   * 缩略图内容（base64 编码或文本数据），直接写入缩略图文件供 UI 展示。
   */
  content: string;
  /**
   * 缩略图宽度（像素），用于计算宽高比和 UI 布局中的尺寸适配。
   */
  width: number;
  /**
   * 缩略图高度（像素），用于计算宽高比和 UI 布局中的尺寸适配。
   */
  height: number;
  /**
   * 是否为动图，影响 UI 展示方式（是否显示播放控件）。
   */
  animated: boolean;
}

/**
 * 描述缩略图模块在运行时交换的尺寸结构。
 * 用于返回缩略图的预设尺寸配置。
 */
export interface ThumbnailDimensions {
  /**
   * 缩略图宽度（像素），由 getConfiguredDimensions 根据类型返回预设值。
   */
  width: number;
  /**
   * 缩略图高度（像素），由 getConfiguredDimensions 根据类型返回预设值。
   */
  height: number;
}

/**
 * 描述缩略图持久化或内存索引中的一条记录。
 * 在缩略图管理流程中，用于缓存源图片的小尺寸预览版本，加速 UI 加载速度。
 */
export interface ThumbnailRecord {
  /**
   * schema 版本号。
   */
  schemaVersion: number;
  /**
   * 缩略图类型（如 avatar/bg/persona），用于分类存储和查询。
   */
  type: string;
  /**
   * 源文件名称，与 type 组合唯一标识一个缩略图记录。
   */
  fileName: string;
  /**
   * 源文件路径，记录原始图片的位置，供 UI 点击缩略图时查看原图。
   */
  sourcePath: string;
  /**
   * 缩略图文件的存储路径，用于文件系统的读写定位。
   */
  path: string;
  /**
   * 缩略图内容（base64 编码或文本数据），供 UI 直接加载展示。
   */
  content: string;
  /**
   * 缩略图宽度（像素）。
   */
  width: number;
  /**
   * 缩略图高度（像素）。
   */
  height: number;
  /**
   * 宽高比（width / height），用于 UI 适配不同尺寸的展示容器。
   */
  aspectRatio: number;
  /**
   * 分辨率像素总数（width * height）。
   */
  resolution: number;
  /**
   * 是否为动图。
   */
  animated: boolean;
  /**
   * 创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 最近更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述缩略图生成事件发布时携带的数据结构。
 * ThumbnailRuntime 在 generateThumbnail 后发布 thumbnail.generated 事件，通知宿主 UI 刷新缩略图展示。
 */
export interface ThumbnailGeneratedPayload {
  /**
   * 新生成的缩略图记录。
   */
  thumbnail: ThumbnailRecord;
}

/**
 * 描述缩略图失效事件发布时携带的数据结构。
 * ThumbnailRuntime 在 invalidateThumbnail 后发布 thumbnail.invalidated 事件，通知宿主 UI 移除对应的缩略图展示。
 */
export interface ThumbnailInvalidatedPayload {
  /**
   * 缩略图类型，用于 UI 定位需要清理的缩略图分类。
   */
  type: string;
  /**
   * 源文件名称，用于 UI 定位需要清理的缩略图目标。
   */
  fileName: string;
  /**
   * 被删除的缩略图文件路径。
   */
  path: string;
}

/**
 * 描述缩略图索引数据的持久化结构。
 * 用于将所有缩略图记录以 JSON 格式持久化到文件，实现应用启动时的数据还原。
 */
export interface ThumbnailIndexData {
  /**
   * 所有缩略图记录的列表。
   */
  thumbnails: Array<ThumbnailRecord>;
}
