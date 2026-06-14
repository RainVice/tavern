/**
 * 上传表情图时需要提供的参数。
 */
export interface SpriteUploadParams {
  /**
   * 关联的角色名称。
   */
  characterName: string;
  /**
   * 子目录名称，用于按主题整理表情图。
   */
  subfolderName: string;
  /**
   * 表情标签，例如 `"happy"`、`"angry"` 等。
   */
  label: string;
  /**
   * 立绘名称，用于标识同一角色的不同立绘变体。
   */
  spriteName: string;
  /**
   * 文件名（不含路径）。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型，例如 `"image/png"`。
   */
  mimeType: string;
  /**
   * 文件内容的 base64 编码字符串。
   */
  content: string;
}

/**
 * 从 RisuAI 导入的表情图数据项。
 */
export interface RisuSpriteImport {
  /**
   * 表情标签。
   */
  label: string;
  /**
   * 图片内容的 base64 编码字符串。
   */
  content: string;
}

/**
 * 表情图的持久化记录，包含完整的元数据和内容。
 */
export interface SpriteRecord {
  /**
   * 数据结构版本号，用于数据迁移判断。
   */
  schemaVersion: number;
  /**
   * 关联的角色名称。
   */
  characterName: string;
  /**
   * 子目录名称。
   */
  subfolderName: string;
  /**
   * 表情标签。
   */
  label: string;
  /**
   * 立绘名称。
   */
  spriteName: string;
  /**
   * 实际文件名（含扩展名）。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型。
   */
  mimeType: string;
  /**
   * 文件在存储中的完整路径。
   */
  path: string;
  /**
   * 文件内容的 base64 编码字符串。
   */
  content: string;
  /**
   * 记录创建时间的时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录最后更新时间的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 角色表情选择状态的记录，记录当前为某个角色/子目录选择的表情。
 */
export interface SpriteSelectionRecord {
  /**
   * 关联的角色名称。
   */
  characterName: string;
  /**
   * 子目录名称。
   */
  subfolderName: string;
  /**
   * 当前选中的表情标签。
   */
  expression: string;
  /**
   * 当前选中的立绘名称。
   */
  spriteName: string;
  /**
   * 当前选中立绘的存储路径。
   */
  path: string;
  /**
   * 选择状态最后更新时间的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 表情图上传事件发布时携带的载荷。
 */
export interface SpriteUploadedPayload {
  /**
   * 刚上传的表情图记录。
   */
  sprite: SpriteRecord;
}

/**
 * 表情图删除事件发布时携带的载荷。
 */
export interface SpriteDeletedPayload {
  /**
   * 关联的角色名称。
   */
  characterName: string;
  /**
   * 子目录名称。
   */
  subfolderName: string;
  /**
   * 被删除的立绘名称。
   */
  spriteName: string;
  /**
   * 被删除文件的存储路径。
   */
  path: string;
}

/**
 * 表情切换事件发布时携带的载荷。
 */
export interface SpriteExpressionChangedPayload {
  /**
   * 关联的角色名称。
   */
  characterName: string;
  /**
   * 子目录名称。
   */
  subfolderName: string;
  /**
   * 切换后的表情标签。
   */
  expression: string;
  /**
   * 切换后的立绘名称。
   */
  spriteName: string;
  /**
   * 切换后立绘的存储路径。
   */
  path: string;
}
