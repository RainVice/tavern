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

/**
 * 提供图片资源相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 管理图片文件在文件系统中的存储、内存索引的维护，以及图片上传/删除全流程（含缩略图生成、附件绑定）。
 * 外部调用方（如图库 UI、角色编辑页、聊天消息处理）通过此类完成图片生命周期管理。
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
   * 缩略图运行时，用于生成和管理图片缩略图。
   */
  private thumbnails: ThumbnailRuntime;
  /**
   * 附件运行时，用于将图片关联到目标对象。
   */
  private attachments: AttachmentRuntime;
  /**
   * 内存中的图片记录缓存，以图片 ID 为键。
   */
  private records: Map<string, ImageRecord> = new Map<string, ImageRecord>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/assets/images';

  /**
   * 注入图片资源运行时依赖并初始化实例状态。
   * 在应用启动时由更高层运行时容器（如 TavernRuntime）调用，组装图片管理所需的全部基础设施。
   * @param files 文件存储适配器，用于读写图片文件和索引文件 index.json。
   * @param events 事件总线，用于在图片上传成功后发布 'image.uploaded' 事件、在删除后发布 'image.deleted' 事件，以便 UI 层和其他模块同步。
   * @param thumbnails 缩略图运行时，用于在上传图片时自动生成缩略图文件，在删除图片时清理对应的缩略图。
   * @param attachments 附件运行时，用于在上传图片时根据 ImageUploadParams 创建附件绑定，将图片关联到指定目标对象（如角色、聊天）。
   */
  constructor(files: TavernFileStore, events: EventBus, thumbnails: ThumbnailRuntime, attachments: AttachmentRuntime) {
    this.files = files;
    this.events = events;
    this.thumbnails = thumbnails;
    this.attachments = attachments;
  }

  /**
   * 上传图片并持久化到文件系统，同时生成缩略图、关联附件并发布上传事件。
   * 这是图片写入流程的入口方法，由 UI 层（如图库上传按钮、角色头像选择、聊天图片发送）调用。
   * 流程：校验格式 -> 生成规范化文件名和路径 -> 写入文件 -> 生成缩略图 -> 更新内存索引 -> 持久化索引 JSON -> 创建附件绑定 -> 发布 'image.uploaded' 事件。
   * @param params 图片上传所需的全部参数，包括 ID、文件信息、Base64 数据、缩略图数据和附件关联设置。
   * @returns 上传完成后新创建的图片记录对象（深拷贝副本），调用方可通过返回的记录获取文件路径、缩略图路径和附件 ID。
   */
  async uploadImage(params: ImageUploadParams): Promise<ImageRecord> {
    this.validateFormat(params.format);
    const now = Date.now();
    const existing = this.records.get(params.id);
    // 规范化文件名：清除不安全字符并附加扩展名
    const fileName = this.normalizedFileName(params.fileName, params.format);
    // 安全化文件夹名：清除非法路径字符
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
   * 根据图片 ID 读取图片文件内容。
   * 由需要获取图片原始二进制文本的场景调用，如将图片内容传递给对话消息构造或图片描述模块。
   * @param imageId 目标图片的唯一标识，用于在内存索引 records Map 中查找图片记录，进而获取存储路径。
   * @returns 图片文件的文本内容。
   */
  async readImageContent(imageId: string): Promise<string> {
    const record = this.requireRecord(imageId);
    return this.files.readText(record.path);
  }

  /**
   * 按文件夹名称列出该目录下的所有图片记录，支持升序/降序排序。
   * 由需要浏览某分类图片的场景调用，如图库 UI 按文件夹展示图片列表、角色选择头像页面对应文件夹的图片。
   * @param folderName 目标文件夹名称，用于过滤内存索引中 folderName 匹配的记录。
   * @param sortOrder 排序方式："asc" 为升序（默认），"desc" 为降序，按文件名拼音/字母顺序排列。
   * @returns 匹配文件夹的图片记录列表；返回值是深拷贝副本，调用方可安全读取。
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
   * 列出所有非空文件夹名称，按字母序排序。
   * 由需要获取图片分类列表的场景调用，如图库 UI 的文件夹选择器或侧边栏分类导航。
   * @returns 文件夹名称数组；返回值是深拷贝副本，调用方可安全读取。
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
   * 删除指定图片记录、文件、缩略图及其附件，并发布删除事件。
   * 由 UI 层（如图库删除按钮或角色头像删除操作）调用。
   * 流程：查找记录 -> 从内存索引移除 -> 删除图片文件 -> 清理缩略图 -> 清理附件绑定 -> 持久化索引 JSON -> 发布 'image.deleted' 事件。
   * @param imageId 要删除的目标图片标识，用于在内存索引中查找图片记录以获取文件路径和关联附件 ID。
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
   * 如果上传参数中指定了附件关联，则创建 Attachment 记录并将图片绑定到目标对象。
   * @param record 要绑定的图片记录。
   * @param params 上传参数，从中读取 attachmentId、targetType 和 targetId。
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
   * 根据 ID 查找图片记录，不存在时抛出异常。
   * @param imageId 目标图片标识。
   * @returns 匹配的图片记录。
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
   * 列出全部图片记录（不限文件夹），按 ID 排序后返回副本。
   * @returns 全部图片记录的深拷贝列表。
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
   * 规范化文件名，清除不安全字符并追加指定的格式扩展名。
   * @param fileName 原始文件名。
   * @param format 图片格式扩展名，如 png、jpg。
   * @returns 安全且含正确扩展名的文件名。
   */
  private normalizedFileName(fileName: string, format: string): string {
    const sanitized = safeFileName(fileName, 'image');
    const dotIndex = sanitized.lastIndexOf('.');
    // 去除原始扩展名，统一替换为指定的 format 扩展名
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
   * 校验图片格式是否在支持范围内（png、jpg、jpeg、webp、gif）。
   */
  private validateFormat(format: string): void {
    if (format === 'png' || format === 'jpg' || format === 'jpeg' || format === 'webp' || format === 'gif') {
      return;
    }
    throw new Error(`Invalid image format: ${format}`);
  }

  /**
   * 深拷贝图片记录，防止外部修改影响内部状态。
   * @param record 原始图片记录。
   * @returns 字段值完全一致的独立副本。
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
