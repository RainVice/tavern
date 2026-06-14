/**
 * 描述调用表情图能力时需要传入的参数。
 */
export interface SpriteUploadParams {
  /**
   * character 名称。
   */
  characterName: string;
  /**
   * subfolder 名称。
   */
  subfolderName: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * sprite 名称。
   */
  spriteName: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * 内容。
   */
  content: string;
}

/**
 * 描述表情图模块在运行时交换的数据结构。
 */
export interface RisuSpriteImport {
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * 内容。
   */
  content: string;
}

/**
 * 描述表情图持久化或内存索引中的一条记录。
 */
export interface SpriteRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * character 名称。
   */
  characterName: string;
  /**
   * subfolder 名称。
   */
  subfolderName: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * sprite 名称。
   */
  spriteName: string;
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
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述表情图持久化或内存索引中的一条记录。
 */
export interface SpriteSelectionRecord {
  /**
   * character 名称。
   */
  characterName: string;
  /**
   * subfolder 名称。
   */
  subfolderName: string;
  /**
   * expression 值，由当前实例内部维护。
   */
  expression: string;
  /**
   * sprite 名称。
   */
  spriteName: string;
  /**
   * 路径。
   */
  path: string;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述表情图事件发布时携带的数据结构。
 */
export interface SpriteUploadedPayload {
  /**
   * sprite 值，由当前实例内部维护。
   */
  sprite: SpriteRecord;
}

/**
 * 描述表情图事件发布时携带的数据结构。
 */
export interface SpriteDeletedPayload {
  /**
   * character 名称。
   */
  characterName: string;
  /**
   * subfolder 名称。
   */
  subfolderName: string;
  /**
   * sprite 名称。
   */
  spriteName: string;
  /**
   * 路径。
   */
  path: string;
}

/**
 * 描述表情图事件发布时携带的数据结构。
 */
export interface SpriteExpressionChangedPayload {
  /**
   * character 名称。
   */
  characterName: string;
  /**
   * subfolder 名称。
   */
  subfolderName: string;
  /**
   * expression 值，由当前实例内部维护。
   */
  expression: string;
  /**
   * sprite 名称。
   */
  spriteName: string;
  /**
   * 路径。
   */
  path: string;
}
