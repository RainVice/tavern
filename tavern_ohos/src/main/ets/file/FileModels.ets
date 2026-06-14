/**
 * 描述调用上传文件能力时需要传入的参数，
 * 用于在宿主或其他模块上传文件到运行时存储时，提供完整的文件元数据、内容和关联信息。
 */
export interface FileUploadParams {
  /**
   * 文件的全局唯一标识，
   * 用于在 FileRuntime 的 records 索引中标识和查找该文件记录。
   */
  id: string;
  /**
   * 原始文件名，上传后经 sanitizeFileName 清理不安全字符后作为持久化文件名，
   * 用于生成存储在磁盘上的实际文件路径。
   */
  fileName: string;
  /**
   * MIME 类型，标识文件的内容格式（如 'image/png'、'text/plain'），
   * 用于在附件关联和数据银行文档中记录文件格式信息。
   */
  mimeType: string;
  /**
   * 文件内容（Base64 编码或纯文本数据），
   * 用于写入物理存储文件及作为附件/数据银行文档的内容。
   */
  content: string;
  /**
   * 关联的附件标识，用于上传后将此文件绑定到指定的附件记录，
   * 实现文件与消息或角色的关联。空字符串表示不创建附件。
   */
  attachmentId: string;
  /**
   * 附件关联的目标类型，如 'message'、'character'，
   * 用于在创建附件绑定时指定该文件附加到哪个类型的对象上。
   */
  attachmentTargetType: string;
  /**
   * 附件关联的目标标识（如消息 ID 或角色 ID），
   * 用于在创建附件绑定时指定该文件关联到哪个具体的对象实例。
   */
  attachmentTargetId: string;
  /**
   * 是否在 AI 提示词中包含该文件内容，
   * 用于控制该附件是否参与 AI 生成上下文。
   */
  includeInPrompt: boolean;
  /**
   * 是否在 RAG（检索增强生成）索引中包含该文件，
   * 用于控制该文件内容是否被纳入知识库检索范围。
   */
  includeInRag: boolean;
  /**
   * 数据银行文档的唯一标识，
   * 用于在 uploadFile 流程中将文件内容同步创建为数据银行文档。空字符串表示不创建。
   */
  dataBankDocumentId: string;
  /**
   * 数据银行文档的作用域标识，
   * 用于创建数据银行文档时限定文档的属主或范围。
   */
  dataBankScope: string;
  /**
   * 数据银行文档的分类标签列表，
   * 用于创建数据银行文档时为文档附加分类标签，方便检索和过滤。
   */
  dataBankTags: Array<string>;
  /**
   * 文件的自定义元数据 JSON 字符串，
   * 用于存储除标准字段外的额外属性，随文件记录一同持久化。
   */
  metadataJson: string;
}

/**
 * 描述上传文件持久化或内存索引中的一条记录，
 * 用于在 FileRuntime 的 records 索引中存储已上传文件的完整快照。
 */
export interface FileRecord {
  /**
   * 数据模式的版本号，用于数据迁移兼容性判断，
   * 当未来 FileRecord 结构发生变化时据此执行数据升级逻辑。
   */
  schemaVersion: number;
  /**
   * 文件的全局唯一标识，
   * 作为 records 索引中的主键，用于查找、删除和读取文件。
   */
  id: string;
  /**
   * 经 sanitizeFileName 清理后的安全文件名，
   * 用于生成磁盘文件路径，避免路径遍历攻击。
   */
  fileName: string;
  /**
   * MIME 类型，标识文件的内容格式（如 'image/png'、'text/plain'），
   * 用于在附件和数据银行中记录文件格式信息。
   */
  mimeType: string;
  /**
   * 文件在存储中的绝对路径，
   * 用于读写物理文件内容以及验证文件是否存在。
   */
  path: string;
  /**
   * 文件内容（Base64 编码或纯文本数据），
   * 在 uploadFile 后存入内存索引，可通过 readFileContent 从磁盘重新读取。
   */
  content: string;
  /**
   * 关联的附件标识，用于将此文件与附件系统关联，
   * 在 deleteFile 时根据此字段清理关联的附件记录。
   */
  attachmentId: string;
  /**
   * 关联的数据银行文档标识，
   * 用于在 deleteFile 时根据此字段清理关联的数据银行文档。
   */
  dataBankDocumentId: string;
  /**
   * 文件的自定义元数据 JSON 字符串，
   * 除标准字段外的附加属性，由上传参数传入。
   */
  metadataJson: string;
  /**
   * 文件创建时间戳（毫秒），首次上传时设置，后续覆盖更新时保持不变。
   */
  createdAt: number;
  /**
   * 文件最后更新时间戳（毫秒），上传时和覆盖更新时刷新。
   */
  updatedAt: number;
}

/**
 * 描述上传文件操作完成后返回给调用方的结果，
 * 用于批量验证文件是否存在于安全路径内且可在磁盘上访问。
 */
export interface FileVerifyResult {
  /**
   * 原始的文件路径（与入参一致），
   * 用于在返回结果中与请求参数一一对应，方便调用方定位每条路径的验证状态。
   */
  path: string;
  /**
   * 标明文件是否实际存在于存储中，
   * 供调用方（如 UI 文件列表刷新）判断该文件记录对应的物理文件是否有效。
   */
  exists: boolean;
}

/**
 * 描述上传文件事件发布时携带的数据结构，
 * 用于在文件上传成功后通过 EventBus 广播给 UI 层或其他模块。
 */
export interface FileUploadedPayload {
  /**
   * 上传文件完成后的完整记录数据，
   * 供监听方（如 UI 文件列表、附件面板）基于此数据刷新展示。
   */
  file: FileRecord;
}

/**
 * 描述上传文件事件发布时携带的数据结构，
 * 用于在文件删除成功后通过 EventBus 广播给 UI 层或其他模块。
 */
export interface FileDeletedPayload {
  /**
   * 被删除文件的标识，
   * 供监听方据此从本地缓存或 UI 列表中移除对应条目。
   */
  fileId: string;
  /**
   * 被删除文件在存储中的路径，
   * 供监听方获取文件位置信息，用于日志记录或后续清理。
   */
  path: string;
}

/**
 * 描述上传文件模块在运行时交换的数据结构，
 * 用于将文件记录索引持久化为 index.json，供下次启动时恢复状态。
 */
export interface FileIndexData {
  /**
   * 所有文件记录的列表，
   * 由 persistIndex 写入 index.json，在应用启动时由宿主加载并恢复运行时状态。
   */
  files: Array<FileRecord>;
}
