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

export class DataBankRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private documents: Map<string, DataBankDocumentRecord> = new Map<string, DataBankDocumentRecord>();
  private rootPath: string = 'tavern-data/users/default/databank';

  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

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

  async getDocument(documentId: string): Promise<DataBankDocumentRecord | undefined> {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  async readDocumentContent(documentId: string): Promise<string> {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      throw new Error(`DataBank document not found: ${documentId}`);
    }
    return this.files.readText(record.path);
  }

  async listDocuments(includeDisabled: boolean): Promise<Array<DataBankDocumentRecord>> {
    const result = new Array<DataBankDocumentRecord>();
    this.documents.forEach((record: DataBankDocumentRecord) => {
      if (includeDisabled || record.enabled) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

  async listByScope(scope: string, includeDisabled: boolean): Promise<Array<DataBankDocumentRecord>> {
    const result = new Array<DataBankDocumentRecord>();
    this.documents.forEach((record: DataBankDocumentRecord) => {
      if (record.scope === scope && (includeDisabled || record.enabled)) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

  async listByTag(tag: string, includeDisabled: boolean): Promise<Array<DataBankDocumentRecord>> {
    const result = new Array<DataBankDocumentRecord>();
    this.documents.forEach((record: DataBankDocumentRecord) => {
      if ((includeDisabled || record.enabled) && this.hasTag(record, tag)) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

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

  async exportData(includeDisabled: boolean): Promise<DataBankExportData> {
    const documents = await this.listDocuments(includeDisabled);
    return {
      documents: documents,
    };
  }

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

  private requireRecord(documentId: string): DataBankDocumentRecord {
    const record = this.documents.get(documentId);
    if (record === undefined) {
      throw new Error(`DataBank document not found: ${documentId}`);
    }
    return record;
  }

  private async writeRecordContent(record: DataBankDocumentRecord): Promise<void> {
    await this.files.writeText(record.path, record.content, false);
  }

  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data = await this.exportData(true);
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

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

  private async deleteDirectoryTree(path: string): Promise<void> {
    const children = await this.files.list(path);
    for (let index = 0; index < children.length; index += 1) {
      await this.deleteDirectoryTree(`${path}/${children[index]}`);
    }
    await this.files.delete(path);
  }

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
