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
   * 项目列表，由当前实例内部维护。
   */
  private items: Map<string, ContentItem> = new Map<string, ContentItem>();
  /**
   * packages 列表，由当前实例内部维护。
   */
  private packages: Map<string, PackageRecord> = new Map<string, PackageRecord>();
  /**
   * item Counter 值，由当前实例内部维护。
   */
  private itemCounter: number = 0;
  /**
   * package Counter 值，由当前实例内部维护。
   */
  private packageCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events = events; }

  /**
   * 读取Content列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 读取ByStatus列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param status 状态值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 执行 installContent 的内部处理步骤，供当前模块复用。

   * @param source 来源类型。

   * @param displayName display名称。
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
   * 更新Progress 列表，同步内部状态并按需发布变更事件。
   * @param itemId 目标内容项标识。

   * @returns 更新或读取后的记录副本。
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
   * 标记Install 值完成，并写入最终结果。
   * @param itemId 目标内容项标识。
   * @param installPath install 路径。
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
   * 标记Install 值失败，并保存错误信息。
   * @param itemId 目标内容项标识。
   * @param error 错误信息。
   */
  failInstall(itemId: string, error: string): ContentItem {
    const item = this.requireItem(itemId);
    item.status = 'failed'; item.error = error; item.updatedAt = Date.now();
    const payload: ContentInstallFailedPayload = { item: this.copyItem(item) };
    this.events.publish<ContentInstallFailedPayload>('content.install.failed', payload);
    return this.copyItem(item);
  }

  /**
   * 移除内容。
   * @param itemId 内容项标识。
   */
  removeContent(itemId: string): void {
    this.requireItem(itemId);
    this.items.delete(itemId);
    this.events.publish<ContentRemovedPayload>('content.removed', { itemId: itemId });
  }

  /**
   * 读取指定Item，不存在时抛出错误。
   * @param itemId 目标内容项标识。
   * @returns 更新或读取后的记录副本。
   */
  getItem(itemId: string): ContentItem { return this.copyItem(this.requireItem(itemId)); }

  /**
   * 注册Package 值，使其可被后续运行时流程使用。
   * @param displayName display名称。



   * @param installPath install 路径。
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
   * 读取Packages列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 设置内容包启用状态，用于切换运行时状态或保存配置。
   * @param packageId 目标内容包标识。
   * @param enabled 是否启用该能力。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  setPackageEnabled(packageId: string, enabled: boolean): PackageRecord {
    const record = this.requirePackage(packageId);
    record.enabled = enabled; record.updatedAt = Date.now();
    return this.copyPackage(record);
  }

  /**
   * 移除包。
   * @param packageId 包标识。
   */
  removePackage(packageId: string): void {
    this.requirePackage(packageId);
    this.packages.delete(packageId);
  }

  // 导出
  exportData(): ContentExportData {
    return { items: this.listContent(), packages: this.listPackages() };
  }

  /**
   * 导入。
   * @param data 数据内容。
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
   * 读取必须存在的Item 值，缺失时抛出错误。
   * @param itemId 目标内容项标识。
   */
  private requireItem(itemId: string): ContentItem {
    const item = this.items.get(itemId);
    if (item === undefined) { throw new Error(`内容条目未找到: ${itemId}`); }
    return item;
  }

  /**
   * 读取必须存在的Package 值，缺失时抛出错误。
   * @param packageId 目标内容包标识。
   */
  private requirePackage(packageId: string): PackageRecord {
    const record = this.packages.get(packageId);
    if (record === undefined) { throw new Error(`包未找到: ${packageId}`); }
    return record;
  }

  /**
   * 复制Item 值，避免外部修改内部状态。
   * @param item 项目记录。
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
   * 复制Package 值，避免外部修改内部状态。
   * @param record 记录副本。
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
   * 复制Metadata 值，避免外部修改内部状态。
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
   * 解析ItemCounter，非法输入会返回失败标记或空结果。
   * @param itemId 目标内容项标识。
   */
  private parseItemCounter(itemId: string): number {
    if (!itemId.startsWith('content-')) {
      return 0;
    }
    const parsed = Number(itemId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 解析PackageCounter，非法输入会返回失败标记或空结果。
   * @param packageId 目标内容包标识。
   */
  private parsePackageCounter(packageId: string): number {
    if (!packageId.startsWith('pkg-')) {
      return 0;
    }
    const parsed = Number(packageId.substring(4));
    return parsed > 0 ? parsed : 0;
  }
}
