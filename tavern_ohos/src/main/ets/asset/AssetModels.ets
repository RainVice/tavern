/**
 * 描述调用资源文件能力时需要传入的参数，用于在导入资源流程中指定资源的元信息和内容。
 */
export interface AssetCreateParams {
  /**
   * 资源唯一标识，用于在资源管理流程中全局索引和引用该资源。
   */
  id: string;
  /**
   * 资源类型（如 image、background、theme），用于在导入流程中决定存储目录分类和后续查询筛选。
   */
  type: string;
  /**
   * 文件名称，用于在导入流程中生成磁盘存储路径，经过安全检查后使用。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型（如 image/png），用于在存储和读取流程中标识文件格式。
   */
  mimeType: string;
  /**
   * 文件内容（base64 编码或原始数据），在导入流程中直接写入磁盘供后续读取使用。
   */
  content: string;
  /**
   * 资源的元数据 JSON 字符串，用于在存储流程中附带附加信息供查询时使用。
   */
  metadataJson: string;
}

/**
 * 描述资源文件持久化或内存索引中的一条记录，用于在资源管理各流程（导入、查询、重命名、删除）中代表一个资源项。
 */
export interface AssetRecord {
  /**
   * 记录结构的 schema 版本号，用于在索引恢复流程中判断旧版本数据是否需要迁移升级。
   */
  schemaVersion: number;
  /**
   * 资源唯一标识，用于在资源管理流程中全局索引和引用。
   */
  id: string;
  /**
   * 资源类型（如 image、background、theme），用于在按类型筛选资源的查询流程中过滤记录。
   */
  type: string;
  /**
   * 文件名称，用于显示和路径构建，在导入和重命名流程中经过安全检查后使用。
   */
  fileName: string;
  /**
   * 文件的 MIME 类型，用于在读取资源时标识文件格式。
   */
  mimeType: string;
  /**
   * 文件在存储中的路径，在导入流程中生成并在重命名流程中更新，用于磁盘读写定位。
   */
  path: string;
  /**
   * 文件内容，在导入流程中写入磁盘、在读取流程中返回给调用方。
   */
  content: string;
  /**
   * 资源的元数据 JSON 字符串，用于在存储和查询流程中附带额外信息。
   */
  metadataJson: string;
  /**
   * 记录创建时间戳（毫秒），用于追踪资源导入的起始时刻。
   */
  createdAt: number;
  /**
   * 记录最近更新时间戳（毫秒），用于追踪资源变更时机，辅助缓存刷新和数据同步。
   */
  updatedAt: number;
}

/**
 * 描述资源文件事件发布时携带的数据结构，在资源导入流程完成后由运行时发布，供 UI 或外部模块响应。
 */
export interface AssetImportedPayload {
  /**
   * 导入的资源记录，包含资源标识、类型、路径等完整信息，在导入事件中传递供监听方使用。
   */
  asset: AssetRecord;
}

/**
 * 描述资源文件事件发布时携带的数据结构，在资源重命名流程完成后由运行时发布，供 UI 或外部模块响应。
 */
export interface AssetRenamedPayload {
  /**
   * 被重命名的资源唯一标识，用于监听方定位变更的资源。
   */
  assetId: string;
  /**
   * 重命名前的原始路径，用于监听方还原或清理旧引用。
   */
  oldPath: string;
  /**
   * 重命名后的资源记录，包含更新后的文件名和路径，在事件中传递供监听方更新显示。
   */
  asset: AssetRecord;
}

/**
 * 描述资源文件事件发布时携带的数据结构，在资源删除流程完成后由运行时发布，供 UI 或外部模块响应。
 */
export interface AssetDeletedPayload {
  /**
   * 被删除的资源唯一标识，用于监听方定位和移除相关引用。
   */
  assetId: string;
  /**
   * 被删除资源的类型，用于监听方按类别统计或清理。
   */
  type: string;
  /**
   * 被删除资源文件的路径，用于监听方验证磁盘清理结果。
   */
  path: string;
}

/**
 * 描述资源文件模块的索引数据结构，用于将全部资源元信息持久化到磁盘，在应用启动时恢复资源列表。
 */
export interface AssetIndexData {
  /**
   * 索引中记录的所有资源列表，在索引持久化和恢复流程中使用。
   */
  assets: Array<AssetRecord>;
}
