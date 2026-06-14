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
 * 提供Data Bank 文档相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class DataBankRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * documents 列表，由当前实例内部维护。
   */
  private documents: Map<string, DataBankDocumentRecord> = new Map<string, DataBankDocumentRecord>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/databank';

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 创建新的文档记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
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
   * 读取指定文档，不存在时抛出错误。
   * @param documentId 目标文档标识。
   * @returns 更新或读取后的记录副本。
   */
  async getDocument(documentId: string): Promise<DataBankDocumentRecord | undefined> {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  /**
   * 读取Document Content 值，并转换为运行时使用的数据结构。
   * @param documentId 目标文档标识。
   */
  async readDocumentContent(documentId: string): Promise<string> {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      throw new Error(`DataBank document not found: ${documentId}`);
    }
    return this.files.readText(record.path);
  }

  /**
   * 读取Documents列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 读取ByScope列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param scope 绑定或查询使用的作用域。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 读取标签列表，返回副本，调用方修改返回值不会直接改变内部状态。


   * @returns 条件命中时返回 true，否则返回 false。
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
   * 设置文档启用状态，用于切换运行时状态或保存配置。
   * @param documentId 目标文档标识。
   * @param enabled 是否启用该能力。
   * @returns 条件命中时返回 true，否则返回 false。
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
   * 更新指定元数据，写回存储并按需发布变更事件。
   * @param documentId 目标文档标识。
   * @param metadataJson metadata JSON 字符串。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 删除指定文档，并清理相关索引或资源引用。
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
   * 导出数据，用于备份、迁移或与 SillyTavern 数据互通。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  async exportData(includeDisabled: boolean): Promise<DataBankExportData> {
    const documents = await this.listDocuments(includeDisabled);
    return {
      documents: documents,
    };
  }

  /**
   * 从外部数据导入Data 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 读取必须存在的Record 值，缺失时抛出错误。
   * @param documentId 目标文档标识。
   */
  private requireRecord(documentId: string): DataBankDocumentRecord {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      throw new Error(`DataBank document not found: ${documentId}`);
    }
    return record;
  }

  /**
   * 写入Record Content 值，持久化当前运行时状态。
   * @param record 记录副本。
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
   * 发布Data Bank 文档事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。
   * @param record 记录副本。
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
   * 删除指定DirectoryTree，并清理相关索引或资源引用。
   * @param path 目标文件或目录路径。
   */
  private async deleteDirectoryTree(path: string): Promise<void> {
    const children = await this.files.list(path);
    for (let index = 0; index < children.length; index += 1) {
      await this.deleteDirectoryTree(`${path}/${children[index]}`);
    }
    await this.files.delete(path);
  }

  /**
   * 判断当前对象是否包含Tag 值。
   * @param record 记录副本。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
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
