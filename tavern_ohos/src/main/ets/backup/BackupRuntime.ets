import { EventBus } from '../runtime/EventBus';
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
 * 在数据迁移、手动备份和还原恢复流程中被调用，用于保障用户数据的安全性和可恢复性。
 */
export class BackupRuntime {
  /**
   * 文件存储适配器，用于读写备份存档文件和遍历数据目录。
   */
  private files: TavernFileStore;
  /**
   * 事件总线，用于发布备份完成和还原事件通知其他模块。
   */
  private events: EventBus;
  /**
   * 自增计数器，用于生成备份唯一标识（如 backup-1、backup-2）。
   */
  private backupCounter: number = 0;

  /**
   * 初始化当前运行时实例，注入文件存储和事件总线依赖，由宿主在应用启动时创建。
   * @param files 文件存储适配器，用于读写备份存档文件和遍历数据目录。
   * @param events 事件总线，用于发布备份完成和还原完成事件。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 创建手动备份：收集数据根路径下所有文件并写入目标路径，发布备份完成事件。
   * 在用户主动触发备份操作（如设置页面中的"创建备份"按钮）时调用。
   * @param rootPath Tavern 数据根路径，用于遍历和收集所有数据文件。
   * @param destinationPath 备份存档的目标写入路径，用于存储最终生成的备份文件。
   * @param kind 备份类型标识（如 manual），用于在存档记录中标记备份来源。
   * @returns 创建的备份存档对象，包含标识、时间戳和所有文件条目。
   */
  async createBackup(rootPath: string, destinationPath: string, kind: string): Promise<BackupArchive> {
    return this.createBackupInternal(rootPath, destinationPath, kind, 'manual');
  }

  /**
   * 创建迁移备份：在数据迁移前自动创建备份，以防迁移失败时数据丢失。
   * 在数据版本升级或格式变更时由迁移流程自动触发，无需用户干预。
   * @param rootPath Tavern 数据根路径，用于遍历和收集所有数据文件。
   * @param reason 触发迁移备份的原因说明（如版本升级、格式变更等），用于记录备份背景。
   * @returns 创建的迁移备份存档对象，包含标识、时间戳和所有文件条目。
   */
  async createMigrationBackup(rootPath: string, reason: string): Promise<BackupArchive> {
    return this.createBackupInternal(rootPath, `backups/migration-${this.backupCounter + 1}.json`, 'migration', reason);
  }

  /**
   * 校验备份存档的完整性：检查每个条目的路径安全性、内容大小和校验和是否正确。
   * 在还原备份之前调用，用于提前发现损坏或不安全的存档，避免还原操作造成数据异常。
   * @param archive 待校验的备份存档对象，包含所有文件条目。
   * @returns 校验结果，包含是否通过和所有错误详情，结果为 valid 时方可安全还原。
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
   * 还原备份存档：校验完整性后将每个条目还原到目标根路径下，并发布还原完成事件。
   * 在用户选择备份文件并确认还原时调用，用于将存档中的数据恢复到指定位置。
   * @param archive 待还原的备份存档，校验通过后执行还原操作。
   * @param targetRootPath 还原的目标根路径，存档中的相对路径将拼接在此路径下。
   * @returns 还原结果，包含成功恢复的路径列表（可在 UI 中展示完成状态）。
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
   * 内部方法：收集文件、构建备份存档、写入目标路径并发布完成事件。
   * 由 createBackup 和 createMigrationBackup 调用，统一处理文件收集和存档写入流程。
   * @param rootPath 数据根路径，用于计算文件相对路径和遍历目录。
   * @param destinationPath 备份存档的写入路径，用于存储最终的 JSON 存档文件。
   * @param kind 备份类型标识（manual / migration），用于存档记录分类。
   * @param reason 备份原因描述，用于描述触发备份的业务场景。
   * @returns 创建的备份存档对象，包含所有收集到的文件条目。
   */
  private async createBackupInternal(rootPath: string, destinationPath: string, kind: string, reason: string): Promise<BackupArchive> {
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
   * 添加单个文件到备份条目列表：读取文件内容并计算大小和校验和。
   * 在递归遍历目录时对每个文件执行，用于将文件元数据和内容纳入备份存档。
   * @param rootPath 数据根路径，用于计算文件在存档中的相对路径。
   * @param path 文件绝对路径（或相对于文件存储的路径），用于读取文件内容。
   * @param entries 备份条目列表，新条目将被追加到其中。
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
   * 计算字符串内容的简易校验和（基于字符编码值的加权求和），用于快速检测内容变化。
   * 在创建备份条目时对每个文件内容计算，用于还原时的完整性验证。
   * @param content 要计算校验和的文本内容，通常是文件内容的完整字符串。
   * @returns 格式为 "长度:加权和" 的校验和字符串，用于还原时比对内容一致性。
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
   * 复制 BackupArchive，生成所有条目的深拷贝，防止外部修改内部状态，用于发布事件和对外返回。
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
   * 复制单条备份条目，生成值副本，防止外部修改内部状态，用于深拷贝存档中的单条条目。
   * @param entry 要复制的备份条目，原对象不会被修改。
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
   * 复制还原结果，生成数组副本，防止外部修改内部状态，用于对外返回和事件发布。
   * @param result 要复制的还原结果对象，原对象不会被修改。
   */
  private copyRestoreResult(result: BackupRestoreResult): BackupRestoreResult {
    return {
      backupId: result.backupId,
      restoredPaths: result.restoredPaths.slice(),
      skippedPaths: result.skippedPaths.slice(),
    };
  }
}
