/**
 * 限定恢复快照模块可接受的字符串取值范围。
 */
export type RecoveryType = 'user_password' | 'data_corruption' | 'session_restore';
/**
 * 描述恢复快照模块在运行时交换的数据结构。
 */
export interface RecoveryMetadata {
  /**
   * 来源。
   */
  source?: string;
  /**
   * 聊天标识。
   */
  chatId?: string;
  /**
   * 消息标识。
   */
  messageId?: string;
  /**
   * 原因。
   */
  reason?: string;
}
/**
 * 描述恢复快照模块在运行时交换的数据结构。
 */
export interface RecoverySnapshot {
  /**
   * 类型。
   */
  type: RecoveryType;
  /**
   * 元数据。
   */
  metadata: RecoveryMetadata;
  /**
   * 时间戳。
   */
  timestamp: number;
}
/**
 * 描述恢复快照操作完成后返回给调用方的结果。
 */
export interface RecoveryResult {
  /**
   * 成功状态。
   */
  success: boolean;
  /**
   * 类型。
   */
  type: RecoveryType;
  /**
   * 消息文本。
   */
  message: string;
}
/**
 * 描述恢复快照事件发布时携带的数据结构。
 */
export interface RecoveryAttemptedPayload {
  /**
   * 处理结果。
   */
  result: RecoveryResult;
}
