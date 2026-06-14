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

/**
 * 提供缩略图相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在图片资源管理流程中，负责生成和管理源图片的缩略图缓存，加速 UI 列表加载性能。
 */
export class ThumbnailRuntime {
  /**
   * 文件存储适配器实例，用于缩略图文件的读写操作。
   */
  private files: TavernFileStore;
  /**
   * 事件总线实例，用于发布缩略图生成和失效事件。
   */
  private events: EventBus;
  /**
   * 按 "type:fileName" 键保存的缩略图记录映射表，用于快速查询和去重。
   */
  private records: Map<string, ThumbnailRecord> = new Map<string, ThumbnailRecord>();
  /**
   * 缩略图数据文件的存储根路径。
   */
  private rootPath: string = 'tavern-data/users/default/assets/thumbnails';

  /**
   * 初始化 ThumbnailRuntime 实例。
   * @param files 文件存储适配器。
   * @param events 事件总线实例。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 生成缩略图：计算尺寸信息，写入文件，持久化索引并发布事件。
   * 在 UI 需要展示图片资源的缩略预览时由图片加载流程调用。
   * @param params 缩略图创建参数。
   * @returns 生成的缩略图记录。
   */
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

  /**
   * 获取指定类型和文件名的缩略图记录。
   * 在 UI 组件初始化时调用，判断是否需要生成新的缩略图。
   * @param type 缩略图类型。
   * @param fileName 源文件名称。
   * @returns 缩略图记录副本，不存在时返回 undefined。
   */
  async getThumbnail(type: string, fileName: string): Promise<ThumbnailRecord | undefined> {
    const record = this.records.get(this.key(type, safeFileName(fileName)));
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  /**
   * 读取指定缩略图的文件内容。
   * 在 UI 展示缩略图时调用，从文件读取 base64 数据或文本内容用于 Image 组件。
   * @param type 缩略图类型。
   * @param fileName 源文件名称。
   * @returns 缩略图文件的文本内容。
   */
  async readThumbnailContent(type: string, fileName: string): Promise<string> {
    const record = this.requireRecord(type, safeFileName(fileName));
    return this.files.readText(record.path);
  }

  /**
   * 按类型列出所有缩略图记录。
   * 在 UI 按分类展示缩略图列表（如角色头像缩略图列表、背景缩略图列表）时调用。
   * @param type 缩略图类型。
   * @returns 匹配类型的缩略图记录副本数组。
   */
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

  /**
   * 列出所有缩略图记录，按 "type:fileName" 排序。
   * 用于索引持久化或全量数据导出。
   * @returns 所有缩略图记录副本数组。
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
   * 使指定缩略图失效：从内存和文件系统中删除，更新索引。
   * 在源图片发生变更或用户手动清除缓存时由宿主调用。
   * @param type 缩略图类型。
   * @param fileName 源文件名称。
   */
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

  /**
   * 获取指定类型的默认缩略图尺寸配置。
   * 在生成缩略图时由调用方决定缩放尺寸。
   * @param type 缩略图类型（bg / avatar / persona / 其他）。
   * @returns 配置的宽度和高度。
   */
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

  /**
   * 确保指定缩略图记录存在，缺失时抛出错误。
   * @param type 缩略图类型。
   * @param fileName 源文件名称。
   */
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

  /**
   * 深度复制 ThumbnailRecord，防止外部代码修改内部状态。
   * @param record 要复制的缩略图记录。
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
