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
 * 文件上传与管理的无 UI 运行时。负责文件记录的增删查、内容读写、附件/知识库联动和事件发布。
 */
export class FileRuntime {
  /**
   * 文件存储适配器，用于文件的读写和删除操作。
   */
  private files: TavernFileStore;
  /**
   * 事件总线，用于发布文件上传/删除事件。
   */
  private events: EventBus;
  /**
   * 附件运行时，用于在上传时创建文件关联的附件。
   */
  private attachments: AttachmentRuntime;
  /**
   * 知识库运行时，用于在上传时创建文件关联的知识库文档。
   */
  private dataBank: DataBankRuntime;
  /**
   * 文件记录的内存索引，以文件 ID 为键。
   */
  private records: Map<string, FileRecord> = new Map<string, FileRecord>();
  /**
   * 文件存储的根路径前缀。
   */
  private rootPath: string = 'tavern-data/users/default/assets/files';

  /**
   * 构造 FileRuntime 实例，注入外部依赖并初始化内部状态。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   * @param attachments 附件运行时。
   * @param dataBank 知识库运行时。
   */
  constructor(files: TavernFileStore, events: EventBus, attachments: AttachmentRuntime, dataBank: DataBankRuntime) {
    this.files = files;
    this.events = events;
    this.attachments = attachments;
    this.dataBank = dataBank;
  }

  /**
   * 清理文件名中的不安全字符，防止路径注入或文件系统逃逸。
   * @param fileName 原始文件名。
   * @returns 清理后的安全文件名。
   */
  sanitizeFileName(fileName: string): string {
    return safeFileName(fileName);
  }

  /**
   * 上传文件：创建或更新文件记录、写入存储、持久化索引，并在需要时创建关联附件和知识库文档。
   * @param params 文件上传所需的参数集合。
   * @returns 新建或更新后的文件记录副本。
   */
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

  /**
   * 读取指定文件的原始内容文本。
   * @param fileId 目标文件的唯一标识。
   * @returns 文件内容字符串。
   */
  async readFileContent(fileId: string): Promise<string> {
    const record = this.requireRecord(fileId);
    return this.files.readText(record.path);
  }

  /**
   * 批量检查指定路径列表中的文件是否存在。
   * @param paths 需要检查的文件路径列表。
   * @returns 每个路径对应的存在性检查结果。
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
   * 删除指定文件记录、清理存储文件，并解除附件和知识库关联。
   * @param fileId 待删除文件的唯一标识。
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
   * 获取所有已上传文件的记录列表，按文件名排序。
   * @returns 文件记录数组，每个元素均为内部记录的副本，调用方无法直接修改内部状态。
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
   * 如果上传参数中指定了附件关联，则创建附件并绑定到目标。
   * @param record 对应的文件记录。
   * @param params 上传参数，包含附件关联信息。
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
   * 如果上传参数中指定了知识库文档关联，则在知识库中创建对应文档。
   * @param record 对应的文件记录。
   * @param params 上传参数，包含知识库文档关联信息。
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
   * 根据文件 ID 获取记录，若不存在则抛出异常。
   * @param fileId 目标文件标识。
   * @returns 匹配的文件记录。
   */
  private requireRecord(fileId: string): FileRecord {
    const record = this.records.get(fileId);
    if (record === undefined) {
      throw new Error(`File not found: ${fileId}`);
    }
    return record;
  }
  /**
   * 将当前文件索引持久化写入存储（index.json），确保重启后可恢复。
   */
  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data: FileIndexData = {
      files: await this.listFiles(),
    };
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  /**
   * 创建文件记录的深拷贝，防止外部代码修改内部状态。
   * @param record 源文件记录。
   * @returns 内容相同的新文件记录对象。
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
