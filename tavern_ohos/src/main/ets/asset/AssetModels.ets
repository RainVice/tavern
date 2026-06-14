import type { AssetType } from '../contracts/PublicContracts';

/**
 * 导入资源文件（头像、背景、音频等）时由调用方传入的创建参数。
 * AssetRuntime.importAsset 接收此参数，将其转换为持久化的 AssetRecord。
 */
export interface AssetCreateParams {
  /**
   * 资源唯一标识，用于去重——相同 id 的导入操作会合并为更新，保留首次 createdAt。
   */
  id: string;
  /**
   * 资源类型（image / background / theme / thumbnail / audio），决定文件存放的子目录。
   */
  type: AssetType;
  /**
   * 经过安全过滤后的文件名，不含路径分隔符。
   */
  fileName: string;
  /**
   * 资源的 MIME 类型，供消费方识别格式（如 image/png、audio/mpeg）。
   */
  mimeType: string;
  /**
   * 资源的原始内容数据（base64 编码的字符串或文本内容）。
   */
  content: string;
  /**
   * 业务元数据，以 JSON 字符串形式存储，由消费方自行解释（如缩略图尺寸、音频时长等）。
   */
  metadataJson: string;
}

/**
 * 持久化存储或内存索引中一条资源文件的完整记录。
 * AssetRuntime 的 records Map 基于此结构维护状态；
 * index.json 快照也以 AssetRecord[] 格式序列化。
 */
export interface AssetRecord {
  /**
   * 数据结构的版本号，用于未来向后兼容的迁移判断。
   */
  schemaVersion: number;
  /**
   * 资源唯一标识。
   */
  id: string;
  /**
   * 资源类型（image / background / theme / thumbnail / audio），决定了文件存放子目录。
   */
  type: AssetType;
  /**
   * 经过安全过滤后的文件名。
   */
  fileName: string;
  /**
   * MIME 类型，供消费方识别格式。
   */
  mimeType: string;
  /**
   * 文件在文件存储中的完整相对路径，由 rootPath + type 子目录 + fileName 拼接而成。
   */
  path: string;
  /**
   * 资源的文本内容（文本类资源直接存储；二进制资源的 base64 编码存储于此）。
   */
  content: string;
  /**
   * 业务元数据 JSON 字符串，由消费方自行解释。
   */
  metadataJson: string;
  /**
   * 资源记录的创建时间戳（毫秒），首次导入时写入，后续更新不改变此值。
   */
  createdAt: number;
  /**
   * 最近一次修改的时间戳（毫秒），每次 importAsset / renameAsset 都会更新。
   */
  updatedAt: number;
}

/**
 * 资源文件导入完成后，通过 EventBus 发布的事件负载。
 * 消费方（如 UI 刷新、索引更新）监听 'asset.imported' 事件时收到此数据。
 */
export interface AssetImportedPayload {
  /**
   * 导入完成后的完整资源记录（副本），包含生成的 id、path 和 createdAt 等字段。
   */
  asset: AssetRecord;
}

/**
 * 资源文件重命名完成后，通过 EventBus 发布的事件负载。
 * 消费方（如画廊 UI、文件索引）监听 'asset.renamed' 事件时收到此数据，
 * 可据此更新界面中显示的路径和文件名。
 */
export interface AssetRenamedPayload {
  /**
   * 被重命名的资源唯一标识。
   */
  assetId: string;
  /**
   * 重命名前的完整相对路径，供消费方定位并清理旧的引用。
   */
  oldPath: string;
  /**
   * 重命名后的完整资源记录（副本），包含新的 fileName 和 path。
   */
  asset: AssetRecord;
}

/**
 * 资源文件删除完成后，通过 EventBus 发布的事件负载。
 * 消费方监听 'asset.deleted' 事件时收到此数据，可据此更新引用计数或移除缓存的界面元素。
 */
export interface AssetDeletedPayload {
  /**
   * 被删除的资源唯一标识。
   */
  assetId: string;
  /**
   * 被删除资源的类型（image / background / theme / thumbnail / audio）。
   */
  type: AssetType;
  /**
   * 被删除文件在存储中的完整路径，供消费方确认清理了哪个文件。
   */
  path: string;
}

/**
 * 资源索引持久化时写入 index.json 的顶层数据结构。
 * AssetRuntime.persistIndex() 在每次 importAsset / renameAsset / deleteAsset 后
 * 重新生成此数据并写回存储，供下次启动时重建 records Map。
 */
export interface AssetIndexData {
  /**
   * 当前所有资源记录的完整列表，按 id 字典序排列。
   */
  assets: Array<AssetRecord>;
}
