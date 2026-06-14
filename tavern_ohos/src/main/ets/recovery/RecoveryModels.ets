/**
 * 恢复操作类型，限定快照可标识的故障场景。
 * - `user_password`：用户密码变更或遗忘导致的恢复。
 * - `data_corruption`：本地数据损坏后尝试重建。
 * - `session_restore`：会话中断后恢复上下文。
 */
export type RecoveryType = 'user_password' | 'data_corruption' | 'session_restore';
/**
 * 恢复快照的元数据，携带可选的上下文信息以追踪恢复原因和关联资源。
 */
export interface RecoveryMetadata {
  /**
   * 来源标识，如触发恢复的模块或用户操作名称。
   */
  source?: string;
  /**
   * 关联的会话唯一标识。
   */
  chatId?: string;
  /**
   * 关联的消息唯一标识。
   */
  messageId?: string;
  /**
   * 触发恢复的具体原因描述。
   */
  reason?: string;
}
/**
 * 恢复快照记录，保存某一时刻的系统状态快照，用于后续恢复决策。
 */
export interface RecoverySnapshot {
  /**
   * 恢复类型。
   */
  type: RecoveryType;
  /**
   * 上下文元数据。
   */
  metadata: RecoveryMetadata;
  /**
   * 快照创建时间戳（UNIX 毫秒）。
   */
  timestamp: number;
}
/**
 * 恢复操作的结果，通知调用方恢复是否成功及相关信息。
 */
export interface RecoveryResult {
  /**
   * 是否成功。
   */
  success: boolean;
  /**
   * 对应的恢复类型。
   */
  type: RecoveryType;
  /**
   * 结果描述文本。
   */
  message: string;
}
/**
 * 恢复尝试事件发布时携带的载荷。
 */
export interface RecoveryAttemptedPayload {
  /**
   * 处理结果。
   */
  result: RecoveryResult;
}
