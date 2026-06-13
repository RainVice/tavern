// 内容类型
export type ContentType = 'extension' | 'asset' | 'character' | 'background' | 'theme';
// 内容来源
export type ContentSource = 'url' | 'file' | 'github' | 'marketplace';
// 安装状态
export type InstallStatus = 'pending' | 'downloading' | 'installing' | 'installed' | 'failed';

// 内容条目
export interface ContentItem {
  itemId: string;
  contentType: ContentType;
  source: ContentSource;
  sourceUrl: string;
  displayName: string;
  version: string;
  status: InstallStatus;
  installPath: string;
  size: number;
  metadata: Record<string, string>;
  error: string;
  createdAt: number;
  updatedAt: number;
}

// 包管理条目
export interface PackageRecord {
  packageId: string;
  contentType: ContentType;
  displayName: string;
  version: string;
  author: string;
  description: string;
  installPath: string;
  enabled: boolean;
  dependencies: Array<string>;
  createdAt: number;
  updatedAt: number;
}

// 事件
export interface ContentDownloadStartedPayload { item: ContentItem; }
export interface ContentDownloadProgressPayload { item: ContentItem; progress: number; }
export interface ContentInstalledPayload { item: ContentItem; }
export interface ContentInstallFailedPayload { item: ContentItem; }
export interface ContentRemovedPayload { itemId: string; }
export interface ContentExportData { items: Array<ContentItem>; packages: Array<PackageRecord>; }
