export interface StatsChatRecord {
  chatId: string;
  messageCount: number;
  userMessages: number;
  assistantMessages: number;
  tokenCount: number;
  byteCount: number;
  updatedAt: number;
}

export interface StatsProviderRecord {
  providerId: string;
  requestCount: number;
  errorCount: number;
  errorRate: number;
  generationCount: number;
  generationTimeMs: number;
  promptTokens: number;
  completionTokens: number;
  updatedAt: number;
}

export interface StatsRagRecord {
  sourceId: string;
  queryCount: number;
  hitCount: number;
  hitRate: number;
  updatedAt: number;
}

export interface StatsPluginRecord {
  pluginId: string;
  errorCount: number;
  lastError: string;
  updatedAt: number;
}

export interface StatsCharacterRecord {
  characterKey: string;
  totalGenTime: number;
  userMsgCount: number;
  nonUserMsgCount: number;
  userWordCount: number;
  nonUserWordCount: number;
  totalSwipeCount: number;
  dateLastChat: number;
  dateFirstChat: number;
}

export interface StatsMessageProcessInput {
  characterKey: string;
  message: string;
  isUser: boolean;
  processType: string;
  oldMessage?: string;
  genStartedAt?: number;
  genFinishedAt?: number;
  now?: number;
}

export interface StatsTotals {
  totalGenTime: number;
  userMsgCount: number;
  nonUserMsgCount: number;
  userWordCount: number;
  nonUserWordCount: number;
  totalSwipeCount: number;
  dateLastChat: number;
  dateFirstChat: number;
}

export interface StatsSnapshot {
  totalPromptTokens: number;
  totalCompletionTokens: number;
  totalTokens: number;
  totalMessages: number;
  userMessages: number;
  assistantMessages: number;
  totalChatBytes: number;
  totalGenerations: number;
  totalGenerationTimeMs: number;
  providerErrors: number;
  ragQueries: number;
  ragHits: number;
  pluginErrors: number;
  chatStats: Array<StatsChatRecord>;
  providerStats: Array<StatsProviderRecord>;
  ragStats: Array<StatsRagRecord>;
  pluginStats: Array<StatsPluginRecord>;
  characterStats: Array<StatsCharacterRecord>;
}

export interface StatsGenerationSample {
  providerId: string;
  startedAt: number;
  finishedAt: number;
  durationMs: number;
  promptTokens: number;
  completionTokens: number;
}

export interface StatsUpdatedPayload {
  snapshot: StatsSnapshot;
}

export interface StatsProviderErrorPayload {
  providerId: string;
  errorCount: number;
  errorRate: number;
}

export interface StatsPluginErrorPayload {
  pluginId: string;
  errorCount: number;
  message: string;
}
