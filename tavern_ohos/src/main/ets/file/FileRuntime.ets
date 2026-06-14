import { AttachmentRuntime } from '../attachment/AttachmentRuntime';
import type { AttachmentCreateParams } from '../attachment/AttachmentModels';
import { DataBankRuntime } from '../databank/DataBankRuntime';
import type { DataBankDocumentCreateParams } from '../databank/DataBankModels';
import { EventBus } from '../runtime/EventBus';
import { isPathInsideRoot, safeFileName } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  FileDeletedPayload,
  FileIndexData,
  FileRecord,
  FileUploadedPayload,
  FileUploadParams,
  FileVerifyResult,
} from './FileModels';

/**
 * 提供上传文件相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class FileRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * attachments 列表，由当前实例内部维护。
   */
  private attachments: AttachmentRuntime;
  /**
   * data Bank 值，由当前实例内部维护。
   */
  private dataBank: DataBankRuntime;
  /**
   * 记录副本列表，由当前实例内部维护。
   */
  private records: Map<string, FileRecord> = new Map<string, FileRecord>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/assets/files';

  /**
   * 注入上传文件运行时依赖并初始化实例状态。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   */
  constructor(files: TavernFileStore, events: EventBus, attachments: AttachmentRuntime, dataBank: DataBankRuntime) {
    this.files = files;
    this.events = events;
    this.attachments = attachments;
    this.dataBank = dataBank;
  }

  /**
   * 清理File 名称中的不安全字符，避免路径或名称逃逸。
   * @param fileName 文件名称。
   */
  sanitizeFileName(fileName: string): string {
    return safeFileName(fileName);
  }

  /**
   * 执行 uploadFile 的内部处理步骤，供当前模块复用。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  async uploadFile(params: FileUploadParams): Promise<FileRecord> {
    const now = Date.now();
    const existing = this.records.get(params.id);
    // file 名称。
    const fileName = this.sanitizeFileName(params.fileName);
    const record: FileRecord = {
      schemaVersion: 1,
      id: params.id,
      fileName: fileName,
      mimeType: params.mimeType,
      path: `${this.rootPath}/${fileName}`,
      content: params.content,
      attachmentId: params.attachmentId,
      dataBankDocumentId: params.dataBankDocumentId,
      metadataJson: params.metadataJson,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(record.id, this.copyRecord(record));
    await this.files.writeText(record.path, record.content, false);
    await this.persistIndex();
    this.createAttachmentIfNeeded(record, params);
    await this.createDataBankDocumentIfNeeded(record, params);
    const payload: FileUploadedPayload = {
      file: this.copyRecord(record),
    };
    this.events.publish<FileUploadedPayload>('file.uploaded', payload);
    return this.copyRecord(record);
  }

  /**
   * 读取File Content 值，并转换为运行时使用的数据结构。
   * @param fileId 目标文件标识。
   */
  async readFileContent(fileId: string): Promise<string> {
    const record = this.requireRecord(fileId);
    return this.files.readText(record.path);
  }

  /**
   * 检查文件是否满足当前规则。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async verifyFiles(paths: Array<string>): Promise<Array<FileVerifyResult>> {
    const result = new Array<FileVerifyResult>();
    for (let index = 0; index < paths.length; index += 1) {
      const path = paths[index];
      const verify: FileVerifyResult = {
        path: path,
        exists: isPathInsideRoot(path, this.rootPath) && await this.files.exists(path),
      };
      result.push(verify);
    }
    return result;
  }

  /**
   * 删除指定文件，并清理相关索引或资源引用。
   * @param fileId 目标文件标识。
   */
  async deleteFile(fileId: string): Promise<void> {
    const record = this.requireRecord(fileId);
    this.records.delete(fileId);
    await this.files.delete(record.path);
    if (record.attachmentId.length > 0) {
      this.attachments.deleteAttachment(record.attachmentId);
    }
    if (record.dataBankDocumentId.length > 0) {
      await this.dataBank.deleteDocument(record.dataBankDocumentId);
    }
    await this.persistIndex();
    const payload: FileDeletedPayload = {
      fileId: fileId,
      path: record.path,
    };
    this.events.publish<FileDeletedPayload>('file.deleted', payload);
  }

  /**
   * 读取Files列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async listFiles(): Promise<Array<FileRecord>> {
    const result = new Array<FileRecord>();
    this.records.forEach((record: FileRecord) => {
      result.push(this.copyRecord(record));
    });
    result.sort((left: FileRecord, right: FileRecord) => left.fileName.localeCompare(right.fileName));
    return result;
  }

  /**
   * 创建新的附件IfNeeded记录，写入存储并返回副本。
   * @param record 记录副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  private createAttachmentIfNeeded(record: FileRecord, params: FileUploadParams): void {
    if (params.attachmentId.length === 0 || params.attachmentTargetId.length === 0) {
      return;
    }
    const attachmentParams: AttachmentCreateParams = {
      id: params.attachmentId,
      kind: 'file',
      fileName: record.fileName,
      mimeType: record.mimeType,
      storagePath: record.path,
      content: record.content,
      includeInPrompt: params.includeInPrompt,
      includeInRag: params.includeInRag,
      captionText: '',
      translationText: '',
      metadataJson: JSON.stringify({ fileId: record.id }),
    };
    this.attachments.createAttachment(attachmentParams);
    this.attachments.bindAttachment(params.attachmentId, params.attachmentTargetType, params.attachmentTargetId);
  }

  /**
   * 创建新的数据Bank文档IfNeeded记录，写入存储并返回副本。
   * @param record 记录副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  private async createDataBankDocumentIfNeeded(record: FileRecord, params: FileUploadParams): Promise<void> {
    if (params.dataBankDocumentId.length === 0) {
      return;
    }
    const documentParams: DataBankDocumentCreateParams = {
      id: params.dataBankDocumentId,
      scope: params.dataBankScope,
      sourceType: 'file',
      fileName: record.fileName,
      mimeType: record.mimeType,
      content: record.content,
      tags: params.dataBankTags.slice(),
      metadataJson: params.metadataJson,
      enabled: true,
    };
    await this.dataBank.createDocument(documentParams);
  }

  /**
   * 读取必须存在的Record 值，缺失时抛出错误。
   * @param fileId 目标文件标识。
   */
  private requireRecord(fileId: string): FileRecord {
    const record = this.records.get(fileId);
    if (record === undefined) {
      throw new Error(`File not found: ${fileId}`);
    }
    return record;
  }
  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data: FileIndexData = {
      files: await this.listFiles(),
    };
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private copyRecord(record: FileRecord): FileRecord {
    return {
      schemaVersion: record.schemaVersion,
      id: record.id,
      fileName: record.fileName,
      mimeType: record.mimeType,
      path: record.path,
      content: record.content,
      attachmentId: record.attachmentId,
      dataBankDocumentId: record.dataBankDocumentId,
      metadataJson: record.metadataJson,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }
}
