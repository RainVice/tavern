/**
 * 描述头像模块在运行时交换的数据结构。
 */
export interface AvatarCrop {
  /**
   * x 值，由当前实例内部维护。
   */
  x: number;
  /**
   * y 值，由当前实例内部维护。
   */
  y: number;
  /**
   * width 值，由当前实例内部维护。
   */
  width: number;
  /**
   * height 值，由当前实例内部维护。
   */
  height: number;
}

/**
 * 描述头像持久化或内存索引中的一条记录。
 */
export interface AvatarRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * target Type 值，由当前实例内部维护。
   */
  targetType: string;
  /**
   * target 标识。
   */
  targetId: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * 路径。
   */
  path: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * crop 值，由当前实例内部维护。
   */
  crop: AvatarCrop;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述头像事件发布时携带的数据结构。
 */
export interface AvatarUploadedPayload {
  /**
   * avatar 值，由当前实例内部维护。
   */
  avatar: AvatarRecord;
}

/**
 * 描述头像事件发布时携带的数据结构。
 */
export interface AvatarDeletedPayload {
  /**
   * target Type 值，由当前实例内部维护。
   */
  targetType: string;
  /**
   * target 标识。
   */
  targetId: string;
  /**
   * 路径。
   */
  path: string;
}

/**
 * 描述头像模块在运行时交换的数据结构。
 */
export interface AvatarIndexData {
  /**
   * avatars 列表，由当前实例内部维护。
   */
  avatars: Array<AvatarRecord>;
}
