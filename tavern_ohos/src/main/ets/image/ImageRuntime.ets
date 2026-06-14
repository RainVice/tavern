import { AttachmentRuntime } from '../attachment/AttachmentRuntime';
import type { AttachmentCreateParams } from '../attachment/AttachmentModels';
import { EventBus } from '../runtime/EventBus';
import { safeFileName, safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import { ThumbnailRuntime } from '../thumbnail/ThumbnailRuntime';
import type { ThumbnailRecord } from '../thumbnail/ThumbnailModels';
import type { MediaFormat } from '../contracts/PublicContracts';
import type {
  ImageDeletedPayload,
  ImageIndexData,
  ImageRecord,
  ImageUploadedPayload,
  ImageUploadParams,
} from './ImageModels';

/**
 * 提供图片资源相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ImageRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * thumbnails 列表，由当前实例内部维护。
   */
  private thumbnails: ThumbnailRuntime;
  /**
   * attachments 列表，由当前实例内部维护。
   */
  private attachments: AttachmentRuntime;
  /**
   * 记录副本列表，由当前实例内部维护。
   */
  private records: Map<string, ImageRecord> = new Map<string, ImageRecord>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/assets/images';

  /**
   * 注入图片资源运行时依赖并初始化实例状态。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   */
  constructor(files: TavernFileStore, events: EventBus, thumbnails: ThumbnailRuntime, attachments: AttachmentRuntime) {
    this.files = files;
    this.events = events;
    this.thumbnails = thumbnails;
    this.attachments = attachments;
  }

  /**
   * 执行 uploadImage 的内部处理步骤，供当前模块复用。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  async uploadImage(params: ImageUploadParams): Promise<ImageRecord> {
    this.validateFormat(params.format);
    const now = Date.now();
    const existing = this.records.get(params.id);
    // file 名称。
    const fileName = this.normalizedFileName(params.fileName, params.format);
    // folder 名称。
    const folderName = this.safeOptionalSegment(params.folderName);
    const path = this.imagePath(folderName, fileName);
    let thumbnailPath = '';
    if (params.thumbnailType.length > 0) {
      const thumbnail: ThumbnailRecord = await this.thumbnails.generateThumbnail({
        type: params.thumbnailType,
        fileName: fileName,
        sourcePath: path,
        content: params.thumbnailContent,
        width: params.thumbnailWidth,
        height: params.thumbnailHeight,
        animated: false,
      });
      thumbnailPath = thumbnail.path;
    }
    const record: ImageRecord = {
      schemaVersion: 1,
      id: params.id,
      fileName: fileName,
      format: params.format,
      folderName: folderName,
      mimeType: params.mimeType,
      path: path,
      content: params.content,
      thumbnailType: params.thumbnailType,
      thumbnailPath: thumbnailPath,
      attachmentId: params.attachmentId,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(record.id, this.copyRecord(record));
    await this.files.writeText(record.path, record.content, false);
    await this.persistIndex();
    this.bindAttachmentIfNeeded(record, params);
    const payload: ImageUploadedPayload = {
      image: this.copyRecord(record),
    };
    this.events.publish<ImageUploadedPayload>('image.uploaded', payload);
    return this.copyRecord(record);
  }

  /**
   * 读取Image Content 值，并转换为运行时使用的数据结构。
   * @param imageId 目标图片标识。
   */
  async readImageContent(imageId: string): Promise<string> {
    const record = this.requireRecord(imageId);
    return this.files.readText(record.path);
  }

  /**
   * 读取Images列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param folderName folder名称。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async listImages(folderName: string, sortOrder: string): Promise<Array<ImageRecord>> {
    const normalizedFolder = this.safeOptionalSegment(folderName);
    const result = new Array<ImageRecord>();
    this.records.forEach((record: ImageRecord) => {
      if (record.folderName === normalizedFolder) {
        result.push(this.copyRecord(record));
      }
    });
    result.sort((left: ImageRecord, right: ImageRecord) => left.fileName.localeCompare(right.fileName));
    if (sortOrder === 'desc') {
      result.reverse();
    }
    return result;
  }

  /**
   * 读取Folders列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async listFolders(): Promise<Array<string>> {
    const folders = new Set<string>();
    this.records.forEach((record: ImageRecord) => {
      if (record.folderName.length > 0) {
        folders.add(record.folderName);
      }
    });
    return Array.from(folders).sort();
  }

  /**
   * 删除指定图片，并清理相关索引或资源引用。
   * @param imageId 目标图片标识。
   */
  async deleteImage(imageId: string): Promise<void> {
    const record = this.requireRecord(imageId);
    this.records.delete(imageId);
    await this.files.delete(record.path);
    if (record.thumbnailType.length > 0) {
      await this.thumbnails.invalidateThumbnail(record.thumbnailType, record.fileName);
    }
    if (record.attachmentId.length > 0) {
      this.attachments.deleteAttachment(record.attachmentId);
    }
    await this.persistIndex();
    const payload: ImageDeletedPayload = {
      imageId: imageId,
      path: record.path,
    };
    this.events.publish<ImageDeletedPayload>('image.deleted', payload);
  }

  /**
   * 把图片资源对象绑定到指定作用域，后续读取会按该绑定解析。
   * @param record 记录副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  private bindAttachmentIfNeeded(record: ImageRecord, params: ImageUploadParams): void {
    if (params.attachmentId.length === 0 || params.attachmentTargetId.length === 0) {
      return;
    }
    const attachmentParams: AttachmentCreateParams = {
      id: params.attachmentId,
      kind: 'image',
      fileName: record.fileName,
      mimeType: record.mimeType,
      storagePath: record.path,
      content: record.content,
      includeInPrompt: params.includeInPrompt,
      includeInRag: params.includeInRag,
      captionText: '',
      translationText: '',
      metadataJson: JSON.stringify({ imageId: record.id }),
    };
    this.attachments.createAttachment(attachmentParams);
    this.attachments.bindAttachment(params.attachmentId, params.attachmentTargetType, params.attachmentTargetId);
  }

  /**
   * 读取必须存在的Record 值，缺失时抛出错误。
   * @param imageId 目标图片标识。
   */
  private requireRecord(imageId: string): ImageRecord {
    const record = this.records.get(imageId);
    if (record === undefined) {
      throw new Error(`Image not found: ${imageId}`);
    }
    return record;
  }
  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data: ImageIndexData = {
      images: await this.listAllImages(),
    };
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  /**
   * 读取AllImages列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private async listAllImages(): Promise<Array<ImageRecord>> {
    const result = new Array<ImageRecord>();
    this.records.forEach((record: ImageRecord) => {
      result.push(this.copyRecord(record));
    });
    result.sort((left: ImageRecord, right: ImageRecord) => left.id.localeCompare(right.id));
    return result;
  }
  private imagePath(folderName: string, fileName: string): string {
    if (folderName.length === 0) {
      return `${this.rootPath}/${fileName}`;
    }
    return `${this.rootPath}/${folderName}/${fileName}`;
  }

  /**
   * 规范化d File 名称，保证后续比较和存储使用一致格式。
   * @param fileName 文件名称。
   */
  private normalizedFileName(fileName: string, format: MediaFormat): string {
    const sanitized = safeFileName(fileName, 'image');
    const dotIndex = sanitized.lastIndexOf('.');
    // base 名称。
    const baseName = dotIndex < 0 ? sanitized : sanitized.substring(0, dotIndex);
    return `${baseName}.${format}`;
  }
  private safeOptionalSegment(value: string): string {
    if (value.length === 0) {
      return '';
    }
    return safePathSegment(value, '');
  }

  /**
   * 校验Format 值是否满足运行时约束。

   */
  private validateFormat(format: MediaFormat): void {
    if (format === 'png' || format === 'jpg' || format === 'jpeg' || format === 'webp' || format === 'gif') {
      return;
    }
    throw new Error(`Invalid image format: ${format}`);
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private copyRecord(record: ImageRecord): ImageRecord {
    return {
      schemaVersion: record.schemaVersion,
      id: record.id,
      fileName: record.fileName,
      format: record.format,
      folderName: record.folderName,
      mimeType: record.mimeType,
      path: record.path,
      content: record.content,
      thumbnailType: record.thumbnailType,
      thumbnailPath: record.thumbnailPath,
      attachmentId: record.attachmentId,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }
}
