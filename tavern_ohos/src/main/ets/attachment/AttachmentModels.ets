import type {
  AttachmentKind,
  TavernScope,
} from '../contracts/PublicContracts';

/**
 * 创建附件时所需的输入参数，涵盖标识、类型、文件信息和关联配置。
 */
export interface AttachmentCreateParams {
  /**
   * 附件唯一标识。
   */
  id: string;
  /**
   * 附件类型（如文本、图片、文件等）。
   */
  kind: AttachmentKind;
  /**
   * 原始文件名。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型。
   */
  mimeType: string;
  /**
   * 文件在存储系统中的路径。
   */
  storagePath: string;
  /**
   * 附件文本内容。
   */
  content: string;
  /**
   * 是否在构造提示词时包含此附件。
   */
  includeInPrompt: boolean;
  /**
   * 是否在 RAG 检索时包含此附件。
   */
  includeInRag: boolean;
  /**
   * 图片描述或图注文本。
   */
  captionText: string;
  /**
   * 翻译后的文本内容。
   */
  translationText: string;
  /**
   * 自定义元数据，以 JSON 字符串形式存储。
   */
  metadataJson: string;
}

/**
 * 附件在持久化存储或内存索引中的完整记录，包含所有元数据和状态。
 */
export interface AttachmentRecord {
  /**
   * 数据模式版本号，用于数据迁移时区分格式。
   */
  schemaVersion: number;
  /**
   * 附件唯一标识。
   */
  id: string;
  /**
   * 附件类型（如文本、图片、文件等）。
   */
  kind: AttachmentKind;
  /**
   * 原始文件名。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型。
   */
  mimeType: string;
  /**
   * 文件在存储系统中的路径。
   */
  storagePath: string;
  /**
   * 附件文本内容。
   */
  content: string;
  /**
   * 是否在构造提示词时包含此附件。
   */
  includeInPrompt: boolean;
  /**
   * 是否在 RAG 检索时包含此附件。
   */
  includeInRag: boolean;
  /**
   * 图片描述或图注文本。
   */
  captionText: string;
  /**
   * 翻译后的文本内容。
   */
  translationText: string;
  /**
   * 自定义元数据，以 JSON 字符串形式存储。
   */
  metadataJson: string;
  /**
   * 是否已标记为删除（逻辑删除）。
   */
  deleted: boolean;
  /**
   * 记录创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 附件与业务作用域之间的绑定关系，记录附件挂载到哪个业务实体上。
 */
export interface AttachmentBindingRecord {
  /**
   * 附件唯一标识。
   */
  attachmentId: string;
  /**
   * 目标作用域类型（如消息、角色等）。
   */
  targetType: TavernScope;
  /**
   * 目标作用域内实体的唯一标识。
   */
  targetId: string;
  /**
   * 绑定创建时间戳（毫秒）。
   */
  createdAt: number;
}

/**
 * 用于提示词构造的附件精简记录，仅包含构造提示词所需的字段。
 */
export interface AttachmentPromptRecord {
  /**
   * 附件唯一标识。
   */
  attachmentId: string;
  /**
   * 附件类型（如文本、图片、文件等）。
   */
  kind: AttachmentKind;
  /**
   * 原始文件名。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型。
   */
  mimeType: string;
  /**
   * 附件文本内容（用于提示词）。
   */
  content: string;
}

/**
 * 附件模块用于运行时导入导出的完整数据包，包含记录及其绑定关系。
 */
export interface AttachmentExportData {
  /**
   * 附件记录。
   */
  attachment: AttachmentRecord;
  /**
   * 与该附件关联的绑定关系列表。
   */
  bindings: Array<AttachmentBindingRecord>;
}

/**
 * 附件添加事件所携带的载荷数据。
 */
export interface AttachmentAddedPayload {
  /**
   * 被添加附件的唯一标识。
   */
  attachmentId: string;
  /**
   * 附件绑定的目标作用域类型。
   */
  targetType: TavernScope;
  /**
   * 附件绑定的目标作用域内实体标识。
   */
  targetId: string;
  /**
   * 被添加的附件记录。
   */
  attachment: AttachmentRecord;
}

/**
 * 附件删除事件所携带的载荷数据。
 */
export interface AttachmentDeletedPayload {
  /**
   * 被删除附件的唯一标识。
   */
  attachmentId: string;
}

/**
 * 附件更新事件所携带的载荷数据。
 */
export interface AttachmentUpdatedPayload {
  /**
   * 更新后的附件记录。
   */
  attachment: AttachmentRecord;
}
