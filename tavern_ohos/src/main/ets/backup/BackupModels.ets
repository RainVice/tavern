export interface BackupManifestEntry {
  path: string;
  content: string;
  checksum: string;
  size: number;
}

export interface BackupArchive {
  id: string;
  kind: string;
  rootPath: string;
  reason: string;
  createdAt: number;
  entries: Array<BackupManifestEntry>;
}

export interface BackupValidationResult {
  valid: boolean;
  errors: Array<string>;
}

export interface BackupRestoreResult {
  backupId: string;
  restoredPaths: Array<string>;
  skippedPaths: Array<string>;
}

export interface BackupCompletedPayload {
  backupId: string;
  path: string;
  archive: BackupArchive;
}

export interface BackupRestoredPayload {
  result: BackupRestoreResult;
}
