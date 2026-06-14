import { EventBus } from '../runtime/EventBus';
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
 * 提供 DataBank 文档相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 调用方通常是数据处理流程或文档管理器，通过本类执行文档的增删改查和导入导出操作。
 */
export class DataBankRuntime {
  /** 文件存储适配器，用于将文档内容写入文件系统及读取已有内容。 */
  private files: TavernFileStore;
  /** 事件总线，用于发布文档变更事件（创建、更新、启用/禁用、删除），通知订阅方同步状态。 */
  private events: EventBus;
  /** 按文档 ID 索引的文档记录集合，运行时核心状态，所有 CRUD 操作和查询基于此 Map。 */
  private documents: Map<string, DataBankDocumentRecord> = new Map<string, DataBankDocumentRecord>();
  /** DataBank 数据存放的根路径（相对于文件存储），index.json 和文档文件均存放在此路径下。 */
  private rootPath: string = 'tavern-data/users/default/databank';

  /**
   * 初始化当前运行时实例。通常在应用启动或 DataBank 模块初始化时调用。
   * @param files 用于读写文档文件的文件存储适配器，由调用方注入（如 TavernFileStore 实例）。
   * @param events 用于发布文档变更事件的事件总线，供调用方在构造时传入。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 创建新文档，写入文件存储并注册到内存索引中。由外部导入流程或用户手动添加文档时调用。
   * @param params 文档创建参数，包含标识、作用域、内容、标签等，由调用方按 DataBankDocumentCreateParams 准备。
   * @returns 新建文档记录的深拷贝，包含生成的 schemaVersion、path 和时间戳。
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
   * 根据文档 ID 获取文档记录。供外部按 ID 精确读取文档元信息时调用。
   * @param documentId 目标文档标识，必须对应已注册的文档。
   * @returns 文档记录深拷贝，不存在时返回 undefined。
   */
  async getDocument(documentId: string): Promise<DataBankDocumentRecord | undefined> {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  /**
   * 读取指定文档的文本内容。供需要获取文档实际文本数据的流程（如向量化、展示）调用。
   * @param documentId 目标文档标识，必须对应已注册的文档。
   * @returns 文档的文本内容字符串，从文件存储中读取。
   */
  async readDocumentContent(documentId: string): Promise<string> {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      throw new Error(`DataBank document not found: ${documentId}`);
    }
    return this.files.readText(record.path);
  }

  /**
   * 获取所有文档记录的列表，可排除已禁用的文档。供 UI 列表展示或批量导出时调用。
   * @param includeDisabled 是否包含已禁用的文档，UI 列表通常设为 false 只展示启用文档。
   * @returns 文档记录列表深拷贝，按文档 ID 排序。
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
   * 按作用域筛选文档记录。供按逻辑分组（如按用户、按对话）获取文档时调用。
   * @param scope 要匹配的作用域，应与创建文档时指定的 scope 一致。
   * @param includeDisabled 是否包含已禁用的文档。
   * @returns 匹配作用域的文档记录列表深拷贝，按 ID 排序。
   */
  async listByScope(scope: string, includeDisabled: boolean): Promise<Array<DataBankDocumentRecord>> {
    const result = new Array<DataBankDocumentRecord>();
    this.documents.forEach((record: DataBankDocumentRecord) => {
      if (record.scope === scope && (includeDisabled || record.enabled)) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

  /**
   * 按标签筛选文档记录。供按主题或分类标签查找文档时调用。
   * @param tag 要匹配的标签名称，精确匹配文档 tags 数组中的元素。
   * @param includeDisabled 是否包含已禁用的文档。
   * @returns 包含指定标签的文档记录列表深拷贝，按 ID 排序。
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
   * 设置文档的启用/禁用状态，并发布对应事件。由 UI 的文档启用开关或自动启用逻辑调用。
   * @param documentId 目标文档标识。
   * @param enabled 设为 true 启用，false 禁用。变更后默认会影响 listDocuments 等方法的返回结果。
   * @returns 更新后的文档记录深拷贝。
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
   * 更新文档的元数据和标签，写回存储并发布变更事件。由元数据编辑流程或外部同步逻辑调用。
   * @param documentId 目标文档标识。
   * @param metadataJson 新的元数据 JSON 字符串，覆盖原有 metadataJson。
   * @param tags 新的标签列表，覆盖原有 tags 数组。
   * @returns 更新后的文档记录深拷贝。
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
   * 删除文档，同时清理文件系统中的内容和索引文件。由清理流程或用户主动删除操作触发。
   * @param documentId 要删除的文档标识，删除后记录从内存索引和文件系统中一并移除。
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
   * 导出文档数据，用于备份、迁移或与外部系统数据互通。生成包含当前文档记录快照的 DataBankExportData。
   * @param includeDisabled 是否包含已禁用的文档，迁移时通常设为 true 确保完整性。
   * @returns 包含文档列表的导出数据结构。
   */
  async exportData(includeDisabled: boolean): Promise<DataBankExportData> {
    const documents = await this.listDocuments(includeDisabled);
    return {
      documents: documents,
    };
  }

  /**
   * 从外部数据导入文档，可选择替换现有全部文档。由数据恢复或批量导入流程调用。
   * @param data 包含文档列表的导入数据，通常来自之前 exportData 的输出或外部生成的数据。
   * @param replace 为 true 时清空现有文档再导入（全量替换），否则追加到现有文档中。
   * @returns 导入成功的文档记录列表深拷贝，按 ID 排序。
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
   * 根据标识获取文档记录，不存在时抛出异常。供内部方法在操作文档前做存在性校验。
   * @param documentId 目标文档标识。
   * @returns 找到的文档记录引用。
   */
  private requireRecord(documentId: string): DataBankDocumentRecord {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      throw new Error(`DataBank document not found: ${documentId}`);
    }
    return record;
  }

  /**
   * 将文档的文本内容写入文件存储，供 createDocument 和 importData 在保存文档数据时调用。
   * @param record 包含内容和路径的文档记录。
   */
  private async writeRecordContent(record: DataBankDocumentRecord): Promise<void> {
    await this.files.writeText(record.path, record.content, false);
  }

  /**
   * 将当前所有文档记录序列化为 index.json 写入文件存储，用于持久化索引以支持冷启动恢复。
   * 每次文档创建、更新、删除后均需调用以保持索引与内存状态一致。
   */
  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data = await this.exportData(true);
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  /**
   * 发布 DataBank 文档变更事件，通知订阅方状态变化（如 UI 刷新、外部模块同步）。
   * @param eventName 要发布的事件名称（如 'databank.document.created'、'databank.document.updated'）。
   * @param record 变更后的文档记录，供订阅方获取最新状态。
   */
  private publishUpdated(eventName: string, record: DataBankDocumentRecord): void {
    const payload: DataBankUpdatedPayload = {
      documentId: record.id,
      document: this.copyRecord(record),
    };
    this.events.publish<DataBankUpdatedPayload>(eventName, payload);
  }

  /**
   * 根据文档 ID 生成文件存储路径，用于确定文档内容的实际磁盘位置。路径格式："{rootPath}/documents/{safeId}.txt"。
   * @param documentId 文档标识，经过 safePathSegment 处理以移除不安全字符。
   * @returns 生成的完整文件路径。
   */
  private documentPath(documentId: string): string {
    return `${this.rootPath}/documents/${safePathSegment(documentId, 'document')}.txt`;
  }

  /**
   * 递归删除指定目录树及其所有子文件和子目录。供 importData(replace=true) 在清空旧数据时调用。
   * @param path 要删除的目录根路径。
   */
  private async deleteDirectoryTree(path: string): Promise<void> {
    const children = await this.files.list(path);
    for (let index = 0; index < children.length; index += 1) {
      await this.deleteDirectoryTree(`${path}/${children[index]}`);
    }
    await this.files.delete(path);
  }

  /**
   * 检查文档记录是否包含指定标签。供 listByTag 筛选文档时内部调用。
   * @param record 要检查的文档记录。
   * @param tag 要匹配的标签名称，精确比较。
   * @returns 包含该标签时返回 true，否则 false。
   */
  private hasTag(record: DataBankDocumentRecord, tag: string): boolean {
    for (let index = 0; index < record.tags.length; index += 1) {
      if (record.tags[index] === tag) {
        return true;
      }
    }
    return false;
  }

  /**
   * 对文档记录列表按 ID 进行字典序排序。供 listDocuments / listByScope / listByTag / importData 统一排序输出。
   * @param records 待排序的文档记录数组。
   * @returns 排序后的文档记录数组。
   */
  private sortRecords(records: Array<DataBankDocumentRecord>): Array<DataBankDocumentRecord> {
    records.sort((left: DataBankDocumentRecord, right: DataBankDocumentRecord) => left.id.localeCompare(right.id));
    return records;
  }

  /**
   * 深拷贝文档记录，防止外部修改内部状态。所有对外返回 DataBankDocumentRecord 的方法均通过此方法生成副本。
   * @param record 要拷贝的文档记录。
   * @returns 文档记录的深拷贝。
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
