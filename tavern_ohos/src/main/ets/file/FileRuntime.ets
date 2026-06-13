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

export class FileRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private attachments: AttachmentRuntime;
  private dataBank: DataBankRuntime;
  private records: Map<string, FileRecord> = new Map<string, FileRecord>();
  private rootPath: string = 'tavern-data/users/default/assets/files';

  constructor(files: TavernFileStore, events: EventBus, attachments: AttachmentRuntime, dataBank: DataBankRuntime) {
    this.files = files;
    this.events = events;
    this.attachments = attachments;
    this.dataBank = dataBank;
  }

  sanitizeFileName(fileName: string): string {
    return safeFileName(fileName);
  }

  async uploadFile(params: FileUploadParams): Promise<FileRecord> {
    const now = Date.now();
    const existing = this.records.get(params.id);
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

  async readFileContent(fileId: string): Promise<string> {
    const record = this.requireRecord(fileId);
    return this.files.readText(record.path);
  }

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

  async listFiles(): Promise<Array<FileRecord>> {
    const result = new Array<FileRecord>();
    this.records.forEach((record: FileRecord) => {
      result.push(this.copyRecord(record));
    });
    result.sort((left: FileRecord, right: FileRecord) => left.fileName.localeCompare(right.fileName));
    return result;
  }

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
