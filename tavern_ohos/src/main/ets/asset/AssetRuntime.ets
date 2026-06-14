import { EventBus } from '../runtime/EventBus';
import type { AssetType } from '../contracts/PublicContracts';
import { safeFileName, safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  AssetCreateParams,
  AssetDeletedPayload,
  AssetImportedPayload,
  AssetIndexData,
  AssetRecord,
  AssetRenamedPayload,
} from './AssetModels';

/**
 * 提供资源文件相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class AssetRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 记录副本列表，由当前实例内部维护。
   */
  private records: Map<string, AssetRecord> = new Map<string, AssetRecord>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/assets';

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
   * 从外部数据导入Asset 值，转换为当前运行时的数据结构。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  async importAsset(params: AssetCreateParams): Promise<AssetRecord> {
    const now = Date.now();
    const existing = this.records.get(params.id);
    // file 名称。
    const fileName = safeFileName(params.fileName);
    const record: AssetRecord = {
      schemaVersion: 1,
      id: params.id,
      type: params.type,
      fileName: fileName,
      mimeType: params.mimeType,
      path: this.assetPath(params.type, fileName),
      content: params.content,
      metadataJson: params.metadataJson,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(record.id, this.copyRecord(record));
    await this.writeRecord(record);
    await this.persistIndex();
    const payload: AssetImportedPayload = {
      asset: this.copyRecord(record),
    };
    this.events.publish<AssetImportedPayload>('asset.imported', payload);
    return this.copyRecord(record);
  }

  /**
   * 读取Asset Content 值，并转换为运行时使用的数据结构。
   * @param assetId 目标资源标识。
   */
  async readAssetContent(assetId: string): Promise<string> {
    const record = this.requireRecord(assetId);
    return this.files.readText(record.path);
  }

  /**
   * 读取Assets列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async listAssets(): Promise<Array<AssetRecord>> {
    const result = new Array<AssetRecord>();
    this.records.forEach((record: AssetRecord) => {
      result.push(this.copyRecord(record));
    });
    return this.sortRecords(result);
  }

  /**
   * 读取ByType列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async listByType(type: AssetType): Promise<Array<AssetRecord>> {
    const result = new Array<AssetRecord>();
    this.records.forEach((record: AssetRecord) => {
      if (record.type === type) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

  /**
   * 更新资源状态，必要时写回存储并发布对应事件。
   * @param assetId 目标资源标识。
   * @param newFileName 新记录文件名称。
   */
  async renameAsset(assetId: string, newFileName: string): Promise<AssetRecord> {
    const record = this.requireRecord(assetId);
    const oldPath = record.path;
    const content = await this.files.readText(oldPath);
    // file 名称。
    const fileName = safeFileName(newFileName);
    const updated = this.copyRecord(record);
    updated.fileName = fileName;
    updated.path = this.assetPath(record.type, fileName);
    updated.updatedAt = Date.now();
    updated.content = content;
    await this.files.writeText(updated.path, content, false);
    await this.files.delete(oldPath);
    this.records.set(updated.id, this.copyRecord(updated));
    await this.persistIndex();
    const payload: AssetRenamedPayload = {
      assetId: assetId,
      oldPath: oldPath,
      asset: this.copyRecord(updated),
    };
    this.events.publish<AssetRenamedPayload>('asset.renamed', payload);
    return this.copyRecord(updated);
  }

  /**
   * 删除指定资源，并清理相关索引或资源引用。
   * @param assetId 目标资源标识。
   */
  async deleteAsset(assetId: string): Promise<void> {
    const record = this.requireRecord(assetId);
    this.records.delete(assetId);
    await this.files.delete(record.path);
    await this.persistIndex();
    const payload: AssetDeletedPayload = {
      assetId: assetId,
      type: record.type,
      path: record.path,
    };
    this.events.publish<AssetDeletedPayload>('asset.deleted', payload);
  }

  /**
   * 读取必须存在的Record 值，缺失时抛出错误。
   * @param assetId 目标资源标识。
   */
  private requireRecord(assetId: string): AssetRecord {
    const record = this.records.get(assetId);
    if (record === undefined) {
      throw new Error(`Asset not found: ${assetId}`);
    }
    return record;
  }

  /**
   * 写入Record 值，持久化当前运行时状态。
   * @param record 记录副本。
   */
  private async writeRecord(record: AssetRecord): Promise<void> {
    await this.files.writeText(record.path, record.content, false);
  }
  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data: AssetIndexData = {
      assets: await this.listAssets(),
    };
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }
  private assetPath(type: AssetType, fileName: string): string {
    return `${this.rootPath}/${this.folderForType(type)}/${fileName}`;
  }
  private folderForType(type: AssetType): string {
    if (type === 'image') {
      return 'images';
    }
    if (type === 'background') {
      return 'backgrounds';
    }
    if (type === 'theme') {
      return 'themes';
    }
    if (type === 'thumbnail') {
      return 'thumbnails';
    }
    if (type === 'audio') {
      return 'audio';
    }
    return safePathSegment(type, 'misc');
  }
  private sortRecords(records: Array<AssetRecord>): Array<AssetRecord> {
    records.sort((left: AssetRecord, right: AssetRecord) => left.id.localeCompare(right.id));
    return records;
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private copyRecord(record: AssetRecord): AssetRecord {
    return {
      schemaVersion: record.schemaVersion,
      id: record.id,
      type: record.type,
      fileName: record.fileName,
      mimeType: record.mimeType,
      path: record.path,
      content: record.content,
      metadataJson: record.metadataJson,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }
}
