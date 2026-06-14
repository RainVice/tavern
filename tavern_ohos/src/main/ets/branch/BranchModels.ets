/**
 * 描述调用聊天分支能力时需要传入的参数，用于创建新分支时的必要信息。
 */
export interface BranchCreateParams {
  /**
   * 分支的唯一标识，用于在内存索引和事件载荷中识别该分支。
   */
  id: string;
  /**
   * 父聊天的唯一标识，表示该分支从哪个聊天分叉出来。
   */
  parentChatId: string;
  /**
   * 锚点消息的唯一标识，表示分支从该消息处开始分叉。
   */
  anchorMessageId: string;
  /**
   * 子聊天的唯一标识，表示该分支指向的具体聊天会话。
   */
  childChatId: string;
  /**
   * 分支标题，用于在 UI 中展示分支的名称或摘要。
   */
  title: string;
}

/**
 * 描述聊天分支持久化或内存索引中的一条记录，用于管理聊天历史的分支结构。
 */
export interface BranchRecord {
  /**
   * 分支的唯一标识。
   */
  id: string;
  /**
   * 父聊天的唯一标识，用于追溯分支的来源聊天。
   */
  parentChatId: string;
  /**
   * 锚点消息的唯一标识，用于定位分支从哪条消息开始分叉。
   */
  anchorMessageId: string;
  /**
   * 子聊天的唯一标识，用于关联分支对应的具体聊天会话。
   */
  childChatId: string;
  /**
   * 分支标题，用于在 UI 中展示分支的标识信息。
   */
  title: string;
  /**
   * 是否为当前激活的分支，用于在多个分支间标记当前使用的分支。
   */
  active: boolean;
  /**
   * 分支创建时间的时间戳（毫秒），用于排序和记录创建历史。
   */
  createdAt: number;
  /**
   * 分支最近更新时间的时间戳（毫秒），用于检测分支状态变更。
   */
  updatedAt: number;
}

/**
 * 描述调用聊天分支能力时需要传入的参数，用于在指定分支下创建检查点。
 */
export interface CheckpointCreateParams {
  /**
   * 检查点的唯一标识，用于在内存索引中定位该检查点。
   */
  id: string;
  /**
   * 检查点所属的分支标识，用于关联检查点到具体分支。
   */
  branchId: string;
  /**
   * 锚点消息的唯一标识，表示检查点从哪条消息开始捕获状态。
   */
  anchorMessageId: string;
  /**
   * 检查点的显示标签，用于在 UI 中标识检查点。
   */
  label: string;
  /**
   * 检查点快照的引用标识，用于在快照存储中定位对应的消息快照数据。
   */
  snapshotRef: string;
}

/**
 * 描述聊天分支持久化或内存索引中的一条记录，用于管理分支内的检查点信息。
 */
export interface CheckpointRecord {
  /**
   * 检查点的唯一标识。
   */
  id: string;
  /**
   * 检查点所属的分支标识，用于关联检查点到具体分支。
   */
  branchId: string;
  /**
   * 锚点消息的唯一标识，标记检查点捕获时的消息位置。
   */
  anchorMessageId: string;
  /**
   * 检查点的显示标签，用于在 UI 中标识检查点。
   */
  label: string;
  /**
   * 检查点快照的引用标识，用于在快照存储中定位对应的消息快照数据。
   */
  snapshotRef: string;
  /**
   * 检查点创建时间的时间戳（毫秒），用于排序和记录创建历史。
   */
  createdAt: number;
}

/**
 * 分支导出数据，包含分支记录及其关联的所有检查点，用于备份、迁移或与外部工具数据互通。
 */
export interface BranchExportData {
  /**
   * 要导出的分支记录，包含分支元数据和状态。
   */
  branch: BranchRecord;
  /**
   * 该分支下的所有检查点记录，用于完整恢复分支的快照历史。
   */
  checkpoints: Array<CheckpointRecord>;
}

/**
 * 分支相关事件（创建、恢复）发布时携带的数据结构，用于通知其他模块分支状态已变更。
 */
export interface BranchEventPayload {
  /**
   * 事件关联的分支记录，供事件订阅者获取分支最新状态。
   */
  branch: BranchRecord;
}

/**
 * 分支激活事件发布时携带的数据结构，用于通知其他模块当前激活的分支已切换。
 */
export interface BranchActivatedPayload {
  /**
   * 被激活的分支记录，供事件订阅者获取激活分支的完整信息。
   */
  branch: BranchRecord;
}

/**
 * 检查点创建事件发布时携带的数据结构，用于通知其他模块新的检查点已创建。
 */
export interface CheckpointEventPayload {
  /**
   * 创建的检查点记录，供事件订阅者获取检查点详情。
   */
  checkpoint: CheckpointRecord;
}
