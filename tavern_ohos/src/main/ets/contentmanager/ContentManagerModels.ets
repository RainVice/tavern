/**
 * 内容类型 —— 区分扩展、资源包、角色卡、背景图片和主题，用于内容管理器的分类安装和索引。
 */
export type ContentType = 'extension' | 'asset' | 'character' | 'background' | 'theme';
/**
 * 内容来源 —— 标识内容是从 URL 下载、本地文件导入、GitHub 拉取还是插件市场获取，影响安装流程的下载策略。
 */
export type ContentSource = 'url' | 'file' | 'github' | 'marketplace';
/**
 * 安装状态 —— 追踪内容从等待到完成或失败的完整生命周期，供内容管理器和 UI 进度显示使用。
 */
export type InstallStatus = 'pending' | 'downloading' | 'installing' | 'installed' | 'failed';

/**
 * 表示一个待安装或已安装的内容条目，贯穿下载、安装、完成或失败的完整内容生命周期。
 */
export interface ContentItem {
  /** 条目的唯一标识，由内容管理器在创建时自动生成（格式为 "content-{数字}"），用于索引和操作定位。 */
  itemId: string;
  /** 内容所属的类型（扩展/资源/角色等），用于按类别筛选列表和安装策略选择。 */
  contentType: ContentType;
  /** 内容的来源方式（URL/文件/GitHub/市场），决定下载或导入时的处理流程。 */
  source: ContentSource;
  /** 来源地址，例如下载链接或文件路径，用于获取内容数据。 */
  sourceUrl: string;
  /** 给用户展示的名称，在 UI 列表和安装通知中显示。 */
  displayName: string;
  /** 内容版本号，安装成功后由外部写入，用于版本管理和更新检测。 */
  version: string;
  /** 当前安装阶段状态（pending/downloading/installing/installed/failed），驱动 UI 进度显示。 */
  status: InstallStatus;
  /** 安装后内容在文件系统中的存放路径，由 completeInstall 方法设置。 */
  installPath: string;
  /** 内容包的大小（字节），用于下载进度估算和存储空间检查。 */
  size: number;
  /** 附加的元数据键值对，可存储来源特有的额外信息（如 GitHub 仓库地址、插件版本等）。 */
  metadata: Record<string, string>;
  /** 安装失败时的错误信息，由 failInstall 方法设置，供错误报告和重试决策使用。 */
  error: string;
  /** 条目创建时间戳（毫秒），由 installContent 在新建条目时写入。 */
  createdAt: number;
  /** 条目最近一次更新的时间戳（毫秒），状态变更和属性更新时同步刷新。 */
  updatedAt: number;
}

/**
 * 表示一个已注册的内容包，包含版本、作者和依赖关系等元信息，用于内容管理和启用/禁用控制。
 */
export interface PackageRecord {
  /** 包的唯一标识，由 registerPackage 自动生成（格式为 "pkg-{数字}"），用于索引和操作定位。 */
  packageId: string;
  /** 包的内容类型（扩展/资源/角色等），用于按类别筛选已注册包列表。 */
  contentType: ContentType;
  /** 包的展示名称，在 UI 管理界面中显示给用户。 */
  displayName: string;
  /** 包版本号，用于版本管理和更新检测。 */
  version: string;
  /** 包的作者，用于归属信息展示。 */
  author: string;
  /** 包的功能描述，供用户了解包的作用。 */
  description: string;
  /** 包在文件系统中的安装路径，由 registerPackage 设置，用于包数据的磁盘访问。 */
  installPath: string;
  /** 包是否已启用，通过 setPackageEnabled 控制，启用状态影响内容功能是否生效。 */
  enabled: boolean;
  /** 该包依赖的其他包标识列表，用于在启用/禁用时检查依赖完整性。 */
  dependencies: Array<string>;
  /** 记录创建时间戳（毫秒），由 registerPackage 写入。 */
  createdAt: number;
  /** 记录最近一次更新的时间戳（毫秒），状态或属性变更时同步刷新。 */
  updatedAt: number;
}

/**
 * 内容开始下载时发布的事件负载，由 ContentManagerRuntime 的下游调用方在开启下载流程时触发。
 */
export interface ContentDownloadStartedPayload {
  /** 正在下载的内容条目，包含来源地址和目标安装信息，供 UI 展示下载初始状态。 */
  item: ContentItem;
}
/**
 * 下载进度更新时发布的事件负载，由 updateProgress 方法在每轮进度变化时触发。
 */
export interface ContentDownloadProgressPayload {
  /** 正在下载的内容条目，包含最新状态信息。 */
  item: ContentItem;
  /** 下载进度百分比（0-100），供 UI 进度条实时反映下载进展。 */
  progress: number;
}
/**
 * 内容安装完成时发布的事件负载，由 completeInstall 方法在安装成功后触发。
 */
export interface ContentInstalledPayload {
  /** 已安装的内容条目，含最终的安装路径和版本信息，供订阅方执行后续处理（如刷新列表、通知用户）。 */
  item: ContentItem;
}
/**
 * 内容安装失败时发布的事件负载，由 failInstall 方法在安装过程中发生错误时触发。
 */
export interface ContentInstallFailedPayload {
  /** 安装失败的内容条目，包含错误详情，供订阅方执行错误处理和用户通知。 */
  item: ContentItem;
}
/**
 * 内容被移除时发布的事件负载，由 removeContent 方法从索引中清除条目时触发。
 */
export interface ContentRemovedPayload {
  /** 被移除的内容条目标识，供订阅方同步清理关联的 UI 视图或缓存数据。 */
  itemId: string;
}
/**
 * 内容管理器完整状态导出格式，用于备份或迁移，包含所有内容条目和包记录的快照。
 */
export interface ContentExportData {
  /** 所有内容条目列表，涵盖全部安装状态（包括已安装、下载中、失败等）。 */
  items: Array<ContentItem>;
  /** 所有已注册的包记录列表，包含启用和禁用状态的包。 */
  packages: Array<PackageRecord>;
}
