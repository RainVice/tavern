export interface MemoryEntry {
  entryId: string; chatId: string; summary: string; keyPoints: Array<string>;
  originalMessages: Array<string>; tokenEstimate: number; createdAt: number; updatedAt: number;
}
export interface MemoryExtractParams {
  chatId: string; maxTokens: number; recentMessageCount: number;
}
export interface MemoryExtractResult {
  entry: MemoryEntry; truncatedMessages: Array<string>;
}
export interface MemoryExtractedPayload { entry: MemoryEntry; }
export interface MemoryExportData { entries: Array<MemoryEntry>; }
