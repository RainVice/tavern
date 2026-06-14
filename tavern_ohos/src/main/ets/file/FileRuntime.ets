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
 * 文件上传流程涉及：安全文件名清理、物理文件持久化、附件关联创建、
 * 数据银行文档创建以及内存索引维护，适用于用户上传图片、文档等场景。
 */
export class FileRuntime {
  /**
   * 文件存储适配器，用于将文件内容写入磁盘、读取磁盘文件及写入 index.json 持久化索引。
   */
  private files: TavernFileStore;
  /**
   * 事件总线，用于在文件上传/删除后向 UI 层、附件系统等广播状态变更事件。
   */
  private events: EventBus;
  /**
   * 附件运行时，用于在 uploadFile 流程中创建附件记录并将文件绑定到目标对象（消息/角色）。
   */
  private attachments: AttachmentRuntime;
  /**
   * 数据银行运行时，用于在 uploadFile 流程中将文件内容同步创建为知识库文档。
   */
  private dataBank: DataBankRuntime;
  /**
   * 文件记录的内存索引，键为文件 ID，值为 FileRecord，
   * 用于在运行时快速查找文件元数据，并通过 persistIndex 持久化为 index.json。
   */
  private records: Map<string, FileRecord> = new Map<string, FileRecord>();
  /**
   * 文件存储的根路径，用于拼接实际磁盘文件路径，
   * 默认值为 'tavern-data/users/default/assets/files'。
   */
  private rootPath: string = 'tavern-data/users/default/assets/files';

  /**
   * 注入文件运行时所需的所有依赖并初始化实例状态。
   * @param files 文件存储适配器，用于写入物理文件内容和管理文件索引。
   * @param events 事件总线，用于在 uploadFile/deleteFile 完成后广播 FileUploadedPayload 或 FileDeletedPayload。
   * @param attachments 附件运行时，用于在文件上传流程中创建附件绑定（关联消息或角色）。
   * @param dataBank 数据银行运行时，用于在上传流程中创建数据银行文档。
   */
  constructor(files: TavernFileStore, events: EventBus, attachments: AttachmentRuntime, dataBank: DataBankRuntime) {
    this.files = files;
    this.events = events;
    this.attachments = attachments;
    this.dataBank = dataBank;
  }

  /**
   * 清理文件名中的不安全字符，防止路径遍历或名称逃逸攻击。
   * 在 uploadFile 流程中作为文件名的预处理步骤调用。
   * @param fileName 原始文件名，可能包含非法字符（如 '/'、'..' 等），经 safeFileName 清理后用于磁盘文件路径。
   */
  sanitizeFileName(fileName: string): string {
    return safeFileName(fileName);
  }

  /**
   * 上传文件，创建文件记录、持久化到磁盘、创建附件和数据银行文档，并发布上传事件。
   * 完整的文件上传主流程，由宿主或其他模块在用户选择文件后调用。
   * @param params 上传文件所需参数，包含文件元数据、内容以及附件和数据银行关联信息。
   * @returns 上传完成后创建的 FileRecord 副本，包含完整的文件元数据和路径信息。
   */
  async uploadFile(params: FileUploadParams): Promise<FileRecord> {
    const now = Date.now();
    const existing = this.records.get(params.id);
    // 清理后的安全文件名，防止路径逃逸
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
   * 读取指定文件的内容文本，从物理存储中读取。
   * 在需要使用文件内容（如显示图片、发送消息附件）时由宿主调用。
   * @param fileId 要读取的文件标识，用于在 records 索引中查找对应文件记录以获取磁盘路径。
   */
  async readFileContent(fileId: string): Promise<string> {
    const record = this.requireRecord(fileId);
    return this.files.readText(record.path);
  }

  /**
   * 批量验证指定路径列表中的文件是否位于安全根目录内且实际存在。
   * 在 UI 文件列表刷新或安全检查时由宿主调用。
   * @param paths 待验证的文件路径列表，每个路径会分别检查路径安全和文件存在性。
   * @returns 每条路径对应的验证结果（路径是否在安全范围内且文件存在于磁盘）。
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
   * 删除指定文件记录，清理磁盘文件、关联附件、关联数据银行文档，并发布删除事件。
   * 在用户或系统需要移除文件时由宿主调用，执行完整的清理流程。
   * @param fileId 要删除的文件标识，用于在 records 索引中查找对应记录以获取磁盘路径和关联信息。
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
   * 返回所有文件记录的副本列表，按文件名字母序排序。
   * 在 UI 文件列表展现或导出操作时由宿主调用。
   * @returns 文件记录列表，每个条目均为副本，修改返回值不影响内部状态。
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
   * 当上传文件包含附件关联时，创建附件并绑定到目标对象。
   * @param record 已上传文件的记录。
   * @param params 上传时传入的原始参数，包含附件关联信息。
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
   * 当上传文件包含数据银行文档关联时，创建对应的数据银行文档。
   * @param record 已上传文件的记录。
   * @param params 上传时传入的原始参数，包含数据银行关联信息。
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
   * 按文件 ID 查找文件记录，不存在时抛出错误。
   * @param fileId 要查找的文件标识。
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
   * 深拷贝文件记录，防止外部代码修改内部状态。
   * @param record 要复制的原始文件记录。
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
