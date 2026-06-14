import { EventBus } from '../runtime/EventBus';
import type { BackupKind } from '../contracts/PublicContracts';
import { isSafeRelativePath } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  BackupArchive,
  BackupCompletedPayload,
  BackupManifestEntry,
  BackupRestoredPayload,
  BackupRestoreResult,
  BackupValidationResult,
} from './BackupModels';

/**
 * 提供备份恢复相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class BackupRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 创建备份的自增计数器，用作备份标识后缀。
   */
  private backupCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 创建新的备份归档，写入存储并返回副本。
   * @param rootPath Tavern 数据根路径。
   * @param destinationPath 备份文件写入路径。
   * @param kind 备份类型。
   * @returns 新创建的备份归档副本。
   */
  async createBackup(rootPath: string, destinationPath: string, kind: BackupKind): Promise<BackupArchive> {
    return this.createBackupInternal(rootPath, destinationPath, kind, 'manual');
  }

  /**
   * 创建迁移场景下的备份归档，写入存储并返回副本。
   * @param rootPath Tavern 数据根路径。
   * @param reason 触发迁移备份的原因描述。
   * @returns 新创建的迁移备份归档副本。
   */
  async createMigrationBackup(rootPath: string, reason: string): Promise<BackupArchive> {
    return this.createBackupInternal(rootPath, `backups/migration-${this.backupCounter + 1}.json`, 'migration', reason);
  }

  /**
   * 校验备份归档中各条目是否满足路径安全、内容一致性和校验和约束。
   * @param archive 待校验的备份归档。
   * @returns 校验结果，包含是否通过及错误详情列表。
   */
  validateArchive(archive: BackupArchive): BackupValidationResult {
    const errors = new Array<string>();
    for (let index = 0; index < archive.entries.length; index += 1) {
      const entry = archive.entries[index];
      if (!isSafeRelativePath(entry.path)) {
        errors.push(`Unsafe path: ${entry.path}`);
      }
      if (entry.size !== entry.content.length) {
        errors.push(`Size mismatch: ${entry.path}`);
      }
      if (entry.checksum !== this.checksum(entry.content)) {
        errors.push(`Checksum mismatch: ${entry.path}`);
      }
    }
    return {
      valid: errors.length === 0,
      errors: errors,
    };
  }

  /**
   * 还原备份归档到指定目标根路径下。
   * @param archive 待还原的备份归档。
   * @param targetRootPath 还原目标根路径。
   * @returns 还原操作结果，包含已还原和跳过的路径列表。
   */
  async restoreBackup(archive: BackupArchive, targetRootPath: string): Promise<BackupRestoreResult> {
    const validation = this.validateArchive(archive);
    if (!validation.valid) {
      throw new Error(`Invalid backup archive: ${validation.errors.join(', ')}`);
    }
    const restoredPaths = new Array<string>();
    for (let index = 0; index < archive.entries.length; index += 1) {
      const entry = archive.entries[index];
      const destinationPath = this.joinPath(targetRootPath, entry.path);
      await this.files.writeText(destinationPath, entry.content, true);
      restoredPaths.push(destinationPath);
    }
    const result: BackupRestoreResult = {
      backupId: archive.id,
      restoredPaths: restoredPaths,
      skippedPaths: new Array<string>(),
    };
    const payload: BackupRestoredPayload = {
      result: this.copyRestoreResult(result),
    };
    this.events.publish<BackupRestoredPayload>('backup.restored', payload);
    return this.copyRestoreResult(result);
  }

  /**
   * 创建内部备份归档，写入存储并返回副本。
   * @param rootPath Tavern 数据根路径。
   * @param destinationPath 备份文件写入路径。
   * @param kind 备份类型。
   * @param reason 创建备份的原因描述。
   * @returns 新创建的备份归档副本。
   */
  private async createBackupInternal(rootPath: string, destinationPath: string, kind: BackupKind, reason: string): Promise<BackupArchive> {
    this.backupCounter += 1;
    const entries = new Array<BackupManifestEntry>();
    await this.collectEntries(rootPath, rootPath, entries);
    entries.sort((left: BackupManifestEntry, right: BackupManifestEntry) => left.path.localeCompare(right.path));
    const archive: BackupArchive = {
      id: `backup-${this.backupCounter}`,
      kind: kind,
      rootPath: rootPath,
      reason: reason,
      createdAt: Date.now(),
      entries: entries,
    };
    await this.files.writeText(destinationPath, JSON.stringify(archive), false);
    const payload: BackupCompletedPayload = {
      backupId: archive.id,
      path: destinationPath,
      archive: this.copyArchive(archive),
    };
    this.events.publish<BackupCompletedPayload>('backup.completed', payload);
    return this.copyArchive(archive);
  }
  private async collectEntries(rootPath: string, currentPath: string, entries: Array<BackupManifestEntry>): Promise<void> {
    const children = await this.files.list(currentPath);
    if (children.length === 0) {
      await this.addFileEntry(rootPath, currentPath, entries);
      return;
    }

    for (let index = 0; index < children.length; index += 1) {
      await this.collectEntries(rootPath, this.joinPath(currentPath, children[index]), entries);
    }
  }

  /**
   * 将单个文件条目加入备份清单。
   * @param rootPath 备份根路径，用于计算相对路径。
   * @param path 文件绝对路径。
   * @param entries 待填充的备份条目列表。
   */
  private async addFileEntry(rootPath: string, path: string, entries: Array<BackupManifestEntry>): Promise<void> {
    try {
      const content = await this.files.readText(path);
      const entry: BackupManifestEntry = {
        path: this.relativePath(rootPath, path),
        content: content,
        checksum: this.checksum(content),
        size: content.length,
      };
      entries.push(entry);
    } catch (_error) {
      return;
    }
  }

  /**
   * 计算给定文本内容的校验和字符串。
   * @param content 待计算校验和的文本内容。
   */
  private checksum(content: string): string {
    let sum = 0;
    for (let index = 0; index < content.length; index += 1) {
      sum = (sum + content.charCodeAt(index) * (index + 1)) % 2147483647;
    }
    return `${content.length}:${sum}`;
  }
  private relativePath(rootPath: string, path: string): string {
    if (path === rootPath) {
      return '';
    }
    const prefix = `${rootPath}/`;
    if (path.startsWith(prefix)) {
      return path.substring(prefix.length);
    }
    return path;
  }
  private joinPath(left: string, right: string): string {
    if (left.length === 0) {
      return right;
    }
    if (right.length === 0) {
      return left;
    }
    return `${left}/${right}`;
  }

  /**
   * 深拷贝备份归档，避免外部修改内部状态。
   * @param archive 源归档对象。
   */
  private copyArchive(archive: BackupArchive): BackupArchive {
    const entries = new Array<BackupManifestEntry>();
    for (let index = 0; index < archive.entries.length; index += 1) {
      entries.push(this.copyEntry(archive.entries[index]));
    }
    return {
      id: archive.id,
      kind: archive.kind,
      rootPath: archive.rootPath,
      reason: archive.reason,
      createdAt: archive.createdAt,
      entries: entries,
    };
  }

  /**
   * 深拷贝备份条目，避免外部修改内部状态。
   * @param entry 源条目对象。
   */
  private copyEntry(entry: BackupManifestEntry): BackupManifestEntry {
    return {
      path: entry.path,
      content: entry.content,
      checksum: entry.checksum,
      size: entry.size,
    };
  }

  /**
   * 深拷贝还原结果，避免外部修改内部状态。
   * @param result 源结果对象。
   */
  private copyRestoreResult(result: BackupRestoreResult): BackupRestoreResult {
    return {
      backupId: result.backupId,
      restoredPaths: result.restoredPaths.slice(),
      skippedPaths: result.skippedPaths.slice(),
    };
  }
}
