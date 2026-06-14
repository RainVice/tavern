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
   * 缩略图运行时实例，负责缩略图生成与管理。
   */
  private thumbnails: ThumbnailRuntime;
  /**
   * 附件运行时实例，负责附件绑定与清理。
   */
  private attachments: AttachmentRuntime;
  /**
   * 内存中的图片记录映射，键为图片标识。
   */
  private records: Map<string, ImageRecord> = new Map<string, ImageRecord>();
  /**
   * 图片数据在文件存储中的根路径。
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
   * 上传图片，包含文件写入、索引持久化和事件发布。
   * @param params 上传图片所需参数。
   */
  async uploadImage(params: ImageUploadParams): Promise<ImageRecord> {
    this.validateFormat(params.format);
    const now = Date.now();
    const existing = this.records.get(params.id);
    // 生成规范化文件名。
    const fileName = this.normalizedFileName(params.fileName, params.format);
    // 生成文件夹名称片段。
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
   * 读取指定图片的原始内容。
   * @param imageId 目标图片标识。
   */
  async readImageContent(imageId: string): Promise<string> {
    const record = this.requireRecord(imageId);
    return this.files.readText(record.path);
  }

  /**
   * 列出指定文件夹下的图片记录。
   * @param folderName 文件夹名称。
   * @param sortOrder 排序方式，"asc" 为升序，"desc" 为降序。
   * @returns 所有图片记录列表副本（含未绑定附件）。
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
   * 列出所有包含图片的文件夹名称。
   * @returns 文件夹名称列表副本，调用方可安全读取。
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
   * 把图片记录绑定到附件系统。
   * @param record 已上传的图片记录。
   * @param params 上传时使用的参数。
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
   * 获取指定图片的记录，若不存在则抛出异常。
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
   * 列出内存中所有图片记录，排序后返回副本。
   * @returns 图片记录列表副本，调用方可安全读取。
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
   * 获取规范化后的文件名，保证后续比较和存储使用一致格式。
   * @param fileName 原始文件名。
   * @param format 目标格式扩展名。
   */
  private normalizedFileName(fileName: string, format: MediaFormat): string {
    const sanitized = safeFileName(fileName, 'image');
    const dotIndex = sanitized.lastIndexOf('.');
    // 提取去除扩展名后的基础名称。
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
   * 校验图片格式是否满足运行时支持的格式集合。
   */
  private validateFormat(format: MediaFormat): void {
    if (format === 'png' || format === 'jpg' || format === 'jpeg' || format === 'webp' || format === 'gif') {
      return;
    }
    throw new Error(`Invalid image format: ${format}`);
  }

  /**
   * 复制图片记录，避免外部修改内部状态。
   * @param record 待复制的图片记录。
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
