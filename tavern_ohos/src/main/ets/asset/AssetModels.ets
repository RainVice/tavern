/**
 * 描述调用资源文件能力时需要传入的参数。
 */
export interface AssetCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * type 值，由当前实例内部维护。
   */
  type: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 描述资源文件持久化或内存索引中的一条记录。
 */
export interface AssetRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * type 值，由当前实例内部维护。
   */
  type: string;
  /**
   * file 名称。
   */
  fileName: string;
  /**
   * mime Type 值，由当前实例内部维护。
   */
  mimeType: string;
  /**
   * 路径。
   */
  path: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述资源文件事件发布时携带的数据结构。
 */
export interface AssetImportedPayload {
  /**
   * asset 值，由当前实例内部维护。
   */
  asset: AssetRecord;
}

/**
 * 描述资源文件事件发布时携带的数据结构。
 */
export interface AssetRenamedPayload {
  /**
   * asset 标识。
   */
  assetId: string;
  /**
   * old 路径。
   */
  oldPath: string;
  /**
   * asset 值，由当前实例内部维护。
   */
  asset: AssetRecord;
}

/**
 * 描述资源文件事件发布时携带的数据结构。
 */
export interface AssetDeletedPayload {
  /**
   * asset 标识。
   */
  assetId: string;
  /**
   * type 值，由当前实例内部维护。
   */
  type: string;
  /**
   * 路径。
   */
  path: string;
}

/**
 * 描述资源文件模块在运行时交换的数据结构。
 */
export interface AssetIndexData {
  /**
   * assets 列表，由当前实例内部维护。
   */
  assets: Array<AssetRecord>;
}
