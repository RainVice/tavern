export type ExpressionClassification = 'joy'|'sadness'|'anger'|'fear'|'surprise'|'disgust'|'neutral'|'love'|'custom';
export interface ExpressionState {
  expressionId: string; characterId: string; classification: ExpressionClassification;
  label: string; spriteName: string; intensity: number; messageId: string;
  createdAt: number; updatedAt: number;
}
export interface ExpressionChangedPayload { state: ExpressionState; }
export interface ExpressionExportData { states: Array<ExpressionState>; }
