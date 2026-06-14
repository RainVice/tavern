/**
 * 限定表情状态模块可接受的字符串取值范围，
 * 用于在设置角色表情时限制 classification 参数只接受预定义的分类标签。
 */
export type ExpressionClassification = 'joy'|'sadness'|'anger'|'fear'|'surprise'|'disgust'|'neutral'|'love'|'custom';

/**
 * 描述表情状态模块在运行时交换的数据结构，
 * 用于存储和管理角色在当前会话/消息上下文中的表情快照信息。
 */
export interface ExpressionState {
  /**
   * 当前表情状态的唯一标识，格式为 'expr-{自增数字}'，
   * 由 ExpressionRuntime.setExpression 自动生成，用于在运行时中索引和查找表情记录。
   */
  expressionId: string; characterId: string; classification: ExpressionClassification;
  /**
   * 表情展示标签，用于 UI 层显示的角色当前表情名称，
   * 例如在聊天气泡上或角色立绘旁显示的表情描述文字。
   */
  label: string; spriteName: string; intensity: number; messageId: string;
  /**
   * 表情状态创建时间戳（毫秒），
   * 用于按时间排序和查找指定消息/时间点的角色表情历史。
   */
  createdAt: number; updatedAt: number;
}

/**
 * 描述表情状态事件发布时携带的数据结构，
 * 用于在角色表情发生变更时通过 EventBus 通知 UI 层或其他模块更新。
 */
export interface ExpressionChangedPayload {
  /**
   * 变更后的完整表情状态数据，
   * 供监听方在不查询运行时的情况下直接获取最新表情信息。
   */
  state: ExpressionState;
}

/**
 * 描述表情状态模块在运行时交换的数据结构，
 * 用于在备份、迁移或与 SillyTavern 数据互通时导出/导入全部表情数据。
 */
export interface ExpressionExportData {
  /**
   * 当前运行时中所有角色的全部表情状态列表，
   * 作为导出/导入操作的数据载体，包含完整的表情历史记录。
   */
  states: Array<ExpressionState>;
}
