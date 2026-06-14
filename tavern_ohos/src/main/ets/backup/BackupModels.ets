/**
 * 描述备份恢复持久化或内存索引中的一条记录，用于备份存档中包含的单个文件条目。
 */
export interface BackupManifestEntry {
  /**
   * 文件在存档中的相对路径，用于还原时定位写入位置。
   */
  path: string;
  /**
   * 文件内容的文本表示，用于还原时写入目标路径。
   */
  content: string;
  /**
   * 文件内容的校验和，用于完整性验证，确保备份在传输或存储过程中未被篡改。
   */
  checksum: string;
  /**
   * 文件内容字节数，用于大小校验，验证内容在还原时是否完整。
   */
  size: number;
}

/**
 * 描述备份恢复模块在运行时交换的数据结构，包含存档元数据和所有文件条目。
 */
export interface BackupArchive {
  /**
   * 备份的唯一标识，用于区分和管理多个备份存档。
   */
  id: string;
  /**
   * 备份类型标识（如 manual、migration），用于区分手动备份和迁移自动备份。
   */
  kind: string;
  /**
   * 备份时使用的数据根路径，用于还原时计算文件的相对路径。
   */
  rootPath: string;
  /**
   * 创建备份的原因说明（如迁移失败原因、手动备份等），用于记录备份背景。
   */
  reason: string;
  /**
   * 备份创建时间的时间戳（毫秒），用于备份历史排序和展示。
   */
  createdAt: number;
  /**
   * 备份中包含的文件条目列表，每条记录包含文件路径、内容、校验和和大小。
   */
  entries: Array<BackupManifestEntry>;
}

/**
 * 备份校验操作的结果，包含校验是否通过和具体的错误信息，用于在还原前验证存档完整性。
 */
export interface BackupValidationResult {
  /**
   * 校验是否全部通过，true 表示所有条目均通过路径安全性、大小匹配和校验和验证。
   */
  valid: boolean;
  /**
   * 校验过程中发现的错误描述列表，每条描述具体的问题条目和失败原因。
   */
  errors: Array<string>;
}

/**
 * 备份还原操作的结果，包含成功恢复和跳过的文件路径，用于向用户展示还原结果。
 */
export interface BackupRestoreResult {
  /**
   * 对应的备份标识，用于关联还原结果和备份存档。
   */
  backupId: string;
  /**
   * 成功还原的文件路径列表，标识这些文件已写入目标路径。
   */
  restoredPaths: Array<string>;
  /**
   * 跳过未还原的文件路径列表（如校验失败或路径不安全），标识这些文件未被写入。
   */
  skippedPaths: Array<string>;
}

/**
 * 备份完成事件发布时携带的数据结构，包含备份标识、路径和完整存档，用于通知其他模块备份已完成。
 */
export interface BackupCompletedPayload {
  /**
   * 备份的唯一标识，供事件订阅者查询和管理备份记录。
   */
  backupId: string;
  /**
   * 备份文件的存储路径，供事件订阅者访问备份文件。
   */
  path: string;
  /**
   * 备份完成后的完整存档数据，供事件订阅者读取备份内容。
   */
  archive: BackupArchive;
}

/**
 * 备份还原完成事件发布时携带的数据结构，包含还原结果，用于通知其他模块数据已恢复。
 */
export interface BackupRestoredPayload {
  /**
   * 还原操作的详细结果，包括成功恢复和跳过的文件路径。
   */
  result: BackupRestoreResult;
}
