import { EventBus } from '../runtime/EventBus';
import { safeFileName, safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  ThumbnailCreateParams,
  ThumbnailDimensions,
  ThumbnailGeneratedPayload,
  ThumbnailIndexData,
  ThumbnailInvalidatedPayload,
  ThumbnailRecord,
} from './ThumbnailModels';

export class ThumbnailRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private records: Map<string, ThumbnailRecord> = new Map<string, ThumbnailRecord>();
  private rootPath: string = 'tavern-data/users/default/assets/thumbnails';

  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  async generateThumbnail(params: ThumbnailCreateParams): Promise<ThumbnailRecord> {
    const type = params.type;
    const fileName = safeFileName(params.fileName);
    const key = this.key(type, fileName);
    const now = Date.now();
    const existing = this.records.get(key);
    const record: ThumbnailRecord = {
      schemaVersion: 1,
      type: type,
      fileName: fileName,
      sourcePath: params.sourcePath,
      path: this.thumbnailPath(type, fileName),
      content: params.content,
      width: params.width,
      height: params.height,
      aspectRatio: params.height === 0 ? 0 : params.width / params.height,
      resolution: params.width * params.height,
      animated: params.animated,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(key, this.copyRecord(record));
    await this.files.writeText(record.path, record.content, false);
    await this.persistIndex();
    const payload: ThumbnailGeneratedPayload = {
      thumbnail: this.copyRecord(record),
    };
    this.events.publish<ThumbnailGeneratedPayload>('thumbnail.generated', payload);
    return this.copyRecord(record);
  }

  async getThumbnail(type: string, fileName: string): Promise<ThumbnailRecord | undefined> {
    const record = this.records.get(this.key(type, safeFileName(fileName)));
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  async readThumbnailContent(type: string, fileName: string): Promise<string> {
    const record = this.requireRecord(type, safeFileName(fileName));
    return this.files.readText(record.path);
  }

  async listByType(type: string): Promise<Array<ThumbnailRecord>> {
    const result = new Array<ThumbnailRecord>();
    this.records.forEach((record: ThumbnailRecord) => {
      if (record.type === type) {
        result.push(this.copyRecord(record));
      }
    });
    result.sort((left: ThumbnailRecord, right: ThumbnailRecord) => left.fileName.localeCompare(right.fileName));
    return result;
  }

  async listThumbnails(): Promise<Array<ThumbnailRecord>> {
    const result = new Array<ThumbnailRecord>();
    this.records.forEach((record: ThumbnailRecord) => {
      result.push(this.copyRecord(record));
    });
    result.sort((left: ThumbnailRecord, right: ThumbnailRecord) => this.key(left.type, left.fileName).localeCompare(this.key(right.type, right.fileName)));
    return result;
  }

  async invalidateThumbnail(type: string, fileName: string): Promise<void> {
    const safeName = safeFileName(fileName);
    const key = this.key(type, safeName);
    const record = this.requireRecord(type, safeName);
    this.records.delete(key);
    await this.files.delete(record.path);
    await this.persistIndex();
    const payload: ThumbnailInvalidatedPayload = {
      type: type,
      fileName: safeName,
      path: record.path,
    };
    this.events.publish<ThumbnailInvalidatedPayload>('thumbnail.invalidated', payload);
  }

  getConfiguredDimensions(type: string): ThumbnailDimensions {
    if (type === 'bg') {
      return { width: 160, height: 90 };
    }
    if (type === 'avatar') {
      return { width: 96, height: 144 };
    }
    if (type === 'persona') {
      return { width: 96, height: 144 };
    }
    return { width: 96, height: 96 };
  }

  private requireRecord(type: string, fileName: string): ThumbnailRecord {
    const record = this.records.get(this.key(type, fileName));
    if (record === undefined) {
      throw new Error(`Thumbnail not found: ${type}:${fileName}`);
    }
    return record;
  }

  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data: ThumbnailIndexData = {
      thumbnails: await this.listThumbnails(),
    };
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  private thumbnailPath(type: string, fileName: string): string {
    return `${this.rootPath}/${this.folderForType(type)}/${fileName}`;
  }

  private folderForType(type: string): string {
    if (type === 'bg') {
      return 'bg';
    }
    if (type === 'avatar') {
      return 'avatar';
    }
    if (type === 'persona') {
      return 'persona';
    }
    return safePathSegment(type, 'misc');
  }

  private key(type: string, fileName: string): string {
    return `${type}:${fileName}`;
  }

  private copyRecord(record: ThumbnailRecord): ThumbnailRecord {
    return {
      schemaVersion: record.schemaVersion,
      type: record.type,
      fileName: record.fileName,
      sourcePath: record.sourcePath,
      path: record.path,
      content: record.content,
      width: record.width,
      height: record.height,
      aspectRatio: record.aspectRatio,
      resolution: record.resolution,
      animated: record.animated,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }
}
