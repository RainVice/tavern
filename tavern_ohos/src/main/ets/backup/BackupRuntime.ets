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

export class BackupRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private backupCounter: number = 0;

  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  async createBackup(rootPath: string, destinationPath: string, kind: string): Promise<BackupArchive> {
    return this.createBackupInternal(rootPath, destinationPath, kind, 'manual');
  }

  async createMigrationBackup(rootPath: string, reason: string): Promise<BackupArchive> {
    return this.createBackupInternal(rootPath, `backups/migration-${this.backupCounter + 1}.json`, 'migration', reason);
  }

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

  private copyEntry(entry: BackupManifestEntry): BackupManifestEntry {
    return {
      path: entry.path,
      content: entry.content,
      checksum: entry.checksum,
      size: entry.size,
    };
  }

  private copyRestoreResult(result: BackupRestoreResult): BackupRestoreResult {
    return {
      backupId: result.backupId,
      restoredPaths: result.restoredPaths.slice(),
      skippedPaths: result.skippedPaths.slice(),
    };
  }
}
