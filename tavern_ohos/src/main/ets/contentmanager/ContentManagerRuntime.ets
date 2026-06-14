import { EventBus } from '../runtime/EventBus';
import type {
  ContentDownloadProgressPayload,
  ContentExportData,
  ContentInstallFailedPayload,
  ContentInstalledPayload,
  ContentItem,
  ContentSource,
  ContentType,
  ContentRemovedPayload,
  InstallStatus,
  PackageRecord,
} from './ContentManagerModels';

/**
 * 提供内容安装相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ContentManagerRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 内容条目映射表，以 itemId 为键维护所有已安装条目的内存索引。
   */
  private items: Map<string, ContentItem> = new Map<string, ContentItem>();
  /**
   * 内容包记录映射表，以 packageId 为键维护所有注册包的内存索引。
   */
  private packages: Map<string, PackageRecord> = new Map<string, PackageRecord>();
  /**
   * 条目自增计数器，每次创建新条目时递增用于生成唯一 itemId。
   */
  private itemCounter: number = 0;
  /**
   * 包自增计数器，每次注册新包时递增用于生成唯一 packageId。
   */
  private packageCounter: number = 0;

  /**
   * 构造内容管理器运行时实例。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) { this.events = events; }

  /**
   * 按内容类型查询条目列表，返回副本以避免外部修改内部状态。
   * @param contentType 内容类型过滤条件，不传则返回全部。
   * @returns 符合条件的条目列表；调用方可安全读取该副本。
   */
  listContent(contentType?: ContentType): Array<ContentItem> {
    const result = new Array<ContentItem>();
    const values = Array.from(this.items.values());
    for (let index = 0; index < values.length; index += 1) {
      if (contentType === undefined || values[index].contentType === contentType) { result.push(this.copyItem(values[index])); }
    }
    return result;
  }

  /**
   * 按安装状态查询条目列表，返回副本以避免外部修改内部状态。
   * @param status 目标安装状态。
   * @returns 符合条件的条目列表；调用方可安全读取该副本。
   */
  listByStatus(status: InstallStatus): Array<ContentItem> {
    const result = new Array<ContentItem>();
    const values = Array.from(this.items.values());
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].status === status) { result.push(this.copyItem(values[index])); }
    }
    return result;
  }

  /**
   * 创建并添加一个新内容条目。
   * @param contentType 内容类型。
   * @param source 来源类型。
   * @param sourceUrl 来源地址。
   * @param displayName 显示名称。
   * @returns 新创建的内容条目副本。
   */
  installContent(contentType: ContentType, source: ContentSource, sourceUrl: string, displayName: string): ContentItem {
    this.itemCounter += 1;
    // item 标识。
    const itemId = `content-${this.itemCounter}`;
    const now = Date.now();
    const item: ContentItem = {
      itemId: itemId, contentType: contentType, source: source, sourceUrl: sourceUrl,
      displayName: displayName, version: '', status: 'pending', installPath: '',
      size: 0, metadata: {}, error: '', createdAt: now, updatedAt: now,
    };
    this.items.set(itemId, this.copyItem(item));
    return this.copyItem(item);
  }

  /**
   * 更新条目下载进度，同步内部状态并发布进度事件。
   * @param itemId 目标内容项标识。
   * @param progress 下载进度值（0-100）。
   * @returns 更新后的条目副本。
   */
  updateProgress(itemId: string, progress: number): ContentItem {
    const item = this.requireItem(itemId);
    item.status = 'downloading'; item.updatedAt = Date.now();
    const normalizedProgress = Math.max(0, Math.min(100, progress));
    const payload: ContentDownloadProgressPayload = { item: this.copyItem(item), progress: normalizedProgress };
    this.events.publish<ContentDownloadProgressPayload>('content.download.progress', payload);
    return this.copyItem(item);
  }

  /**
   * 标记条目安装完成，写入最终路径和版本信息并发布完成事件。
   * @param itemId 目标内容项标识。
   * @param installPath 安装路径。
   * @param version 安装版本号。
   * @returns 更新后的条目副本。
   */
  completeInstall(itemId: string, installPath: string, version: string): ContentItem {
    const item = this.requireItem(itemId);
    item.status = 'installed'; item.installPath = installPath; item.version = version;
    item.updatedAt = Date.now();
    const payload: ContentInstalledPayload = { item: this.copyItem(item) };
    this.events.publish<ContentInstalledPayload>('content.installed', payload);
    return this.copyItem(item);
  }

  /**
   * 标记条目安装失败，保存错误信息并发布失败事件。
   * @param itemId 目标内容项标识。
   * @param error 错误信息。
   * @returns 更新后的条目副本。
   */
  failInstall(itemId: string, error: string): ContentItem {
    const item = this.requireItem(itemId);
    item.status = 'failed'; item.error = error; item.updatedAt = Date.now();
    const payload: ContentInstallFailedPayload = { item: this.copyItem(item) };
    this.events.publish<ContentInstallFailedPayload>('content.install.failed', payload);
    return this.copyItem(item);
  }

  /**
   * 移除指定内容条目并发布移除事件。
   * @param itemId 待移除的内容项标识。
   */
  removeContent(itemId: string): void {
    this.requireItem(itemId);
    this.items.delete(itemId);
    this.events.publish<ContentRemovedPayload>('content.removed', { itemId: itemId });
  }

  /**
   * 获取指定条目的副本，条目不存在时抛出错误。
   * @param itemId 目标内容项标识。
   * @returns 条目副本。
   */
  getItem(itemId: string): ContentItem { return this.copyItem(this.requireItem(itemId)); }

  /**
   * 注册一个新的内容包，使其可被后续流程使用。
   * @param displayName 显示名称。
   * @param contentType 内容类型。
   * @param version 版本号。
   * @param author 作者。
   * @param installPath 安装路径。
   * @returns 新创建的包记录副本。
   */
  registerPackage(displayName: string, contentType: ContentType, version: string, author: string, installPath: string): PackageRecord {
    this.packageCounter += 1;
    // package 标识。
    const packageId = `pkg-${this.packageCounter}`;
    const now = Date.now();
    const record: PackageRecord = {
      packageId: packageId, contentType: contentType, displayName: displayName,
      version: version, author: author, description: '', installPath: installPath,
      enabled: true, dependencies: new Array<string>(), createdAt: now, updatedAt: now,
    };
    this.packages.set(packageId, this.copyPackage(record));
    return this.copyPackage(record);
  }

  /**
   * 按内容类型查询包记录列表，返回副本以避免外部修改内部状态。
   * @param contentType 内容类型过滤条件，不传则返回全部。
   * @returns 符合条件的包记录列表；调用方可安全读取该副本。
   */
  listPackages(contentType?: ContentType): Array<PackageRecord> {
    const result = new Array<PackageRecord>();
    const values = Array.from(this.packages.values());
    for (let index = 0; index < values.length; index += 1) {
      if (contentType === undefined || values[index].contentType === contentType) { result.push(this.copyPackage(values[index])); }
    }
    return result;
  }

  /**
   * 设置内容包启用状态。
   * @param packageId 目标内容包标识。
   * @param enabled 是否启用。
   * @returns 更新后的包记录副本。
   */
  setPackageEnabled(packageId: string, enabled: boolean): PackageRecord {
    const record = this.requirePackage(packageId);
    record.enabled = enabled; record.updatedAt = Date.now();
    return this.copyPackage(record);
  }

  /**
   * 移除指定内容包。
   * @param packageId 待移除的包标识。
   */
  removePackage(packageId: string): void {
    this.requirePackage(packageId);
    this.packages.delete(packageId);
  }

  /**
   * 导出全部内容条目和包记录。
   * @returns 包含所有条目和包记录的导出数据。
   */
  exportData(): ContentExportData {
    return { items: this.listContent(), packages: this.listPackages() };
  }

  /**
   * 导入内容条目和包记录，存在重复标识时抛出错误。
   * @param data 待导入的导出数据。
   */
  importData(data: ContentExportData): void {
    for (let index = 0; index < data.items.length; index += 1) {
      const item = this.copyItem(data.items[index]);
      if (this.items.has(item.itemId)) {
        throw new Error(`内容条目已存在: ${item.itemId}`);
      }
      this.items.set(item.itemId, item);
      this.itemCounter = Math.max(this.itemCounter, this.parseItemCounter(item.itemId));
    }
    for (let index = 0; index < data.packages.length; index += 1) {
      const record = this.copyPackage(data.packages[index]);
      if (this.packages.has(record.packageId)) {
        throw new Error(`包已存在: ${record.packageId}`);
      }
      this.packages.set(record.packageId, record);
      this.packageCounter = Math.max(this.packageCounter, this.parsePackageCounter(record.packageId));
    }
  }

  /**
   * 按标识获取条目，条目不存在时抛出错误。
   * @param itemId 目标内容项标识。
   * @returns 条目引用。
   */
  private requireItem(itemId: string): ContentItem {
    const item = this.items.get(itemId);
    if (item === undefined) { throw new Error(`内容条目未找到: ${itemId}`); }
    return item;
  }

  /**
   * 按标识获取包记录，包不存在时抛出错误。
   * @param packageId 目标内容包标识。
   * @returns 包记录引用。
   */
  private requirePackage(packageId: string): PackageRecord {
    const record = this.packages.get(packageId);
    if (record === undefined) { throw new Error(`包未找到: ${packageId}`); }
    return record;
  }

  /**
   * 深度复制条目，避免外部修改内部状态。
   * @param item 待复制的条目。
   * @returns 条目副本。
   */
  private copyItem(item: ContentItem): ContentItem {
    return {
      itemId: item.itemId,
      contentType: item.contentType,
      source: item.source,
      sourceUrl: item.sourceUrl,
      displayName: item.displayName,
      version: item.version,
      status: item.status,
      installPath: item.installPath,
      size: item.size,
      metadata: this.copyMetadata(item.metadata),
      error: item.error,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    };
  }

  /**
   * 深度复制包记录，避免外部修改内部状态。
   * @param record 待复制的包记录。
   * @returns 包记录副本。
   */
  private copyPackage(record: PackageRecord): PackageRecord {
    return {
      packageId: record.packageId,
      contentType: record.contentType,
      displayName: record.displayName,
      version: record.version,
      author: record.author,
      description: record.description,
      installPath: record.installPath,
      enabled: record.enabled,
      dependencies: record.dependencies.slice(),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  /**
   * 深度复制元数据字典，避免外部修改内部状态。
   * @param metadata 待复制的元数据字典。
   * @returns 元数据字典副本。
   */
  private copyMetadata(metadata: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {};
    const keys = Object.keys(metadata);
    for (let index = 0; index < keys.length; index += 1) {
      result[keys[index]] = metadata[keys[index]];
    }
    return result;
  }

  /**
   * 从条目标识中解析计数器值，格式非法时返回 0。
   * @param itemId 目标内容项标识。
   * @returns 解析后的计数器值。
   */
  private parseItemCounter(itemId: string): number {
    if (!itemId.startsWith('content-')) {
      return 0;
    }
    const parsed = Number(itemId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 从包标识中解析计数器值，格式非法时返回 0。
   * @param packageId 目标内容包标识。
   * @returns 解析后的计数器值。
   */
  private parsePackageCounter(packageId: string): number {
    if (!packageId.startsWith('pkg-')) {
      return 0;
    }
    const parsed = Number(packageId.substring(4));
    return parsed > 0 ? parsed : 0;
  }
}
