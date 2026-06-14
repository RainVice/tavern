/**
 * 限定表情状态分类的可选字符串字面量类型。
 */
export type ExpressionClassification = 'joy'|'sadness'|'anger'|'fear'|'surprise'|'disgust'|'neutral'|'love'|'custom';
/**
 * 单个表情状态的完整数据结构，包含标识、角色归属、分类、标签、立绘、强度以及时间戳。
 */
export interface ExpressionState {
  /**
   * 全局唯一表达式标识，格式为 "expr-{自增序号}"。
   */
  expressionId: string; characterId: string; classification: ExpressionClassification;
  /**
   * 展示用标签，用于 UI 中识别当前表情状态。
   */
  label: string; spriteName: string; intensity: number; messageId: string;
  /**
   * 表情状态创建时的毫秒级时间戳。
   */
  createdAt: number; updatedAt: number;
}
/**
 * 描述表情状态事件发布时携带的数据结构。
 */
export interface ExpressionChangedPayload {
  /**
   * 状态数据。
   */
  state: ExpressionState;
}
/**
 * 表情导出/导入时使用的序列化结构，包含所有表情状态的快照。
 */
export interface ExpressionExportData {
  /**
   * 状态列表。
   */
  states: Array<ExpressionState>;
}
