import type { BackupKind } from '../contracts/PublicContracts';

/**
 * 描述备份恢复持久化或内存索引中的一条文件记录。
 */
export interface BackupManifestEntry {
  /**
   * 文件相对于备份根目录的相对路径。
   */
  path: string;
  /**
   * 文件原始文本内容。
   */
  content: string;
  /**
   * 校验和，由当前实例根据内容自动生成。
   */
  checksum: string;
  /**
   * 内容字节长度。
   */
  size: number;
}

/**
 * 描述备份恢复模块在运行时交换的归档数据结构。
 */
export interface BackupArchive {
  /**
   * 归档唯一标识符，格式为 backup-{自增序号}。
   */
  id: string;
  /**
   * 归档类型，区分手动备份与迁移备份。
   */
  kind: BackupKind;
  /**
   * 数据根路径。
   */
  rootPath: string;
  /**
   * 创建此归档的原因描述。
   */
  reason: string;
  /**
   * 归档创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 归档中包含的文件条目列表。
   */
  entries: Array<BackupManifestEntry>;
}

/**
 * 描述备份归档校验操作的结果。
 */
export interface BackupValidationResult {
  /**
   * 归档是否通过校验。
   */
  valid: boolean;
  /**
   * 校验过程中发现的错误信息列表。
   */
  errors: Array<string>;
}

/**
 * 描述备份还原操作的结果。
 */
export interface BackupRestoreResult {
  /**
   * 所还原的备份归档标识符。
   */
  backupId: string;
  /**
   * 成功还原的文件路径列表。
   */
  restoredPaths: Array<string>;
  /**
   * 因校验未通过等原因被跳过的文件路径列表。
   */
  skippedPaths: Array<string>;
}

/**
 * 描述备份完成事件（backup.completed）发布时携带的载荷。
 */
export interface BackupCompletedPayload {
  /**
   * 所完成备份的归档标识符。
   */
  backupId: string;
  /**
   * 备份文件写入的物理路径。
   */
  path: string;
  /**
   * 备份归档的不可变副本。
   */
  archive: BackupArchive;
}

/**
 * 描述备份还原事件（backup.restored）发布时携带的载荷。
 */
export interface BackupRestoredPayload {
  /**
   * 还原操作的执行结果。
   */
  result: BackupRestoreResult;
}
