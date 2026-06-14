/**
 * 描述调用图片资源能力时需要传入的参数。
 * 用于图片上传流程，由 UI 层收集图片数据和附件关联信息后传入 ImageRuntime.uploadImage()。
 */
export interface ImageUploadParams {
  /**
   * 图片资源唯一标识，用于在上传流程中追踪图片记录和在内存索引中建立映射。
   */
  id: string;
  /**
   * 上传后的文件名，用于生成最终存储在文件系统中的文件名。
   */
  fileName: string;
  /**
   * 图片格式扩展名，如 png、jpg、webp，用于校验格式合法性及生成带正确扩展名的文件。
   */
  format: string;
  /**
   * 图片存放的子目录名称，用于在图片存储根路径下按文件夹分类组织图片文件。
   */
  folderName: string;
  /**
   * 图片的 MIME 类型，如 image/png，用于附件创建时记录媒体类型信息。
   */
  mimeType: string;
  /**
   * Base64 编码的图片数据内容，用于实际写入文件系统持久化存储。
   */
  content: string;
  /**
   * 缩略图的 MIME 类型，用于决定缩略图生成的格式。空字符串表示不生成缩略图。
   */
  thumbnailType: string;
  /**
   * Base64 编码的缩略图数据内容，用于写入缩略图文件系统存储。
   */
  thumbnailContent: string;
  /**
   * 缩略图宽度（像素），用于传递给缩略图运行时以生成指定尺寸的缩略图。
   */
  thumbnailWidth: number;
  /**
   * 缩略图高度（像素），用于传递给缩略图运行时以生成指定尺寸的缩略图。
   */
  thumbnailHeight: number;
  /**
   * 附件关联的唯一标识，用于将图片绑定到目标对象（如角色头像、聊天消息）。空字符串表示不关联附件。
   */
  attachmentId: string;
  /**
   * 附件目标对象的类型，如 character、chat，用于附件运行时确定绑定目标所属表。
   */
  attachmentTargetType: string;
  /**
   * 附件目标对象的唯一标识，用于附件运行时确定绑定目标的具体记录。
   */
  attachmentTargetId: string;
  /**
   * 是否在提示词中包含该图片引用，用于附件创建时设置附件在构造消息时是否参与提示词渲染。
   */
  includeInPrompt: boolean;
  /**
   * 是否在 RAG 检索中包含该图片引用，用于附件创建时设置附件在检索增强生成流程中是否可被检索。
   */
  includeInRag: boolean;
}

/**
 * 描述图片资源持久化或内存索引中的一条记录。
 * 用于图片上传完成后在 ImageRuntime 内存中缓存、写入 index.json 索引文件以及通过事件发布给外部订阅者。
 */
export interface ImageRecord {
  /**
   * 数据结构的版本号，用于序列化/反序列化时的向后兼容，确保未来扩展时能区分旧版记录。
   */
  schemaVersion: number;
  /**
   * 图片资源唯一标识，作为内存索引 Map 的键，用于查找、删除和事件追踪。
   */
  id: string;
  /**
   * 图片文件名（含格式扩展名），用于生成文件系统存储路径和文件操作。
   */
  fileName: string;
  /**
   * 图片格式扩展名，如 png、jpg、webp，用于格式校验和日志记录。
   */
  format: string;
  /**
   * 图片存放的子目录名称，用于按文件夹分类组织图片文件系统路径。
   */
  folderName: string;
  /**
   * 图片的 MIME 类型，用于附件创建时记录和后续媒体处理。
   */
  mimeType: string;
  /**
   * 图片文件的存储路径，用于 readImageContent() 读取文件内容和 deleteImage() 删除文件。
   */
  path: string;
  /**
   * Base64 编码的图片数据内容，用于快速读取和写入文件系统。
   */
  content: string;
  /**
   * 缩略图的 MIME 类型，用于标识缩略图格式。空字符串表示未生成缩略图。
   */
  thumbnailType: string;
  /**
   * 缩略图文件的存储路径，用于 deleteImage() 清理缩略图文件时定位。
   */
  thumbnailPath: string;
  /**
   * 附件关联的唯一标识，用于在 deleteImage() 中通过 AttachmentRuntime.deleteAttachment() 清理关联的附件记录。
   */
  attachmentId: string;
  /**
   * 记录创建时间戳（毫秒），用于记录排序和状态跟踪。新记录使用当前时间，已存在记录保留原创建时间。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（毫秒），用于判断数据时效性和冲突检测。
   */
  updatedAt: number;
}

/**
 * 描述图片资源事件发布时携带的数据结构。
 * 用于 ImageRuntime.uploadImage() 完成后发布 'image.uploaded' 事件时传递给订阅者（如 UI 层的图库刷新）。
 */
export interface ImageUploadedPayload {
  /**
   * 上传完成后的图片记录对象，包含完整的元数据、文件路径和附件信息，订阅者可据此更新 UI 或触发后续流程。
   */
  image: ImageRecord;
}

/**
 * 描述图片资源删除事件发布时携带的数据结构。
 * 用于 ImageRuntime.deleteImage() 完成后发布 'image.deleted' 事件时传递给订阅者（如 UI 层的图库清理）。
 */
export interface ImageDeletedPayload {
  /**
   * 被删除图片的唯一标识，订阅者可通过此 ID 从本地缓存或 UI 列表中移除对应条目。
   */
  imageId: string;
  /**
   * 被删除图片的存储路径，用于在事件订阅者侧确认文件已被清理。
   */
  path: string;
}

/**
 * 描述图片索引持久化到磁盘时的整体数据结构。
 * 用于 ImageRuntime 写入 index.json 文件时序列化的顶级结构，应用启动时反序列化恢复图片索引。
 */
export interface ImageIndexData {
  /**
   * 全部图片记录的列表，用于持久化到 index.json 文件以及从磁盘恢复所有图片索引到内存。
   */
  images: Array<ImageRecord>;
}
