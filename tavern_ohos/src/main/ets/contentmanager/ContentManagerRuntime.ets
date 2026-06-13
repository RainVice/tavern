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

export class ContentManagerRuntime {
  private events: EventBus;
  private items: Map<string, ContentItem> = new Map<string, ContentItem>();
  private packages: Map<string, PackageRecord> = new Map<string, PackageRecord>();
  private itemCounter: number = 0;
  private packageCounter: number = 0;

  constructor(events: EventBus) { this.events = events; }

  // 列出现有内容
  listContent(contentType?: ContentType): Array<ContentItem> {
    const result = new Array<ContentItem>();
    const values = Array.from(this.items.values());
    for (let index = 0; index < values.length; index += 1) {
      if (contentType === undefined || values[index].contentType === contentType) { result.push(this.copyItem(values[index])); }
    }
    return result;
  }

  // 按状态过滤
  listByStatus(status: InstallStatus): Array<ContentItem> {
    const result = new Array<ContentItem>();
    const values = Array.from(this.items.values());
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].status === status) { result.push(this.copyItem(values[index])); }
    }
    return result;
  }

  // 发起下载安装
  installContent(contentType: ContentType, source: ContentSource, sourceUrl: string, displayName: string): ContentItem {
    this.itemCounter += 1;
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

  // 更新下载进度
  updateProgress(itemId: string, progress: number): ContentItem {
    const item = this.requireItem(itemId);
    item.status = 'downloading'; item.updatedAt = Date.now();
    const normalizedProgress = Math.max(0, Math.min(100, progress));
    const payload: ContentDownloadProgressPayload = { item: this.copyItem(item), progress: normalizedProgress };
    this.events.publish<ContentDownloadProgressPayload>('content.download.progress', payload);
    return this.copyItem(item);
  }

  // 完成安装
  completeInstall(itemId: string, installPath: string, version: string): ContentItem {
    const item = this.requireItem(itemId);
    item.status = 'installed'; item.installPath = installPath; item.version = version;
    item.updatedAt = Date.now();
    const payload: ContentInstalledPayload = { item: this.copyItem(item) };
    this.events.publish<ContentInstalledPayload>('content.installed', payload);
    return this.copyItem(item);
  }

  // 安装失败
  failInstall(itemId: string, error: string): ContentItem {
    const item = this.requireItem(itemId);
    item.status = 'failed'; item.error = error; item.updatedAt = Date.now();
    const payload: ContentInstallFailedPayload = { item: this.copyItem(item) };
    this.events.publish<ContentInstallFailedPayload>('content.install.failed', payload);
    return this.copyItem(item);
  }

  // 移除内容
  removeContent(itemId: string): void {
    this.requireItem(itemId);
    this.items.delete(itemId);
    this.events.publish<ContentRemovedPayload>('content.removed', { itemId: itemId });
  }

  // 获取条目
  getItem(itemId: string): ContentItem { return this.copyItem(this.requireItem(itemId)); }

  // 包管理：注册已安装的包
  registerPackage(displayName: string, contentType: ContentType, version: string, author: string, installPath: string): PackageRecord {
    this.packageCounter += 1;
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

  // 列出已安装的包
  listPackages(contentType?: ContentType): Array<PackageRecord> {
    const result = new Array<PackageRecord>();
    const values = Array.from(this.packages.values());
    for (let index = 0; index < values.length; index += 1) {
      if (contentType === undefined || values[index].contentType === contentType) { result.push(this.copyPackage(values[index])); }
    }
    return result;
  }

  // 启用/禁用包
  setPackageEnabled(packageId: string, enabled: boolean): PackageRecord {
    const record = this.requirePackage(packageId);
    record.enabled = enabled; record.updatedAt = Date.now();
    return this.copyPackage(record);
  }

  // 移除包
  removePackage(packageId: string): void {
    this.requirePackage(packageId);
    this.packages.delete(packageId);
  }

  // 导出
  exportData(): ContentExportData {
    return { items: this.listContent(), packages: this.listPackages() };
  }

  // 导入
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

  private requireItem(itemId: string): ContentItem {
    const item = this.items.get(itemId);
    if (item === undefined) { throw new Error(`内容条目未找到: ${itemId}`); }
    return item;
  }

  private requirePackage(packageId: string): PackageRecord {
    const record = this.packages.get(packageId);
    if (record === undefined) { throw new Error(`包未找到: ${packageId}`); }
    return record;
  }

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

  private copyMetadata(metadata: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {};
    const keys = Object.keys(metadata);
    for (let index = 0; index < keys.length; index += 1) {
      result[keys[index]] = metadata[keys[index]];
    }
    return result;
  }

  private parseItemCounter(itemId: string): number {
    if (!itemId.startsWith('content-')) {
      return 0;
    }
    const parsed = Number(itemId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  private parsePackageCounter(packageId: string): number {
    if (!packageId.startsWith('pkg-')) {
      return 0;
    }
    const parsed = Number(packageId.substring(4));
    return parsed > 0 ? parsed : 0;
  }
}
