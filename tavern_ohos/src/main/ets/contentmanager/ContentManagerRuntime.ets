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
 * 调用方通常是安装流程控制器或 UI ViewModel，通过本类驱动内容从下载到安装完成的完整生命周期。
 */
export class ContentManagerRuntime {
  /** 用于发布内容生命周期事件的事件总线，让订阅方（如 UI 或外部模块）感知安装进度和状态变化。 */
  private events: EventBus;
  /** 按 itemId 索引的内容条目集合，运行时核心状态，所有内容查找和操作基于此 Map。 */
  private items: Map<string, ContentItem> = new Map<string, ContentItem>();
  /** 按 packageId 索引的包记录集合，管理已注册内容包的元信息。 */
  private packages: Map<string, PackageRecord> = new Map<string, PackageRecord>();
  /** 自增计数器，用于生成内容条目唯一标识（格式 "content-{数字}"）。 */
  private itemCounter: number = 0;
  /** 自增计数器，用于生成包记录唯一标识（格式 "pkg-{数字}"）。 */
  private packageCounter: number = 0;

  /**
   * 初始化当前运行时实例。通常在应用启动或内容管理器模块初始化时调用。
   * @param events 用于发布内容生命周期事件的事件总线实例，需由调用方在构造时注入。
   */
  constructor(events: EventBus) { this.events = events; }

  /**
   * 按内容类型筛选并返回所有内容条目的深拷贝列表。供 UI 列表展示或外部按类型导出时调用。
   * @param contentType 可选，指定后只返回该类型的内容条目；不传时返回全部条目。
   * @returns 内容条目列表的副本，调用方修改返回值不会影响内部状态。
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
   * 按安装状态筛选并返回所有内容条目的深拷贝列表。供 UI 按状态分组展示、或清理流程中查找特定状态条目时调用。
   * @param status 要匹配的安装状态（如 pending / downloading / installed）。
   * @returns 符合状态条件的内容条目列表副本。
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
   * 创建一个新的内容条目并注册到内部索引中，初始状态为 pending。
   * 由安装流程发起方调用，作为内容安装的起始点。
   * @param contentType 内容的类型（扩展/资源/角色等），决定安装策略和目标目录。
   * @param source 内容的来源方式（URL/文件/GitHub/市场），影响后续下载或导入流程的选择。
   * @param sourceUrl 来源的具体地址，如下载链接或文件路径，供后续数据获取使用。
   * @param displayName 给用户展示的名称，显示在 UI 安装列表和通知中。
   * @returns 新建内容条目的深拷贝，调用方可使用返回的 itemId 进行后续进度更新和状态变更。
   */
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

  /**
   * 更新指定内容的下载进度，并将进度事件发布到事件总线。
   * 由下载流程（如 URL 下载器或流式读取器）在收到数据块时周期调用。
   * @param itemId 要更新进度的内容条目标识，必须是已通过 installContent 创建的条目。
   * @param progress 下载进度百分比（0-100），调用方应根据已接收数据量计算。
   * @returns 更新后的内容条目深拷贝，状态为 'downloading'。
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
   * 标记指定内容为安装完成，记录安装路径和版本，并发布安装完成事件。
   * 由安装流程在内容数据已写入文件系统后调用，通知订阅方安装成功。
   * @param itemId 已安装的内容条目标识，必须是状态为 downloading 或 installing 的条目。
   * @param installPath 内容在文件系统中的安装路径，供后续文件访问使用。
   * @param version 安装的内容版本号，覆写条目原有的空版本。
   * @returns 更新后的内容条目深拷贝，状态变为 'installed'。
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
   * 标记指定内容为安装失败，记录错误信息并发布失败事件。
   * 由安装流程在下载或安装过程发生不可恢复错误时调用，供 UI 显示失败提示。
   * @param itemId 安装失败的内容条目标识。
   * @param error 失败原因描述，将写入条目 error 字段供后续分析和重试决策。
   * @returns 更新后的内容条目深拷贝，状态变为 'failed'。
   */
  failInstall(itemId: string, error: string): ContentItem {
    const item = this.requireItem(itemId);
    item.status = 'failed'; item.error = error; item.updatedAt = Date.now();
    const payload: ContentInstallFailedPayload = { item: this.copyItem(item) };
    this.events.publish<ContentInstallFailedPayload>('content.install.failed', payload);
    return this.copyItem(item);
  }

  /**
   * 从索引中移除指定内容条目，并发布移除事件。由清理流程或用户手动删除操作触发。
   * @param itemId 要移除的内容条目标识，移除后无法通过 getItem 或 listContent 获取。
   */
  removeContent(itemId: string): void {
    this.requireItem(itemId);
    this.items.delete(itemId);
    this.events.publish<ContentRemovedPayload>('content.removed', { itemId: itemId });
  }

  /**
   * 根据标识获取内容条目的深拷贝。供外部模块按 itemId 精确读取条目详情时调用。
   * @param itemId 目标内容条目标识。
   * @returns 内容条目的深拷贝，不存在时抛出异常。
   */
  getItem(itemId: string): ContentItem { return this.copyItem(this.requireItem(itemId)); }

  /**
   * 注册一个新的内容包记录，包含版本、作者和安装路径等元信息。
   * 在内容安装完成并注册到系统时调用，建立持久化的包管理记录。
   * @param displayName 包的展示名称，在 UI 管理界面中显示。
   * @param contentType 包的内容类型，用于按类别筛选包列表。
   * @param version 包版本号，用于版本管理和更新检测。
   * @param author 包作者，记录归属信息。
   * @param installPath 包在文件系统中的安装路径，必须是有效且可访问的路径。
   * @returns 新建包记录的深拷贝，调用方可使用返回的 packageId 进行后续状态控制。
   */
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

  /**
   * 按内容类型筛选并返回所有已注册包记录的深拷贝列表。供 UI 管理界面或按类型导出时调用。
   * @param contentType 可选，指定后只返回该类型的包记录；不传时返回全部包记录。
   * @returns 包记录列表的副本。
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
   * 设置指定内容包的启用/禁用状态。供 UI 管理界面的启用开关调用，影响该包功能是否生效。
   * @param packageId 目标内容包标识。
   * @param enabled 设为 true 启用，false 禁用。
   * @returns 更新后的包记录深拷贝。
   */
  setPackageEnabled(packageId: string, enabled: boolean): PackageRecord {
    const record = this.requirePackage(packageId);
    record.enabled = enabled; record.updatedAt = Date.now();
    return this.copyPackage(record);
  }

  /**
   * 从索引中移除指定包记录。由包卸载或清理流程触发，移除后无法通过 listPackages 获取。
   * @param packageId 要移除的包标识。
   */
  removePackage(packageId: string): void {
    this.requirePackage(packageId);
    this.packages.delete(packageId);
  }

  /**
   * 导出全部内容条目和包记录，用于备份或迁移，生成当前运行时的完整快照。
   * 供备份/恢复流程或数据迁移工具在保存状态时调用。
   * @returns 包含所有 items 和 packages 的导出数据结构。
   */
  exportData(): ContentExportData {
    return { items: this.listContent(), packages: this.listPackages() };
  }

  /**
   * 从外部数据导入内容条目和包记录，覆盖或追加到当前运行时状态。
   * 供备份恢复或数据迁移流程在加载先前保存的状态时调用。
   * @param data 包含 items 和 packages 的导入数据，通常来自之前 exportData 的输出。
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
   * 根据标识获取内容条目，不存在时抛出异常。供内部方法在操作条目前做存在性校验。
   * @param itemId 目标内容条目标识。
   * @returns 找到的内容条目引用。
   */
  private requireItem(itemId: string): ContentItem {
    const item = this.items.get(itemId);
    if (item === undefined) { throw new Error(`内容条目未找到: ${itemId}`); }
    return item;
  }

  /**
   * 根据标识获取包记录，不存在时抛出异常。供内部方法在操作包前做存在性校验。
   * @param packageId 目标包标识。
   * @returns 找到的包记录引用。
   */
  private requirePackage(packageId: string): PackageRecord {
    const record = this.packages.get(packageId);
    if (record === undefined) { throw new Error(`包未找到: ${packageId}`); }
    return record;
  }

  /**
   * 深拷贝内容条目，防止外部修改内部状态。所有对外返回 ContentItem 的方法均通过此方法生成副本。
   * @param item 要拷贝的内容条目。
   * @returns 内容条目的深拷贝。
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
   * 深拷贝包记录，防止外部修改内部状态。所有对外返回 PackageRecord 的方法均通过此方法生成副本。
   * @param record 要拷贝的包记录。
   * @returns 包记录的深拷贝。
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
   * 深拷贝元数据字典，防止外部修改内部状态。被 copyItem 在构建条目深拷贝时调用。
   * @param metadata 原始元数据字典。
   * @returns 键值对的深拷贝。
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
   * 从内容条目 ID 中解析出自增计数数值，用于 importData 时同步计数器避免 ID 冲突。
   * @param itemId 格式为 "content-{数字}" 的条目标识。
   * @returns 解析出的计数值，解析失败返回 0。
   */
  private parseItemCounter(itemId: string): number {
    if (!itemId.startsWith('content-')) {
      return 0;
    }
    const parsed = Number(itemId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 从包记录 ID 中解析出自增计数数值，用于 importData 时同步计数器避免 ID 冲突。
   * @param packageId 格式为 "pkg-{数字}" 的包标识。
   * @returns 解析出的计数值，解析失败返回 0。
   */
  private parsePackageCounter(packageId: string): number {
    if (!packageId.startsWith('pkg-')) {
      return 0;
    }
    const parsed = Number(packageId.substring(4));
    return parsed > 0 ? parsed : 0;
  }
}
