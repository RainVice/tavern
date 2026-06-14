/**
 * 描述调用表情图能力时需要传入的参数。
 * 用于 uploadSprite 方法定义上传一张角色表情图所需的信息，最终存储为 SpriteRecord 并写入文件存储。
 */
export interface SpriteUploadParams {
  /**
   * 角色名称，用于构建文件存储路径和内存索引键名 "characterName:subfolderName:spriteName"，
   * 由 uploadSprite 内部通过 safePathSegment 进行安全化处理。
   */
  characterName: string;
  /**
   * 子文件夹名称，用于细分表情图分类（如按表情集分组），可为空字符串。
   * 由 uploadSprite 内部通过 safeOptionalSegment 进行安全化处理。
   */
  subfolderName: string;
  /**
   * 表情图的显示标签，用于在 UI 表情选择器中展示该表情的描述名称（如 "开心"、"难过"）。
   */
  label: string;
  /**
   * 表情图名称（不含扩展名），用于构建文件名和内存索引键名，
   * 由 uploadSprite 内部通过 safePathSegment 进行安全化处理。
   */
  spriteName: string;
  /**
   * 表情图实际文件名（含扩展名），用于提取文件扩展名以确定图片保存格式。
   */
  fileName: string;
  /**
   * 图片的 MIME 类型（如 "image/png"、"image/jpeg"），存储在 SpriteRecord 中供后续读取时判断图片格式。
   */
  mimeType: string;
  /**
   * 表情图的 Base64 编码图片内容，由 uploadSprite 写入文件存储供后续展示使用。
   */
  content: string;
}

/**
 * 描述表情图模块在运行时交换的数据结构。
 * 用于从 Risu 格式的数据中导入表情图，包含标签和图片内容。
 */
export interface RisuSpriteImport {
  /**
   * 表情图的显示标签，在 importRisuSprites 中同时作为 label 和 spriteName 使用。
   */
  label: string;
  /**
   * 表情图的 Base64 编码图片内容，在 importRisuSprites 中传到 uploadSprite 写入文件存储。
   */
  content: string;
}

/**
 * 描述表情图持久化或内存索引中的一条记录。
 * 由 uploadSprite 创建并存储在 records 映射中，代表一张已上传的角色表情图。
 */
export interface SpriteRecord {
  /**
   * 数据结构的 schema 版本号，用于未来的数据格式迁移检测。
   */
  schemaVersion: number;
  /**
   * 角色名称，在 records 映射中与 subfolderName、spriteName 组合为唯一键。
   */
  characterName: string;
  /**
   * 子文件夹名称，用于细分表情图分类，为空字符串时存储在默认 sprites 目录。
   */
  subfolderName: string;
  /**
   * 表情图的显示标签，用于在 UI 表情选择器中展示给用户选择。
   */
  label: string;
  /**
   * 表情图名称（不含扩展名），用于构建存储路径和索引键。
   */
  spriteName: string;
  /**
   * 表情图实际文件名（含扩展名），用于写入文件存储时确定最终文件名。
   */
  fileName: string;
  /**
   * 图片的 MIME 类型，用于在展示时正确解码图片内容。
   */
  mimeType: string;
  /**
   * 表情图文件在存储中的路径，由 uploadSprite 构建，用于 deleteSprite 删除文件。
   */
  path: string;
  /**
   * 表情图的 Base64 编码图片内容，由 uploadSprite 写入文件存储供后续展示使用。
   */
  content: string;
  /**
   * 表情图创建时的时间戳（毫秒），用于在管理界面按创建时间排序。
   */
  createdAt: number;
  /**
   * 表情图最近更新时的时间戳（毫秒），标识最后被替换或更新的时间。
   */
  updatedAt: number;
}

/**
 * 描述表情图持久化或内存索引中的一条记录。
 * 由 setExpression 创建并存储在 selections 映射中，代表当前角色正在使用的表情选择状态。
 */
export interface SpriteSelectionRecord {
  /**
   * 角色名称，与 subfolderName 组合为选择状态键名 "characterName:subfolderName"。
   */
  characterName: string;
  /**
   * 子文件夹名称，与 characterName 组合为选择状态键名。
   */
  subfolderName: string;
  /**
   * 当前表情的名称（如 "happy"、"sad"），由用户在 UI 中选择，用于标识当前显示的表情。
   */
  expression: string;
  /**
   * 表情图名称（不含扩展名），对应 SpriteRecord 中的 spriteName，用于查找对应的图片文件。
   */
  spriteName: string;
  /**
   * 表情图文件在存储中的路径，由 setExpression 在查找 SpriteRecord 时填充，供 UI 直接加载图片使用。
   */
  path: string;
  /**
   * 选择记录最近更新时的时间戳（毫秒），用于追踪表情切换时间。
   */
  updatedAt: number;
}

/**
 * 描述表情图事件发布时携带的数据结构。
 * 当 uploadSprite 方法上传或替换表情图时，通过事件总线通知宿主或其他模块。
 */
export interface SpriteUploadedPayload {
  /**
   * 被上传或更新的表情图记录，宿主可监听 "sprite.uploaded" 事件来刷新 UI 表情列表。
   */
  sprite: SpriteRecord;
}

/**
 * 描述表情图事件发布时携带的数据结构。
 * 当 deleteSprite 方法删除表情图时，通过事件总线通知宿主或其他模块。
 */
export interface SpriteDeletedPayload {
  /**
   * 角色名称，用于在被删除的表情图所属的角色范围内刷新 UI。
   */
  characterName: string;
  /**
   * 子文件夹名称，用于在被删除的表情图所属的子文件夹范围内刷新 UI。
   */
  subfolderName: string;
  /**
   * 被删除的表情图名称，宿主可监听 "sprite.deleted" 事件来移除对应的 UI 显示。
   */
  spriteName: string;
  /**
   * 表情图文件在存储中的路径，宿主可据此判断是否需要清理引用。
   */
  path: string;
}

/**
 * 描述表情图事件发布时携带的数据结构。
 * 当 setExpression 方法切换表情时，通过事件总线通知宿主或其他模块更新 UI 显示。
 */
export interface SpriteExpressionChangedPayload {
  /**
   * 角色名称，宿主可监听 "sprite.expression.changed" 事件来更新对应角色的表情显示。
   */
  characterName: string;
  /**
   * 子文件夹名称，用于确定表情变更发生的子文件夹范围。
   */
  subfolderName: string;
  /**
   * 当前表情的名称（如 "happy"、"sad"），宿主根据此名称在 UI 中展示对应的表情图。
   */
  expression: string;
  /**
   * 表情图名称，对应 SpriteRecord.spriteName，用于加载具体的图片文件。
   */
  spriteName: string;
  /**
   * 表情图文件在存储中的路径，供 UI 直接加载图片使用。
   */
  path: string;
}
