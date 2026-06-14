import { EventBus } from '../runtime/EventBus';
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
 * 提供资源文件相关的无 UI 运行时能力，负责资源导入、读取、重命名、删除等全生命周期管理，
 * 维护内存索引并持久化到磁盘，通过事件总线向外部模块发布资源变更通知，
 * 用于在角色头像、聊天背景、主题等资源文件管理流程中驱动数据读写和状态同步。
 */
export class AssetRuntime {
  /**
   * 文件存储适配器，用于在资源创建、读取、重命名、删除等流程中执行磁盘文件的读写删除操作。
   */
  private files: TavernFileStore;
  /**
   * 事件总线实例，用于在资源导入、重命名、删除等操作完成后发布事件，供 UI 或其他模块监听响应。
   */
  private events: EventBus;
  /**
   * 内存中的资源文件记录映射表，以资源 id 为键，用于在资源管理各流程中快速存取资源元信息。
   */
  private records: Map<string, AssetRecord> = new Map<string, AssetRecord>();
  /**
   * 数据根路径，用于在文件读写流程中定位资源存储目录。
   */
  private rootPath: string = 'tavern-data/users/default/assets';

  /**
   * 初始化当前运行时实例，在模块加载时调用，建立文件存储和事件总线的连接通道。
   * @param files 文件存储适配器，用于在资源各操作流程中持久化资源数据和索引。
   * @param events 事件总线，用于在资源变更操作完成后发布事件通知外部模块。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 从外部导入资源文件，创建记录、写入磁盘、更新索引并发布导入事件，
   * 用于在用户导入头像、背景等资源文件时将数据持久化到应用存储中。
   * @param params 资源创建参数，包含类型、文件名、内容等，由外部调用方传入以确定资源的存储方式和路径。
   * @returns 创建后的资源记录副本。
   */
  async importAsset(params: AssetCreateParams): Promise<AssetRecord> {
    const now = Date.now();
    const existing = this.records.get(params.id);
    // 对文件名做安全检查，过滤非法字符
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
   * 读取指定资源的文件内容，用于在外部需要获取资源实际数据（如图片 base64、文本内容）时调用。
   * @param assetId 目标资源标识，用于在记录映射表中定位资源并获取其存储路径。
   * @returns 资源的文本内容。
   */
  async readAssetContent(assetId: string): Promise<string> {
    const record = this.requireRecord(assetId);
    return this.files.readText(record.path);
  }

  /**
   * 获取所有资源记录的深拷贝列表，用于在资源管理 UI 或数据导出流程中列出全部可用资源。
   * @returns 按 id 排序的资源记录列表。
   */
  async listAssets(): Promise<Array<AssetRecord>> {
    const result = new Array<AssetRecord>();
    this.records.forEach((record: AssetRecord) => {
      result.push(this.copyRecord(record));
    });
    return this.sortRecords(result);
  }

  /**
   * 按资源类型筛选并返回资源记录列表（深拷贝），
   * 用于在分类展示（如图片列表、背景列表、主题列表）流程中过滤特定类型的资源。
   * @param type 资源类型，用于在查询流程中筛选匹配的资源记录。
   * @returns 匹配指定类型的资源记录列表。
   */
  async listByType(type: string): Promise<Array<AssetRecord>> {
    const result = new Array<AssetRecord>();
    this.records.forEach((record: AssetRecord) => {
      if (record.type === type) {
        result.push(this.copyRecord(record));
      }
    });
    return this.sortRecords(result);
  }

  /**
   * 重命名资源文件，同步更新存储路径和索引并发布重命名事件，
   * 用于在用户修改资源文件名时同步更新磁盘和内存中的记录。
   * @param assetId 目标资源标识，用于在记录映射表中定位要重命名的资源。
   * @param newFileName 新的文件名称，经过安全检查后用于更新文件名和存储路径。
   * @returns 更新后的资源记录副本。
   */
  async renameAsset(assetId: string, newFileName: string): Promise<AssetRecord> {
    const record = this.requireRecord(assetId);
    const oldPath = record.path;
    const content = await this.files.readText(oldPath);
    // 对文件名做安全检查，过滤非法字符
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
   * 删除指定资源，从内存映射表和磁盘中移除并发布删除事件，
   * 用于在用户移除资源时同时清理内存记录和磁盘文件。
   * @param assetId 目标资源标识，用于在记录映射表中定位要删除的资源。
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
   * 获取指定资源记录，不存在时抛出异常。
   * @param assetId 目标资源标识。
   * @returns 资源记录（内部引用）。
   */
  private requireRecord(assetId: string): AssetRecord {
    const record = this.records.get(assetId);
    if (record === undefined) {
      throw new Error(`Asset not found: ${assetId}`);
    }
    return record;
  }

  /**
   * 将资源文件内容写入磁盘持久化存储。
   * @param record 要写入的资源记录。
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
  private assetPath(type: string, fileName: string): string {
    return `${this.rootPath}/${this.folderForType(type)}/${fileName}`;
  }
  private folderForType(type: string): string {
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
   * 深拷贝 AssetRecord，防止外部代码修改内部状态。
   * @param record 要复制的资源记录。
   * @returns 深拷贝后的资源记录。
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
