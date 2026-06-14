import { EventBus } from '../runtime/EventBus';
import type { TavernScope } from '../contracts/PublicContracts';
import { safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  DataBankDeletedPayload,
  DataBankDocumentCreateParams,
  DataBankDocumentRecord,
  DataBankExportData,
  DataBankUpdatedPayload,
} from './DataBankModels';

/**
 * 提供 Data Bank 文档管理能力，负责内存索引、文件读写与事件发布。
 */
export class DataBankRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private documents: Map<string, DataBankDocumentRecord> = new Map<string, DataBankDocumentRecord>();
  private rootPath: string = 'tavern-data/users/default/databank';

  /**
   * 初始化运行时实例。
   * @param files 文件存储适配器，用于读写文档内容和索引文件。
   * @param events 事件总线实例，用于发布文档变更事件。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 创建新的文档，写入文件存储并更新内存索引。
   * @param params 文档创建参数。
   * @returns 创建成功的文档记录副本。
   */
  async createDocument(params: DataBankDocumentCreateParams): Promise<DataBankDocumentRecord> {
    const now = Date.now();
    const path = this.documentPath(params.id);
    const existing = this.documents.get(params.id);
    const record: DataBankDocumentRecord = {
      schemaVersion: 1,
      id: params.id,
      scope: params.scope,
      sourceType: params.sourceType,
      fileName: params.fileName,
      mimeType: params.mimeType,
      path: path,
      content: params.content,
      tags: params.tags.slice(),
      metadataJson: params.metadataJson,
      enabled: params.enabled,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.documents.set(record.id, this.copyRecord(record));
    await this.writeRecordContent(record);
    await this.persistIndex();
    this.publishUpdated('databank.document.created', record);
    return this.copyRecord(record);
  }

  /**
   * 根据 ID 查询文档，不存在时返回 undefined。
   * @param documentId 目标文档标识。
   * @returns 文档记录副本，未找到则为 undefined。
   */
  async getDocument(documentId: string): Promise<DataBankDocumentRecord | undefined> {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  /**
   * 读取指定文档的正文内容。
   * @param documentId 目标文档标识。
   * @returns 文档的文本内容。
   */
  async readDocumentContent(documentId: string): Promise<string> {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      throw new Error(`DataBank document not found: ${documentId}`);
    }
    return this.files.readText(record.path);
  }

  /**
   * 列出所有文档记录，可按是否启用过滤。
   * @param includeDisabled 是否包含已禁用的文档。
   * @returns 文档记录副本数组。
   */
  async listDocuments(includeDisabled: boolean): Promise<Array<DataBankDocumentRecord>> {
    const result = new Array<DataBankDocumentRecord>();
    this.documents.forEach((record: DataBankDocumentRecord) => {
      if (includeDisabled || record.enabled) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

  /**
   * 按作用域筛选文档记录。
   * @param scope 作用域。
   * @param includeDisabled 是否包含已禁用的文档。
   * @returns 匹配的文档记录副本数组。
   */
  async listByScope(scope: TavernScope, includeDisabled: boolean): Promise<Array<DataBankDocumentRecord>> {
    const result = new Array<DataBankDocumentRecord>();
    this.documents.forEach((record: DataBankDocumentRecord) => {
      if (record.scope === scope && (includeDisabled || record.enabled)) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

  /**
   * 按标签筛选文档记录。
   * @param tag 标签名称。
   * @param includeDisabled 是否包含已禁用的文档。
   * @returns 匹配的文档记录副本数组。
   */
  async listByTag(tag: string, includeDisabled: boolean): Promise<Array<DataBankDocumentRecord>> {
    const result = new Array<DataBankDocumentRecord>();
    this.documents.forEach((record: DataBankDocumentRecord) => {
      if ((includeDisabled || record.enabled) && this.hasTag(record, tag)) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

  /**
   * 设置文档的启用或禁用状态。
   * @param documentId 目标文档标识。
   * @param enabled 是否启用。
   * @returns 更新后的文档记录副本。
   */
  async setDocumentEnabled(documentId: string, enabled: boolean): Promise<DataBankDocumentRecord> {
    const record = this.requireRecord(documentId);
    const updated = this.copyRecord(record);
    updated.enabled = enabled;
    updated.updatedAt = Date.now();
    this.documents.set(updated.id, this.copyRecord(updated));
    await this.persistIndex();
    this.publishUpdated(enabled ? 'databank.document.enabled' : 'databank.document.disabled', updated);
    return this.copyRecord(updated);
  }

  /**
   * 更新文档的元数据和标签。
   * @param documentId 目标文档标识。
   * @param metadataJson 新的元数据 JSON 字符串。
   * @param tags 新的标签列表。
   * @returns 更新后的文档记录副本。
   */
  async updateMetadata(documentId: string, metadataJson: string, tags: Array<string>): Promise<DataBankDocumentRecord> {
    const record = this.requireRecord(documentId);
    const updated = this.copyRecord(record);
    updated.metadataJson = metadataJson;
    updated.tags = tags.slice();
    updated.updatedAt = Date.now();
    this.documents.set(updated.id, this.copyRecord(updated));
    await this.persistIndex();
    this.publishUpdated('databank.document.updated', updated);
    return this.copyRecord(updated);
  }

  /**
   * 删除指定文档，清理文件存储并更新索引。
   * @param documentId 目标文档标识。
   */
  async deleteDocument(documentId: string): Promise<void> {
    const record = this.requireRecord(documentId);
    this.documents.delete(documentId);
    await this.files.delete(record.path);
    await this.persistIndex();
    const payload: DataBankDeletedPayload = {
      documentId: documentId,
    };
    this.events.publish<DataBankDeletedPayload>('databank.document.deleted', payload);
  }

  /**
   * 导出当前所有文档数据，用于备份或迁移。
   * @param includeDisabled 是否包含已禁用的文档。
   * @returns 包含所有文档记录的导出数据。
   */
  async exportData(includeDisabled: boolean): Promise<DataBankExportData> {
    const documents = await this.listDocuments(includeDisabled);
    return {
      documents: documents,
    };
  }

  /**
   * 从外部导入文档数据，可选择替换或追加。
   * @param data 待导入的文档数据。
   * @param replace 为 true 时清空现有数据再导入，为 false 时追加。
   * @returns 导入成功的文档记录副本数组。
   */
  async importData(data: DataBankExportData, replace: boolean): Promise<Array<DataBankDocumentRecord>> {
    if (replace) {
      await this.deleteDirectoryTree(`${this.rootPath}/documents`);
      this.documents.clear();
    }
    const imported = new Array<DataBankDocumentRecord>();
    for (let index = 0; index < data.documents.length; index += 1) {
      const record = this.copyRecord(data.documents[index]);
      record.path = this.documentPath(record.id);
      this.documents.set(record.id, this.copyRecord(record));
      await this.writeRecordContent(record);
      imported.push(this.copyRecord(record));
    }
    await this.persistIndex();
    return this.sortRecords(imported);
  }

  /**
   * 获取指定文档记录，不存在则抛出错误。
   * @param documentId 目标文档标识。
   * @returns 文档记录。
   */
  private requireRecord(documentId: string): DataBankDocumentRecord {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      throw new Error(`DataBank document not found: ${documentId}`);
    }
    return record;
  }

  /**
   * 将文档内容写入文件存储。
   * @param record 文档记录。
   */
  private async writeRecordContent(record: DataBankDocumentRecord): Promise<void> {
    await this.files.writeText(record.path, record.content, false);
  }
  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data = await this.exportData(true);
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  /**
   * 发布文档变更事件，通知宿主或其他运行时模块。
   * @param eventName 事件名称。
   * @param record 变更后的文档记录。
   */
  private publishUpdated(eventName: string, record: DataBankDocumentRecord): void {
    const payload: DataBankUpdatedPayload = {
      documentId: record.id,
      document: this.copyRecord(record),
    };
    this.events.publish<DataBankUpdatedPayload>(eventName, payload);
  }
  private documentPath(documentId: string): string {
    return `${this.rootPath}/documents/${safePathSegment(documentId, 'document')}.txt`;
  }

  /**
   * 递归删除指定目录树。
   * @param path 目标目录路径。
   */
  private async deleteDirectoryTree(path: string): Promise<void> {
    const children = await this.files.list(path);
    for (let index = 0; index < children.length; index += 1) {
      await this.deleteDirectoryTree(`${path}/${children[index]}`);
    }
    await this.files.delete(path);
  }

  /**
   * 判断文档记录是否包含指定标签。
   * @param record 文档记录。
   * @param tag 待检查的标签。
   * @returns 包含返回 true，否则返回 false。
   */
  private hasTag(record: DataBankDocumentRecord, tag: string): boolean {
    for (let index = 0; index < record.tags.length; index += 1) {
      if (record.tags[index] === tag) {
        return true;
      }
    }
    return false;
  }
  private sortRecords(records: Array<DataBankDocumentRecord>): Array<DataBankDocumentRecord> {
    records.sort((left: DataBankDocumentRecord, right: DataBankDocumentRecord) => left.id.localeCompare(right.id));
    return records;
  }

  /**
   * 深拷贝文档记录，防止外部修改内部状态。
   * @param record 原始记录。
   * @returns 副本。
   */
  private copyRecord(record: DataBankDocumentRecord): DataBankDocumentRecord {
    return {
      schemaVersion: record.schemaVersion,
      id: record.id,
      scope: record.scope,
      sourceType: record.sourceType,
      fileName: record.fileName,
      mimeType: record.mimeType,
      path: record.path,
      content: record.content,
      tags: record.tags.slice(),
      metadataJson: record.metadataJson,
      enabled: record.enabled,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }
}
