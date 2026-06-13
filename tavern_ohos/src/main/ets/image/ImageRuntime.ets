import { AttachmentRuntime } from '../attachment/AttachmentRuntime';
import type { AttachmentCreateParams } from '../attachment/AttachmentModels';
import { EventBus } from '../runtime/EventBus';
import { safeFileName, safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import { ThumbnailRuntime } from '../thumbnail/ThumbnailRuntime';
import type { ThumbnailRecord } from '../thumbnail/ThumbnailModels';
import type {
  ImageDeletedPayload,
  ImageIndexData,
  ImageRecord,
  ImageUploadedPayload,
  ImageUploadParams,
} from './ImageModels';

export class ImageRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private thumbnails: ThumbnailRuntime;
  private attachments: AttachmentRuntime;
  private records: Map<string, ImageRecord> = new Map<string, ImageRecord>();
  private rootPath: string = 'tavern-data/users/default/assets/images';

  constructor(files: TavernFileStore, events: EventBus, thumbnails: ThumbnailRuntime, attachments: AttachmentRuntime) {
    this.files = files;
    this.events = events;
    this.thumbnails = thumbnails;
    this.attachments = attachments;
  }

  async uploadImage(params: ImageUploadParams): Promise<ImageRecord> {
    this.validateFormat(params.format);
    const now = Date.now();
    const existing = this.records.get(params.id);
    const fileName = this.normalizedFileName(params.fileName, params.format);
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

  async readImageContent(imageId: string): Promise<string> {
    const record = this.requireRecord(imageId);
    return this.files.readText(record.path);
  }

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

  async listFolders(): Promise<Array<string>> {
    const folders = new Set<string>();
    this.records.forEach((record: ImageRecord) => {
      if (record.folderName.length > 0) {
        folders.add(record.folderName);
      }
    });
    return Array.from(folders).sort();
  }

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

  private normalizedFileName(fileName: string, format: string): string {
    const sanitized = safeFileName(fileName, 'image');
    const dotIndex = sanitized.lastIndexOf('.');
    const baseName = dotIndex < 0 ? sanitized : sanitized.substring(0, dotIndex);
    return `${baseName}.${format}`;
  }

  private safeOptionalSegment(value: string): string {
    if (value.length === 0) {
      return '';
    }
    return safePathSegment(value, '');
  }

  private validateFormat(format: string): void {
    if (format === 'png' || format === 'jpg' || format === 'jpeg' || format === 'webp' || format === 'gif') {
      return;
    }
    throw new Error(`Invalid image format: ${format}`);
  }

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
