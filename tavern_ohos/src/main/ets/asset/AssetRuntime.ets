import { EventBus } from '../runtime/EventBus';
import { safeFileName, safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  AssetCreateParams,
  AssetDeletedPayload,
  AssetImportedPayload,
  AssetIndexData,
  AssetRecord,
  AssetRenamedPayload,
} from './AssetModels';

export class AssetRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private records: Map<string, AssetRecord> = new Map<string, AssetRecord>();
  private rootPath: string = 'tavern-data/users/default/assets';

  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  async importAsset(params: AssetCreateParams): Promise<AssetRecord> {
    const now = Date.now();
    const existing = this.records.get(params.id);
    const fileName = safeFileName(params.fileName);
    const record: AssetRecord = {
      schemaVersion: 1,
      id: params.id,
      type: params.type,
      fileName: fileName,
      mimeType: params.mimeType,
      path: this.assetPath(params.type, fileName),
      content: params.content,
      metadataJson: params.metadataJson,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(record.id, this.copyRecord(record));
    await this.writeRecord(record);
    await this.persistIndex();
    const payload: AssetImportedPayload = {
      asset: this.copyRecord(record),
    };
    this.events.publish<AssetImportedPayload>('asset.imported', payload);
    return this.copyRecord(record);
  }

  async readAssetContent(assetId: string): Promise<string> {
    const record = this.requireRecord(assetId);
    return this.files.readText(record.path);
  }

  async listAssets(): Promise<Array<AssetRecord>> {
    const result = new Array<AssetRecord>();
    this.records.forEach((record: AssetRecord) => {
      result.push(this.copyRecord(record));
    });
    return this.sortRecords(result);
  }

  async listByType(type: string): Promise<Array<AssetRecord>> {
    const result = new Array<AssetRecord>();
    this.records.forEach((record: AssetRecord) => {
      if (record.type === type) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

  async renameAsset(assetId: string, newFileName: string): Promise<AssetRecord> {
    const record = this.requireRecord(assetId);
    const oldPath = record.path;
    const content = await this.files.readText(oldPath);
    const fileName = safeFileName(newFileName);
    const updated = this.copyRecord(record);
    updated.fileName = fileName;
    updated.path = this.assetPath(record.type, fileName);
    updated.updatedAt = Date.now();
    updated.content = content;
    await this.files.writeText(updated.path, content, false);
    await this.files.delete(oldPath);
    this.records.set(updated.id, this.copyRecord(updated));
    await this.persistIndex();
    const payload: AssetRenamedPayload = {
      assetId: assetId,
      oldPath: oldPath,
      asset: this.copyRecord(updated),
    };
    this.events.publish<AssetRenamedPayload>('asset.renamed', payload);
    return this.copyRecord(updated);
  }

  async deleteAsset(assetId: string): Promise<void> {
    const record = this.requireRecord(assetId);
    this.records.delete(assetId);
    await this.files.delete(record.path);
    await this.persistIndex();
    const payload: AssetDeletedPayload = {
      assetId: assetId,
      type: record.type,
      path: record.path,
    };
    this.events.publish<AssetDeletedPayload>('asset.deleted', payload);
  }

  private requireRecord(assetId: string): AssetRecord {
    const record = this.records.get(assetId);
    if (record === undefined) {
      throw new Error(`Asset not found: ${assetId}`);
    }
    return record;
  }

  private async writeRecord(record: AssetRecord): Promise<void> {
    await this.files.writeText(record.path, record.content, false);
  }

  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data: AssetIndexData = {
      assets: await this.listAssets(),
    };
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  private assetPath(type: string, fileName: string): string {
    return `${this.rootPath}/${this.folderForType(type)}/${fileName}`;
  }

  private folderForType(type: string): string {
    if (type === 'image') {
      return 'images';
    }
    if (type === 'background') {
      return 'backgrounds';
    }
    if (type === 'theme') {
      return 'themes';
    }
    if (type === 'thumbnail') {
      return 'thumbnails';
    }
    if (type === 'audio') {
      return 'audio';
    }
    return safePathSegment(type, 'misc');
  }

  private sortRecords(records: Array<AssetRecord>): Array<AssetRecord> {
    records.sort((left: AssetRecord, right: AssetRecord) => left.id.localeCompare(right.id));
    return records;
  }

  private copyRecord(record: AssetRecord): AssetRecord {
    return {
      schemaVersion: record.schemaVersion,
      id: record.id,
      type: record.type,
      fileName: record.fileName,
      mimeType: record.mimeType,
      path: record.path,
      content: record.content,
      metadataJson: record.metadataJson,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }
}
