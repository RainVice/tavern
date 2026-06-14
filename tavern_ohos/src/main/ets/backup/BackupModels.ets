import type { BackupKind } from '../contracts/PublicContracts';

/**
 * 描述备份恢复持久化或内存索引中的一条记录。
 */
export interface BackupManifestEntry {
  /**
   * 路径。
   */
  path: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * checksum 值，由当前实例内部维护。
   */
  checksum: string;
  /**
   * size 值，由当前实例内部维护。
   */
  size: number;
}

/**
 * 描述备份恢复模块在运行时交换的数据结构。
 */
export interface BackupArchive {
  /**
   * 标识。
   */
  id: string;
  /**
   * kind 值，由当前实例内部维护。
   */
  kind: BackupKind;
  /**
   * 数据根路径。
   */
  rootPath: string;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * 条目列表，由当前实例内部维护。
   */
  entries: Array<BackupManifestEntry>;
}

/**
 * 描述备份恢复操作完成后返回给调用方的结果。
 */
export interface BackupValidationResult {
  /**
   * valid 值，由当前实例内部维护。
   */
  valid: boolean;
  /**
   * errors 列表，由当前实例内部维护。
   */
  errors: Array<string>;
}

/**
 * 描述备份恢复操作完成后返回给调用方的结果。
 */
export interface BackupRestoreResult {
  /**
   * backup 标识。
   */
  backupId: string;
  /**
   * restored Paths 列表，由当前实例内部维护。
   */
  restoredPaths: Array<string>;
  /**
   * skipped Paths 列表，由当前实例内部维护。
   */
  skippedPaths: Array<string>;
}

/**
 * 描述备份恢复事件发布时携带的数据结构。
 */
export interface BackupCompletedPayload {
  /**
   * backup 标识。
   */
  backupId: string;
  /**
   * 路径。
   */
  path: string;
  /**
   * archive 值，由当前实例内部维护。
   */
  archive: BackupArchive;
}

/**
 * 描述备份恢复事件发布时携带的数据结构。
 */
export interface BackupRestoredPayload {
  /**
   * 处理结果。
   */
  result: BackupRestoreResult;
}
