/**
 * 描述调用附件能力时需要传入的参数，用于在创建附件流程中指定附件的内容、类型和行为标记。
 */
export interface AttachmentCreateParams {
  /**
   * 附件唯一标识，用于在附件管理流程中全局索引和引用该附件。
   */
  id: string;
  /**
   * 附件种类（如 text、image、file），用于在创建和查询流程中区分附件的内容形式。
   */
  kind: string;
  /**
   * 文件名称，用于在附件列表展示和 Prompt 构建中标识附件的原始文件名。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型，用于在处理流程中识别附件的数据格式。
   */
  mimeType: string;
  /**
   * 附件内容在存储中的路径，用于在读取附件内容时定位磁盘文件。
   */
  storagePath: string;
  /**
   * 附件的内容数据，在创建流程中直接存入记录供后续读取或 Prompt 构建使用。
   */
  content: string;
  /**
   * 是否在构建 Prompt 时包含该附件内容，用于在 Prompt 组装流程中决定是否将附件纳入上下文。
   */
  includeInPrompt: boolean;
  /**
   * 是否将该附件纳入 RAG（检索增强生成）索引，用于在知识检索流程中决定是否为该附件建立索引。
   */
  includeInRag: boolean;
  /**
   * 附件的图片描述（caption）文本，用于在附件标注流程中存储图片内容描述，在 Prompt 构建时优先使用。
   */
  captionText: string;
  /**
   * 附件的翻译文本，用于在多语言处理流程中存储附件内容的翻译结果。
   */
  translationText: string;
  /**
   * 附件的元数据 JSON 字符串，用于在存储和查询流程中附带附加信息。
   */
  metadataJson: string;
}

/**
 * 描述附件持久化或内存索引中的一条记录，用于在附件各管理流程（创建、查询、标注、导出、删除）中代表一个附件项。
 */
export interface AttachmentRecord {
  /**
   * 记录结构的 schema 版本号，用于在数据迁移流程中判断旧版本数据是否需要升级。
   */
  schemaVersion: number;
  /**
   * 附件唯一标识，用于在附件管理流程中全局索引和引用。
   */
  id: string;
  /**
   * 附件种类（如 text、image、file），用于在查询和 Prompt 构建流程中区分附件类型。
   */
  kind: string;
  /**
   * 文件名称，在附件展示和 Prompt 构建流程中使用的原始文件名。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型，用于在处理流程中识别附件的数据格式。
   */
  mimeType: string;
  /**
   * 附件内容在存储中的路径，用于在读取附件内容时定位磁盘文件。
   */
  storagePath: string;
  /**
   * 附件的内容数据，在创建流程中存入，在读取和 Prompt 构建流程中使用。
   */
  content: string;
  /**
   * 是否在构建 Prompt 时包含该附件，用于在 Prompt 组装流程中决定附件是否作为上下文的一部分。
   */
  includeInPrompt: boolean;
  /**
   * 是否将该附件纳入 RAG 索引，用于在知识检索流程中决定是否为附件建立向量索引。
   */
  includeInRag: boolean;
  /**
   * 附件的图片描述文本，在标注流程中由 caption 服务填充，在 Prompt 构建时优先于原始内容。
   */
  captionText: string;
  /**
   * 附件的翻译文本，在翻译流程中由翻译服务填充，用于多语言对话场景。
   */
  translationText: string;
  /**
   * 附件的元数据 JSON 字符串，用于在存储和查询流程中附带额外信息。
   */
  metadataJson: string;
  /**
   * 附件是否已被标记为删除，用于在软删除流程中标记附件不再可用，查询时过滤已删除项。
   */
  deleted: boolean;
  /**
   * 记录创建时间戳（毫秒），用于追踪附件创建的起始时刻。
   */
  createdAt: number;
  /**
   * 记录最近更新时间戳（毫秒），用于追踪附件内容或标注的变更时机。
   */
  updatedAt: number;
}

/**
 * 描述附件与目标对象的绑定关系，用于在附件绑定流程中将附件关联到角色、消息或个人资料等目标。
 */
export interface AttachmentBindingRecord {
  /**
   * 被绑定的附件唯一标识，用于在绑定查询流程中定位附件记录。
   */
  attachmentId: string;
  /**
   * 目标对象的类型（如 character、message、persona），用于在附件查询流程中按目标类型筛选。
   */
  targetType: string;
  /**
   * 目标对象的唯一标识，用于在附件查询流程中定位特定目标的绑定附件。
   */
  targetId: string;
  /**
   * 绑定的创建时间戳（毫秒），用于追踪绑定关系建立的时间。
   */
  createdAt: number;
}

/**
 * 描述用于 Prompt 构建的附件摘要记录，在 Prompt 组装流程中由运行时生成，供 Prompt 引擎使用。
 */
export interface AttachmentPromptRecord {
  /**
   * 附件唯一标识，用于在 Prompt 内容中引用附件来源。
   */
  attachmentId: string;
  /**
   * 附件种类（如 text、image、file），用于在 Prompt 中按附件类型格式化内容。
   */
  kind: string;
  /**
   * 文件名称，用于在 Prompt 中标识附件的原始文件名。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型，用于在 Prompt 中确定附件内容的处理方式。
   */
  mimeType: string;
  /**
   * 附件内容（caption 优先，回退到原始内容），在 Prompt 构建时作为附件上下文提供给模型。
   */
  content: string;
}

/**
 * 描述附件模块的导出数据结构，用于在备份或与外部系统数据互通时将附件记录及其绑定关系一起导出。
 */
export interface AttachmentExportData {
  /**
   * 导出的附件记录，包含附件的内容和所有元信息，在导出流程中序列化保存。
   */
  attachment: AttachmentRecord;
  /**
   * 与该附件关联的绑定关系列表，在导出流程中一并保存以保持引用的完整性。
   */
  bindings: Array<AttachmentBindingRecord>;
}

/**
 * 描述附件添加事件发布时携带的数据结构，在附件绑定流程完成后由运行时发布，供 UI 或外部模块响应。
 */
export interface AttachmentAddedPayload {
  /**
   * 被添加的附件唯一标识，用于监听方定位新增附件。
   */
  attachmentId: string;
  /**
   * 绑定目标对象的类型，用于监听方判断附件所属的模块。
   */
  targetType: string;
  /**
   * 绑定目标对象的标识，用于监听方在目标对象上更新附件关联。
   */
  targetId: string;
  /**
   * 被添加的附件记录，包含完整信息，在事件中传递供监听方直接使用。
   */
  attachment: AttachmentRecord;
}

/**
 * 描述附件删除事件发布时携带的数据结构，在附件删除流程中由运行时发布，供 UI 或外部模块响应。
 */
export interface AttachmentDeletedPayload {
  /**
   * 被删除的附件唯一标识，用于监听方定位和移除相关引用。
   */
  attachmentId: string;
}

/**
 * 描述附件更新事件发布时携带的数据结构，在附件内容（如 caption、翻译结果）更新后由运行时发布。
 */
export interface AttachmentUpdatedPayload {
  /**
   * 更新后的附件记录，包含最新字段值，在事件中传递供监听方刷新展示。
   */
  attachment: AttachmentRecord;
}
