import { AssetRuntime } from '../asset/AssetRuntime';
import type { AssetCreateParams, AssetRecord } from '../asset/AssetModels';
import { EventBus } from '../runtime/EventBus';
import type { TavernFileStore } from '../storage/TavernFileStore';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ThumbnailRuntime } from '../thumbnail/ThumbnailRuntime';
import type { ThumbnailDimensions, ThumbnailRecord } from '../thumbnail/ThumbnailModels';
import type {
  BackgroundDeletedPayload,
  BackgroundFolderRecord,
  BackgroundImportedPayload,
  BackgroundImportParams,
  BackgroundIndexData,
  BackgroundListItem,
  BackgroundListResult,
  BackgroundRecord,
  BackgroundRenamedPayload,
} from './BackgroundModels';

export class BackgroundRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private assets: AssetRuntime;
  private thumbnails: ThumbnailRuntime;
  private themes: ThemeRuntime;
  private records: Map<string, BackgroundRecord> = new Map<string, BackgroundRecord>();
  private rootPath: string = 'tavern-data/users/default/assets/backgrounds';

  constructor(files: TavernFileStore, events: EventBus, assets: AssetRuntime, thumbnails: ThumbnailRuntime, themes: ThemeRuntime) {
    this.files = files;
    this.events = events;
    this.assets = assets;
    this.thumbnails = thumbnails;
    this.themes = themes;
  }

  async importBackground(params: BackgroundImportParams): Promise<BackgroundRecord> {
    const now = Date.now();
    const asset = await this.assets.importAsset(this.toAssetParams(params));
    const thumbnail = await this.thumbnails.generateThumbnail({
      type: 'bg',
      fileName: asset.fileName,
      sourcePath: asset.path,
      content: params.thumbnailContent,
      width: 160,
      height: 90,
      animated: params.isAnimated,
    });
    const existing = this.records.get(params.id);
    const record: BackgroundRecord = {
      schemaVersion: 1,
      id: params.id,
      fileName: asset.fileName,
      path: asset.path,
      content: params.content,
      mimeType: params.mimeType,
      metadataJson: params.metadataJson,
      isAnimated: params.isAnimated,
      folderIds: this.copyStrings(params.folderIds),
      thumbnailPath: thumbnail.path,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(record.id, this.copyRecord(record));
    await this.persistIndex();
    const payload: BackgroundImportedPayload = {
      background: this.copyRecord(record),
    };
    this.events.publish<BackgroundImportedPayload>('background.imported', payload);
    return this.copyRecord(record);
  }

  async listBackgrounds(): Promise<BackgroundListResult> {
    const images = new Array<BackgroundListItem>();
    const records = await this.listRecords();
    for (let index = 0; index < records.length; index += 1) {
      const item: BackgroundListItem = {
        filename: records[index].fileName,
        isAnimated: records[index].isAnimated,
      };
      images.push(item);
    }
    const config: ThumbnailDimensions = this.thumbnails.getConfiguredDimensions('bg');
    return {
      images: images,
      config: config,
    };
  }

  async listFolders(): Promise<Array<BackgroundFolderRecord>> {
    const folderIds = new Set<string>();
    this.records.forEach((record: BackgroundRecord) => {
      for (let index = 0; index < record.folderIds.length; index += 1) {
        folderIds.add(record.folderIds[index]);
      }
    });
    const ids = Array.from(folderIds).sort();
    const result = new Array<BackgroundFolderRecord>();
    for (let index = 0; index < ids.length; index += 1) {
      const folder: BackgroundFolderRecord = {
        id: ids[index],
        name: ids[index],
      };
      result.push(folder);
    }
    return result;
  }

  async activateBackground(fileName: string): Promise<void> {
    this.requireRecordByFileName(fileName);
    await this.themes.setActiveBackground(fileName);
  }

  async renameBackground(backgroundId: string, newFileName: string): Promise<BackgroundRecord> {
    const record = this.requireRecord(backgroundId);
    const oldFileName = record.fileName;
    await this.thumbnails.invalidateThumbnail('bg', oldFileName);
    const asset: AssetRecord = await this.assets.renameAsset(backgroundId, newFileName);
    const thumbnail: ThumbnailRecord = await this.thumbnails.generateThumbnail({
      type: 'bg',
      fileName: asset.fileName,
      sourcePath: asset.path,
      content: record.content,
      width: 160,
      height: 90,
      animated: record.isAnimated,
    });
    const updated = this.copyRecord(record);
    updated.fileName = asset.fileName;
    updated.path = asset.path;
    updated.thumbnailPath = thumbnail.path;
    updated.updatedAt = Date.now();
    this.records.set(backgroundId, this.copyRecord(updated));
    await this.persistIndex();
    const payload: BackgroundRenamedPayload = {
      oldFileName: oldFileName,
      background: this.copyRecord(updated),
    };
    this.events.publish<BackgroundRenamedPayload>('background.renamed', payload);
    return this.copyRecord(updated);
  }

  async deleteBackground(backgroundId: string): Promise<void> {
    const record = this.requireRecord(backgroundId);
    this.records.delete(backgroundId);
    await this.assets.deleteAsset(backgroundId);
    await this.thumbnails.invalidateThumbnail('bg', record.fileName);
    if (this.themes.getActiveBackground() === record.fileName) {
      await this.themes.setActiveBackground('');
    }
    await this.persistIndex();
    const payload: BackgroundDeletedPayload = {
      backgroundId: backgroundId,
      fileName: record.fileName,
    };
    this.events.publish<BackgroundDeletedPayload>('background.deleted', payload);
  }

  private requireRecord(backgroundId: string): BackgroundRecord {
    const record = this.records.get(backgroundId);
    if (record === undefined) {
      throw new Error(`Background not found: ${backgroundId}`);
    }
    return record;
  }

  private requireRecordByFileName(fileName: string): BackgroundRecord {
    let found: BackgroundRecord | undefined = undefined;
    this.records.forEach((record: BackgroundRecord) => {
      if (record.fileName === fileName) {
        found = record;
      }
    });
    if (found === undefined) {
      throw new Error(`Background not found: ${fileName}`);
    }
    return found;
  }

  private async listRecords(): Promise<Array<BackgroundRecord>> {
    const result = new Array<BackgroundRecord>();
    this.records.forEach((record: BackgroundRecord) => {
      result.push(this.copyRecord(record));
    });
    result.sort((left: BackgroundRecord, right: BackgroundRecord) => left.fileName.localeCompare(right.fileName));
    return result;
  }

  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data: BackgroundIndexData = {
      backgrounds: await this.listRecords(),
    };
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  private toAssetParams(params: BackgroundImportParams): AssetCreateParams {
    return {
      id: params.id,
      type: 'background',
      fileName: params.fileName,
      mimeType: params.mimeType,
      content: params.content,
      metadataJson: params.metadataJson,
    };
  }

  private copyRecord(record: BackgroundRecord): BackgroundRecord {
    return {
      schemaVersion: record.schemaVersion,
      id: record.id,
      fileName: record.fileName,
      path: record.path,
      content: record.content,
      mimeType: record.mimeType,
      metadataJson: record.metadataJson,
      isAnimated: record.isAnimated,
      folderIds: this.copyStrings(record.folderIds),
      thumbnailPath: record.thumbnailPath,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  private copyStrings(values: Array<string>): Array<string> {
    const result = new Array<string>();
    for (let index = 0; index < values.length; index += 1) {
      result.push(values[index]);
    }
    return result;
  }
}
