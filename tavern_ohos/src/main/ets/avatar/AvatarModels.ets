/**
 * 头像裁剪区域坐标，描述原始图像中用于裁剪的矩形范围。
 */
export interface AvatarCrop {
  /**
   * 裁剪矩形左上角的横坐标，单位为像素。
   */
  x: number;
  /**
   * 裁剪矩形左上角的纵坐标，单位为像素。
   */
  y: number;
  /**
   * 裁剪矩形的宽度，单位为像素。
   */
  width: number;
  /**
   * 裁剪矩形的高度，单位为像素。
   */
  height: number;
}

/**
 * 头像的一条完整记录，用于持久化存储或运行时索引。
 */
export interface AvatarRecord {
  /**
   * 数据结构的 schema 版本号，用于向前兼容。
   */
  schemaVersion: number;
  /**
   * 所属目标类型，如 "character" 或 "persona"。
   */
  targetType: string;
  /**
   * 关联目标的唯一标识符。
   */
  targetId: string;
  /**
   * 头像文件的原始名称。
   */
  fileName: string;
  /**
   * 头像文件的 MIME 类型，如 "image/png"。
   */
  mimeType: string;
  /**
   * 头像文件在存储中的完整路径。
   */
  path: string;
  /**
   * 头像文件的 base64 编码内容。
   */
  content: string;
  /**
   * 与该头像关联的裁剪区域信息。
   */
  crop: AvatarCrop;
  /**
   * 记录创建时间的时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录最近一次更新时间的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 头像上传事件发布时携带的数据载荷。
 */
export interface AvatarUploadedPayload {
  /**
   * 已完成上传的头像记录副本。
   */
  avatar: AvatarRecord;
}

/**
 * 头像删除事件发布时携带的数据载荷。
 */
export interface AvatarDeletedPayload {
  /**
   * 已删除头像所属的目标类型。
   */
  targetType: string;
  /**
   * 已删除头像所属目标的唯一标识符。
   */
  targetId: string;
  /**
   * 已删除头像文件在存储中的路径。
   */
  path: string;
}

/**
 * 头像索引的持久化数据结构，用于记录当前所有头像记录的快照。
 */
export interface AvatarIndexData {
  /**
   * 所有头像记录的列表。
   */
  avatars: Array<AvatarRecord>;
}
