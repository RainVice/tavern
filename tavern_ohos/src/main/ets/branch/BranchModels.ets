/**
 * 描述调用聊天分支能力时需要传入的参数。
 */
export interface BranchCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 父级聊天会话的唯一标识。
   */
  parentChatId: string;
  /**
   * 锚定消息的唯一标识，表示分支产生的原始消息位置。
   */
  anchorMessageId: string;
  /**
   * 子级聊天会话的唯一标识。
   */
  childChatId: string;
  /**
   * 分支标题。
   */
  title: string;
}

/**
 * 描述聊天分支持久化或内存索引中的一条记录。
 */
export interface BranchRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 父级聊天会话的唯一标识。
   */
  parentChatId: string;
  /**
   * 锚定消息的唯一标识。
   */
  anchorMessageId: string;
  /**
   * 子级聊天会话的唯一标识。
   */
  childChatId: string;
  /**
   * 分支标题。
   */
  title: string;
  /**
   * 是否当前分支处于激活状态。
   */
  active: boolean;
  /**
   * 记录创建时间戳。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳。
   */
  updatedAt: number;
}

/**
 * 描述创建聊天检查点时需要传入的参数。
 */
export interface CheckpointCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 所属分支的唯一标识。
   */
  branchId: string;
  /**
   * 锚定消息的唯一标识。
   */
  anchorMessageId: string;
  /**
   * 标签。
   */
  label: string;
  /**
   * 快照引用标识。
   */
  snapshotRef: string;
}

/**
 * 描述聊天检查点持久化或内存索引中的一条记录。
 */
export interface CheckpointRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 所属分支的唯一标识。
   */
  branchId: string;
  /**
   * 锚定消息的唯一标识。
   */
  anchorMessageId: string;
  /**
   * 标签。
   */
  label: string;
  /**
   * 快照引用标识。
   */
  snapshotRef: string;
  /**
   * 记录创建时间戳。
   */
  createdAt: number;
}

/**
 * 描述分支模块导出数据的内容结构，包含分支及其关联的检查点列表。
 */
export interface BranchExportData {
  /**
   * 分支记录。
   */
  branch: BranchRecord;
  /**
   * 关联的检查点列表。
   */
  checkpoints: Array<CheckpointRecord>;
}

/**
 * 描述分支通用事件（创建、恢复等）发布时携带的数据。
 */
export interface BranchEventPayload {
  /**
   * 关联的分支记录。
   */
  branch: BranchRecord;
}

/**
 * 描述分支激活事件发布时携带的数据。
 */
export interface BranchActivatedPayload {
  /**
   * 关联的分支记录。
   */
  branch: BranchRecord;
}

/**
 * 描述检查点事件（创建等）发布时携带的数据。
 */
export interface CheckpointEventPayload {
  /**
   * 关联的检查点记录。
   */
  checkpoint: CheckpointRecord;
}
