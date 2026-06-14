/**
 * 内容类型枚举值。
 */
export type ContentType = 'extension' | 'asset' | 'character' | 'background' | 'theme';
/**
 * 内容来源类型枚举值。
 */
export type ContentSource = 'url' | 'file' | 'github' | 'marketplace';
/**
 * 安装状态枚举值。
 */
export type InstallStatus = 'pending' | 'downloading' | 'installing' | 'installed' | 'failed';

/**
 * 内容条目数据结构，描述单个内容项的全部属性。
 */
export interface ContentItem {
  /**
   * item 标识。
   */
  itemId: string;
  /**
   * 内容类型（如 extension/asset/character 等），标记该条目属于哪种内容品类。
   */
  contentType: ContentType;
  /**
   * 内容的来源类型（url/file/github/marketplace），决定安装和更新策略。
   */
  source: ContentSource;
  /**
   * 来源的 URL 地址，供下载模块读取内容数据。
   */
  sourceUrl: string;
  /**
   * display 名称。
   */
  displayName: string;
  /**
   * 内容条目的版本号，用于版本比较和更新判断。
   */
  version: string;
  /**
   * 安装状态（pending/downloading/installing/installed/failed）。
   */
  status: InstallStatus;
  /**
   * install 路径。
   */
  installPath: string;
  /**
   * 内容条目的大小（字节），用于进度计算和空间检查。
   */
  size: number;
  /**
   * 附加的元数据键值对，存储与内容类型相关的额外属性。
   */
  metadata: Record<string, string>;
  /**
   * 安装失败时记录的错误信息，成功时为空字符串。
   */
  error: string;
  /**
   * 条目的创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 条目的最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 内容包记录数据结构，描述一个内容包的全部属性。
 */
export interface PackageRecord {
  /**
   * package 标识。
   */
  packageId: string;
  /**
   * 内容包的类型（extension/asset/character/background/theme）。
   */
  contentType: ContentType;
  /**
   * display 名称。
   */
  displayName: string;
  /**
   * 内容包的版本号，用于版本管理和更新检查。
   */
  version: string;
  /**
   * 内容包作者的信息或名称。
   */
  author: string;
  /**
   * 内容包的描述文本，提供功能说明。
   */
  description: string;
  /**
   * install 路径。
   */
  installPath: string;
  /**
   * 内容包是否已启用，未启用时不影响应用运行。
   */
  enabled: boolean;
  /**
   * 内容包所依赖的其他包标识列表，安装时先行处理。
   */
  dependencies: Array<string>;
  /**
   * 内容包的创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 内容包的最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 内容下载开始事件发布时携带的数据结构。
 */
export interface ContentDownloadStartedPayload {
  /**
   * 内容项。
   */
  item: ContentItem;
}
/**
 * 内容下载进度事件发布时携带的数据结构。
 */
export interface ContentDownloadProgressPayload {
  /**
   * 内容项。
   */
  item: ContentItem;
  /**
   * 进度值。
   */
  progress: number;
}
/**
 * 内容安装完成事件发布时携带的数据结构。
 */
export interface ContentInstalledPayload {
  /**
   * 内容项。
   */
  item: ContentItem;
}
/**
 * 内容安装失败事件发布时携带的数据结构。
 */
export interface ContentInstallFailedPayload {
  /**
   * 内容项。
   */
  item: ContentItem;
}
/**
 * 内容移除事件发布时携带的数据结构。
 */
export interface ContentRemovedPayload {
  /**
   * 内容项标识。
   */
  itemId: string;
}
/**
 * 内容管理器导出数据结构，包含所有内容项和包信息。
 */
export interface ContentExportData {
  /**
   * 内容项列表。
   */
  items: Array<ContentItem>;
  /**
   * 包列表。
   */
  packages: Array<PackageRecord>;
}
