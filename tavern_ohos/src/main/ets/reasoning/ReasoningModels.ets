export interface ReasoningRecord {
  messageId: string;
  snapshot: string;
  metadataJson: string;
  signature: string;
  visible: boolean;
  includeInPrompt: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface ReasoningDeltaPayload {
  reasoning: ReasoningRecord;
  delta: string;
}

export interface ReasoningUpdatedPayload {
  reasoning: ReasoningRecord;
}
