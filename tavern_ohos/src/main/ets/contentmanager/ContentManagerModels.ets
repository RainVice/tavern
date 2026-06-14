// 内容类型
export type ContentType = 'extension' | 'asset' | 'character' | 'background' | 'theme';
// 内容来源
export type ContentSource = 'url' | 'file' | 'github' | 'marketplace';
// 安装状态
export type InstallStatus = 'pending' | 'downloading' | 'installing' | 'installed' | 'failed';

// 内容条目
export interface ContentItem {
  /**
   * item 标识。
   */
  itemId: string;
  /**
   * content Type 值，由当前实例内部维护。
   */
  contentType: ContentType;
  /**
   * 来源类型，由当前实例内部维护。
   */
  source: ContentSource;
  /**
   * source Url 值，由当前实例内部维护。
   */
  sourceUrl: string;
  /**
   * display 名称。
   */
  displayName: string;
  /**
   * version 值，由当前实例内部维护。
   */
  version: string;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: InstallStatus;
  /**
   * install 路径。
   */
  installPath: string;
  /**
   * size 值，由当前实例内部维护。
   */
  size: number;
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: Record<string, string>;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

// 包管理条目
export interface PackageRecord {
  /**
   * package 标识。
   */
  packageId: string;
  /**
   * content Type 值，由当前实例内部维护。
   */
  contentType: ContentType;
  /**
   * display 名称。
   */
  displayName: string;
  /**
   * version 值，由当前实例内部维护。
   */
  version: string;
  /**
   * author 值，由当前实例内部维护。
   */
  author: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * install 路径。
   */
  installPath: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * dependencies 列表，由当前实例内部维护。
   */
  dependencies: Array<string>;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

// 事件
export interface ContentDownloadStartedPayload {
  /**
   * 内容项。
   */
  item: ContentItem;
}
/**
 * 描述内容安装事件发布时携带的数据结构。
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
 * 描述内容安装事件发布时携带的数据结构。
 */
export interface ContentInstalledPayload {
  /**
   * 内容项。
   */
  item: ContentItem;
}
/**
 * 描述内容安装事件发布时携带的数据结构。
 */
export interface ContentInstallFailedPayload {
  /**
   * 内容项。
   */
  item: ContentItem;
}
/**
 * 描述内容安装事件发布时携带的数据结构。
 */
export interface ContentRemovedPayload {
  /**
   * 内容项标识。
   */
  itemId: string;
}
/**
 * 描述内容安装模块在运行时交换的数据结构。
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
