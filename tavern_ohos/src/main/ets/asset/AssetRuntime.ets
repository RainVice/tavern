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
 * 资源文件运行时管理器，负责无 UI 层的资源生命周期：
 * - 维护内存中的 records Map，追踪所有已知资源的最新状态；
 * - 操作底层文件存储（TavernFileStore）读写具体文件内容；
 * - 每次变更后通过 EventBus 发布 'asset.imported/renamed/deleted' 事件，
 *   供消费方（如画廊页面 UI、BackgroundRuntime）响应。
 *
 * 资源分为五种类型（image / background / theme / thumbnail / audio），
 * 每种对应文件存储下的一个子目录。
 */
export class AssetRuntime {
  /**
   * 底层文件存储适配器，负责实际的文件读写与目录管理。
   */
  private files: TavernFileStore;
  /**
   * 事件总线实例，每次资源变更后发布对应事件通知外部消费方。
   */
  private events: EventBus;
  /**
   * 内存记录缓存，key 为资源 id，value 为资源记录的副本。
   * 每次 import、rename、delete 操作后同步更新此缓存并重新生成 index.json 快照。
   */
  private records: Map<string, AssetRecord> = new Map<string, AssetRecord>();
  /**
   * 资源文件存储的根目录路径，所有资源文件存放于此目录下按类型分类的子目录中。
   */
  private rootPath: string = 'tavern-data/users/default/assets';

  /**
   * 构造一个 AssetRuntime 实例。
   * @param files 文件存储适配器，用于文件读写和目录管理。
   * @param events 事件总线实例，用于发布资源变更事件。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 导入一个资源文件。
   * 对于相同的 id 会合并更新（保留首次 createdAt），否则新建记录。
   * 依次执行：写文件 -> 更新内存缓存 -> 持久化 index.json 快照 -> 发布 'asset.imported' 事件。
   * @param params 资源创建参数，包含 id、类型、文件名、内容、MIME 类型和元数据。
   * @returns 导入完成后的完整资源记录（副本），调用方可安全读取。
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
   * 读取指定资源文件的原始文本内容。
   * 先通过 records Map 查找元数据，再从文件存储中读取实际内容。
   * @param assetId 目标资源的唯一标识。
   * @returns 资源文件的内容字符串。
   */
  async readAssetContent(assetId: string): Promise<string> {
    const record = this.requireRecord(assetId);
    return this.files.readText(record.path);
  }

  /**
   * 获取当前内存中所有资源记录的只读副本，按 id 字典序排列。
   * 每次返回新数组和新对象，调用方修改返回值不会影响内部状态。
   * @returns 所有资源记录的副本列表。
   */
  async listAssets(): Promise<Array<AssetRecord>> {
    const result = new Array<AssetRecord>();
    this.records.forEach((record: AssetRecord) => {
      result.push(this.copyRecord(record));
    });
    return this.sortRecords(result);
  }

  /**
   * 根据资源类型过滤记录，返回该类型下所有资源的只读副本列表，按 id 字典序排列。
   * @param type 要筛选的资源类型。
   * @returns 符合条件的资源记录副本列表。
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
   * 重命名一个已有资源文件。
   * 流程：读出现有内容 -> 在新路径写入 -> 删除旧文件 -> 更新内存缓存 ->
   * 持久化 index.json 快照 -> 发布 'asset.renamed' 事件。
   * @param assetId 要重命名的资源唯一标识。
   * @param newFileName 新文件名（会经过安全过滤，移除路径分隔符等非法字符）。
   * @returns 重命名后的完整资源记录（副本）。
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
   * 删除指定资源文件。
   * 流程：从内存缓存移除 -> 从文件存储删除 -> 持久化 index.json 快照 -> 发布 'asset.deleted' 事件。
   * 如果指定的 id 在 records 中不存在，会抛错。
   * @param assetId 要删除的资源唯一标识。
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
   * 按 id 查找资源记录，若不存在则抛出异常。
   * 所有公开 API 在读写操作前均通过此方法做存在性校验。
   * @param assetId 目标资源唯一标识。
   * @returns 匹配的资源记录（直接引用，非副本）。
   */
  private requireRecord(assetId: string): AssetRecord {
    const record = this.records.get(assetId);
    if (record === undefined) {
      throw new Error(`Asset not found: ${assetId}`);
    }
    return record;
  }

  /**
   * 将资源记录的内容写入文件存储。
   * @param record 要写入的资源记录，writeRecord 读取其 path 和 content 字段执行写入。
   */
  private async writeRecord(record: AssetRecord): Promise<void> {
    await this.files.writeText(record.path, record.content, false);
  }

  /**
   * 将当前内存中的所有资源记录持久化为 index.json 快照文件到存储根目录。
   * 每次 importAsset、renameAsset、deleteAsset 操作后自动调用，用于下次启动时重建 records Map。
   */
  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data: AssetIndexData = {
      assets: await this.listAssets(),
    };
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  /**
   * 根据资源类型和文件名拼接完整的存储路径（rootPath + 类型子目录 + 文件名）。
   * @param type 资源类型。
   * @param fileName 安全的文件名。
   * @returns 完整的相对路径字符串。
   */
  private assetPath(type: AssetType, fileName: string): string {
    return `${this.rootPath}/${this.folderForType(type)}/${fileName}`;
  }

  /**
   * 将资源类型映射为文件子目录名。
   * image -> images, background -> backgrounds, theme -> themes,
   * thumbnail -> thumbnails, audio -> audio, 未知类型 -> safePathSegment(type, 'misc')。
   * @param type 资源类型。
   * @returns 对应的目录名称。
   */
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

  /**
   * 对资源记录列表按 id 进行字典序排序。
   * @param records 待排序的记录数组（直接修改原数组）。
   * @returns 排序后的数组（与原数组为同一引用）。
   */
  private sortRecords(records: Array<AssetRecord>): Array<AssetRecord> {
    records.sort((left: AssetRecord, right: AssetRecord) => left.id.localeCompare(right.id));
    return records;
  }

  /**
   * 深度复制一条资源记录，返回全新的对象。
   * 所有公开 API 返回的记录均通过此方法复制，确保调用方无法直接修改内部 records Map。
   * @param record 要复制的资源记录。
   * @returns 全新的资源记录对象。
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
