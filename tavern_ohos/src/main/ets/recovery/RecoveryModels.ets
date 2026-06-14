/**
 * 限定恢复快照模块可接受的字符串取值范围。
 */
export type RecoveryType = 'user_password' | 'data_corruption' | 'session_restore';
/**
 * 描述恢复快照模块在运行时交换的数据结构。
 */
export interface RecoveryMetadata {
  /**
   * 来源标识，用于记录快照的创建来源（如模块名称或调用方），便于恢复时溯源。
   */
  source?: string;
  /**
   * 聊天标识，记录了当快照创建时的对话上下文，恢复时用于定位。
   */
  chatId?: string;
  /**
   * 消息标识，记录了当快照创建时的具体消息位置，恢复时用于定位。
   */
  messageId?: string;
  /**
   * 原因，描述快照创建的原因或触发条件，用于恢复时判断是否匹配。
   */
  reason?: string;
}
/**
 * 描述恢复快照模块在运行时交换的数据结构。
 */
export interface RecoverySnapshot {
  /**
   * 类型，标识快照的恢复场景类别（密码变更、数据损坏、会话恢复）。
   */
  type: RecoveryType;
  /**
   * 元数据，携带快照的额外上下文信息（来源、聊天、消息、原因），用于恢复决策。
   */
  metadata: RecoveryMetadata;
  /**
   * 时间戳（毫秒），记录快照创建时刻，用于排序和判断快照的新旧程度。
   */
  timestamp: number;
}
/**
 * 描述恢复快照操作完成后返回给调用方的结果。
 */
export interface RecoveryResult {
  /**
   * 成功状态，true 表示找到并应用了可恢复的快照，false 表示无匹配快照。
   */
  success: boolean;
  /**
   * 类型，与尝试恢复的请求类型对应，标识恢复场景类别。
   */
  type: RecoveryType;
  /**
   * 消息文本，携带恢复操作的人类可读描述（成功或失败原因）。
   */
  message: string;
}
/**
 * 描述恢复快照事件发布时携带的数据结构。
 */
export interface RecoveryAttemptedPayload {
  /**
   * 处理结果，用于通知监听方恢复操作已完成并携带结果详情。
   */
  result: RecoveryResult;
}
