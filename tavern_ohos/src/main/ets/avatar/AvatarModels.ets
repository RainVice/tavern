/**
 * 描述头像裁剪区域的数据结构，用于定义用户在原始图片中选择的头像裁剪框位置和尺寸。
 */
export interface AvatarCrop {
  /**
   * 裁剪区域左上角的 x 坐标（像素），用于定义头像裁剪框在原始图片中的水平偏移位置。
   */
  x: number;
  /**
   * 裁剪区域左上角的 y 坐标（像素），用于定义头像裁剪框在原始图片中的垂直偏移位置。
   */
  y: number;
  /**
   * 裁剪区域的宽度（像素），用于定义头像裁剪框的水平尺寸。
   */
  width: number;
  /**
   * 裁剪区域的高度（像素），用于定义头像裁剪框的垂直尺寸。
   */
  height: number;
}

/**
 * 描述头像持久化或内存索引中的一条记录，用于在角色编辑或个人资料设置中管理用户头像。
 */
export interface AvatarRecord {
  /**
   * 记录结构的 schema 版本号，用于索引数据的向前兼容性检查。
   */
  schemaVersion: number;
  /**
   * 头像所属目标对象的类型（如 character、persona），用于区分不同模块的头像存储目录。
   */
  targetType: string;
  /**
   * 头像所属目标对象的唯一标识，用于将头像记录关联到具体的角色或个人资料。
   */
  targetId: string;
  /**
   * 文件名称，用于定义头像文件在存储目录中的文件名。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型，用于头像显示时判断图片格式。
   */
  mimeType: string;
  /**
   * 头像文件在存储中的路径，用于读写头像文件内容。
   */
  path: string;
  /**
   * 头像文件内容（base64 编码或原始数据），用于头像渲染或导出。
   */
  content: string;
  /**
   * 头像的裁剪区域配置，用于记录用户在原始图片中选择的裁剪范围。
   */
  crop: AvatarCrop;
  /**
   * 记录创建时间戳（毫秒），用于头像历史记录排序和展示。
   */
  createdAt: number;
  /**
   * 记录最近更新时间戳（毫秒），用于头像变更检测和缓存失效。
   */
  updatedAt: number;
}

/**
 * 描述头像上传事件发布时携带的数据结构，用于通知其他模块有新头像可用。
 */
export interface AvatarUploadedPayload {
  /**
   * 上传的头像记录，供事件订阅者获取头像元数据和内容进行后续处理。
   */
  avatar: AvatarRecord;
}

/**
 * 描述头像删除事件发布时携带的数据结构，用于通知其他模块清理关联的缓存或引用。
 */
export interface AvatarDeletedPayload {
  /**
   * 被删除头像所属的目标对象类型，供事件订阅者识别是哪个模块的头像被删除。
   */
  targetType: string;
  /**
   * 被删除头像所属的目标对象标识，供事件订阅者定位具体的角色或个人资料引用。
   */
  targetId: string;
  /**
   * 被删除头像文件的路径，供事件订阅者清理文件系统缓存。
   */
  path: string;
}

/**
 * 描述头像模块的索引数据结构，用于将全部头像元信息持久化到 index.json 文件。
 */
export interface AvatarIndexData {
  /**
   * 索引中记录的所有头像列表，用于启动时重建内存头像索引。
   */
  avatars: Array<AvatarRecord>;
}
