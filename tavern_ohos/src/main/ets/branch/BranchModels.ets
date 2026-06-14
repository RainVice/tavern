/**
 * 描述调用聊天分支能力时需要传入的参数。
 */
export interface BranchCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * parent Chat 标识。
   */
  parentChatId: string;
  /**
   * anchor Message 标识。
   */
  anchorMessageId: string;
  /**
   * child Chat 标识。
   */
  childChatId: string;
  /**
   * 标题，由当前实例内部维护。
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
   * parent Chat 标识。
   */
  parentChatId: string;
  /**
   * anchor Message 标识。
   */
  anchorMessageId: string;
  /**
   * child Chat 标识。
   */
  childChatId: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * active 值，由当前实例内部维护。
   */
  active: boolean;
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
 * 描述调用聊天分支能力时需要传入的参数。
 */
export interface CheckpointCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * branch 标识。
   */
  branchId: string;
  /**
   * anchor Message 标识。
   */
  anchorMessageId: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * snapshot Ref 值，由当前实例内部维护。
   */
  snapshotRef: string;
}

/**
 * 描述聊天分支持久化或内存索引中的一条记录。
 */
export interface CheckpointRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * branch 标识。
   */
  branchId: string;
  /**
   * anchor Message 标识。
   */
  anchorMessageId: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * snapshot Ref 值，由当前实例内部维护。
   */
  snapshotRef: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
}

/**
 * 描述聊天分支模块在运行时交换的数据结构。
 */
export interface BranchExportData {
  /**
   * branch 值，由当前实例内部维护。
   */
  branch: BranchRecord;
  /**
   * checkpoints 列表，由当前实例内部维护。
   */
  checkpoints: Array<CheckpointRecord>;
}

/**
 * 描述聊天分支事件发布时携带的数据结构。
 */
export interface BranchEventPayload {
  /**
   * branch 值，由当前实例内部维护。
   */
  branch: BranchRecord;
}

/**
 * 描述聊天分支事件发布时携带的数据结构。
 */
export interface BranchActivatedPayload {
  /**
   * branch 值，由当前实例内部维护。
   */
  branch: BranchRecord;
}

/**
 * 描述聊天分支事件发布时携带的数据结构。
 */
export interface CheckpointEventPayload {
  /**
   * checkpoint 值，由当前实例内部维护。
   */
  checkpoint: CheckpointRecord;
}
