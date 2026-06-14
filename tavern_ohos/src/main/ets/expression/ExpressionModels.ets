/**
 * 限定表情状态模块可接受的字符串取值范围。
 */
export type ExpressionClassification = 'joy'|'sadness'|'anger'|'fear'|'surprise'|'disgust'|'neutral'|'love'|'custom';
/**
 * 描述表情状态模块在运行时交换的数据结构。
 */
export interface ExpressionState {
  /**
   * expression 标识。
   */
  expressionId: string; characterId: string; classification: ExpressionClassification;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string; spriteName: string; intensity: number; messageId: string;
  /**
   * created At 值，由当前实例内部维护。
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
 * 描述表情状态模块在运行时交换的数据结构。
 */
export interface ExpressionExportData {
  /**
   * 状态列表。
   */
  states: Array<ExpressionState>;
}
