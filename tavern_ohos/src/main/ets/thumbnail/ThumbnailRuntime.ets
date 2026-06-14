import { EventBus } from '../runtime/EventBus';
import type { ThumbnailType } from '../contracts/PublicContracts';
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

/**
 * 提供缩略图相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ThumbnailRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 内存中的缩略图记录映射表。
   */
  private records: Map<string, ThumbnailRecord> = new Map<string, ThumbnailRecord>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/assets/thumbnails';

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
   * 生成缩略图，持久化后返回生成的记录。
   * @param params 缩略图创建所需参数。
   * @returns 生成的缩略图记录副本。
   */
  async generateThumbnail(params: ThumbnailCreateParams): Promise<ThumbnailRecord> {
    const type = params.type;
    // file 名称。
    const fileName = safeFileName(params.fileName);
    // 键名。
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

  /**
   * 按类型和文件名查找缩略图记录。
   * @param type 缩略图类型。
   * @param fileName 原始文件名。
   * @returns 缩略图记录，不存在则返回 undefined。
   */
  async getThumbnail(type: ThumbnailType, fileName: string): Promise<ThumbnailRecord | undefined> {
    const record = this.records.get(this.key(type, safeFileName(fileName)));
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  /**
   * 读取指定缩略图的文件内容。
   * @param type 缩略图类型。
   * @param fileName 原始文件名。
   * @returns 缩略图文件内容字符串。
   */
  async readThumbnailContent(type: ThumbnailType, fileName: string): Promise<string> {
    const record = this.requireRecord(type, safeFileName(fileName));
    return this.files.readText(record.path);
  }

  /**
   * 按类型列出该类型下所有缩略图记录，返回副本。
   * @param type 缩略图类型。
   * @returns 该类型的缩略图记录列表副本。
   */
  async listByType(type: ThumbnailType): Promise<Array<ThumbnailRecord>> {
    const result = new Array<ThumbnailRecord>();
    this.records.forEach((record: ThumbnailRecord) => {
      if (record.type === type) {
        result.push(this.copyRecord(record));
      }
    });
    result.sort((left: ThumbnailRecord, right: ThumbnailRecord) => left.fileName.localeCompare(right.fileName));
    return result;
  }

  /**
   * 列出所有缩略图记录，返回副本。
   * @returns 所有缩略图记录列表副本。
   */
  async listThumbnails(): Promise<Array<ThumbnailRecord>> {
    const result = new Array<ThumbnailRecord>();
    this.records.forEach((record: ThumbnailRecord) => {
      result.push(this.copyRecord(record));
    });
    result.sort((left: ThumbnailRecord, right: ThumbnailRecord) => this.key(left.type, left.fileName).localeCompare(this.key(right.type, right.fileName)));
    return result;
  }

  /**
   * 使指定缩略图失效，删除文件并清理索引。
   * @param type 缩略图类型。
   * @param fileName 原始文件名。
   */
  async invalidateThumbnail(type: ThumbnailType, fileName: string): Promise<void> {
    // safe 名称。
    const safeName = safeFileName(fileName);
    // 键名。
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

  /**
   * 根据缩略图类型获取预设尺寸配置。
   * @param type 缩略图类型。
   * @returns 预设的宽高尺寸。
   */
  getConfiguredDimensions(type: ThumbnailType): ThumbnailDimensions {
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

  /**
   * 读取必须存在的Record 值，缺失时抛出错误。

   * @param fileName 文件名称。
   */
  private requireRecord(type: ThumbnailType, fileName: string): ThumbnailRecord {
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
  private thumbnailPath(type: ThumbnailType, fileName: string): string {
    return `${this.rootPath}/${this.folderForType(type)}/${fileName}`;
  }
  private folderForType(type: ThumbnailType): string {
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
  private key(type: ThumbnailType, fileName: string): string {
    return `${type}:${fileName}`;
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
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
