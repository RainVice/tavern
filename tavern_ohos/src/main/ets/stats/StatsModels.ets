/**
 * 描述统计持久化或内存索引中的一条记录。
 */
export interface StatsChatRecord {
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * message Count 值，由当前实例内部维护。
   */
  messageCount: number;
  /**
   * user Messages 列表，由当前实例内部维护。
   */
  userMessages: number;
  /**
   * assistant Messages 列表，由当前实例内部维护。
   */
  assistantMessages: number;
  /**
   * token Count 值，由当前实例内部维护。
   */
  tokenCount: number;
  /**
   * byte Count 值，由当前实例内部维护。
   */
  byteCount: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述统计持久化或内存索引中的一条记录。
 */
export interface StatsProviderRecord {
  /**
   * provider 标识。
   */
  providerId: string;
  /**
   * request Count 值，由当前实例内部维护。
   */
  requestCount: number;
  /**
   * error Count 值，由当前实例内部维护。
   */
  errorCount: number;
  /**
   * error Rate 值，由当前实例内部维护。
   */
  errorRate: number;
  /**
   * generation Count 值，由当前实例内部维护。
   */
  generationCount: number;
  /**
   * generation Time Ms 列表，由当前实例内部维护。
   */
  generationTimeMs: number;
  /**
   * prompt Tokens 列表，由当前实例内部维护。
   */
  promptTokens: number;
  /**
   * completion Tokens 列表，由当前实例内部维护。
   */
  completionTokens: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述统计持久化或内存索引中的一条记录。
 */
export interface StatsRagRecord {
  /**
   * source 标识。
   */
  sourceId: string;
  /**
   * query Count 值，由当前实例内部维护。
   */
  queryCount: number;
  /**
   * hit Count 值，由当前实例内部维护。
   */
  hitCount: number;
  /**
   * hit Rate 值，由当前实例内部维护。
   */
  hitRate: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述统计持久化或内存索引中的一条记录。
 */
export interface StatsPluginRecord {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * error Count 值，由当前实例内部维护。
   */
  errorCount: number;
  /**
   * last Error 值，由当前实例内部维护。
   */
  lastError: string;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述统计持久化或内存索引中的一条记录。
 */
export interface StatsCharacterRecord {
  /**
   * character Key 值，由当前实例内部维护。
   */
  characterKey: string;
  /**
   * total Gen Time 值，由当前实例内部维护。
   */
  totalGenTime: number;
  /**
   * user Msg Count 值，由当前实例内部维护。
   */
  userMsgCount: number;
  /**
   * non User Msg Count 值，由当前实例内部维护。
   */
  nonUserMsgCount: number;
  /**
   * user Word Count 值，由当前实例内部维护。
   */
  userWordCount: number;
  /**
   * non User Word Count 值，由当前实例内部维护。
   */
  nonUserWordCount: number;
  /**
   * total Swipe Count 值，由当前实例内部维护。
   */
  totalSwipeCount: number;
  /**
   * date Last Chat 值，由当前实例内部维护。
   */
  dateLastChat: number;
  /**
   * date First Chat 值，由当前实例内部维护。
   */
  dateFirstChat: number;
}

/**
 * 描述调用统计能力时需要传入的参数。
 */
export interface StatsMessageProcessInput {
  /**
   * character Key 值，由当前实例内部维护。
   */
  characterKey: string;
  /**
   * 消息数据。
   */
  message: string;
  /**
   * is User 值，由当前实例内部维护。
   */
  isUser: boolean;
  /**
   * process Type 值，由当前实例内部维护。
   */
  processType: string;
  /**
   * old Message 值，由当前实例内部维护。
   */
  oldMessage?: string;
  /**
   * gen Started At 值，由当前实例内部维护。
   */
  genStartedAt?: number;
  /**
   * gen Finished At 值，由当前实例内部维护。
   */
  genFinishedAt?: number;
  /**
   * 当前时间戳，由当前实例内部维护。
   */
  now?: number;
}

/**
 * 描述统计模块在运行时交换的数据结构。
 */
export interface StatsTotals {
  /**
   * total Gen Time 值，由当前实例内部维护。
   */
  totalGenTime: number;
  /**
   * user Msg Count 值，由当前实例内部维护。
   */
  userMsgCount: number;
  /**
   * non User Msg Count 值，由当前实例内部维护。
   */
  nonUserMsgCount: number;
  /**
   * user Word Count 值，由当前实例内部维护。
   */
  userWordCount: number;
  /**
   * non User Word Count 值，由当前实例内部维护。
   */
  nonUserWordCount: number;
  /**
   * total Swipe Count 值，由当前实例内部维护。
   */
  totalSwipeCount: number;
  /**
   * date Last Chat 值，由当前实例内部维护。
   */
  dateLastChat: number;
  /**
   * date First Chat 值，由当前实例内部维护。
   */
  dateFirstChat: number;
}

/**
 * 描述统计模块在运行时交换的数据结构。
 */
export interface StatsSnapshot {
  /**
   * total Prompt Tokens 列表，由当前实例内部维护。
   */
  totalPromptTokens: number;
  /**
   * total Completion Tokens 列表，由当前实例内部维护。
   */
  totalCompletionTokens: number;
  /**
   * total Tokens 列表，由当前实例内部维护。
   */
  totalTokens: number;
  /**
   * total Messages 列表，由当前实例内部维护。
   */
  totalMessages: number;
  /**
   * user Messages 列表，由当前实例内部维护。
   */
  userMessages: number;
  /**
   * assistant Messages 列表，由当前实例内部维护。
   */
  assistantMessages: number;
  /**
   * total Chat Bytes 列表，由当前实例内部维护。
   */
  totalChatBytes: number;
  /**
   * total Generations 列表，由当前实例内部维护。
   */
  totalGenerations: number;
  /**
   * total Generation Time Ms 列表，由当前实例内部维护。
   */
  totalGenerationTimeMs: number;
  /**
   * provider Errors 列表，由当前实例内部维护。
   */
  providerErrors: number;
  /**
   * rag Queries 列表，由当前实例内部维护。
   */
  ragQueries: number;
  /**
   * rag Hits 列表，由当前实例内部维护。
   */
  ragHits: number;
  /**
   * plugin Errors 列表，由当前实例内部维护。
   */
  pluginErrors: number;
  /**
   * chat Stats 列表，由当前实例内部维护。
   */
  chatStats: Array<StatsChatRecord>;
  /**
   * provider Stats 列表，由当前实例内部维护。
   */
  providerStats: Array<StatsProviderRecord>;
  /**
   * rag Stats 列表，由当前实例内部维护。
   */
  ragStats: Array<StatsRagRecord>;
  /**
   * plugin Stats 列表，由当前实例内部维护。
   */
  pluginStats: Array<StatsPluginRecord>;
  /**
   * character Stats 列表，由当前实例内部维护。
   */
  characterStats: Array<StatsCharacterRecord>;
}

/**
 * 描述统计模块在运行时交换的数据结构。
 */
export interface StatsGenerationSample {
  /**
   * provider 标识。
   */
  providerId: string;
  /**
   * started At 值，由当前实例内部维护。
   */
  startedAt: number;
  /**
   * finished At 值，由当前实例内部维护。
   */
  finishedAt: number;
  /**
   * duration Ms 列表，由当前实例内部维护。
   */
  durationMs: number;
  /**
   * prompt Tokens 列表，由当前实例内部维护。
   */
  promptTokens: number;
  /**
   * completion Tokens 列表，由当前实例内部维护。
   */
  completionTokens: number;
}

/**
 * 描述统计事件发布时携带的数据结构。
 */
export interface StatsUpdatedPayload {
  /**
   * snapshot 值，由当前实例内部维护。
   */
  snapshot: StatsSnapshot;
}

/**
 * 描述统计事件发布时携带的数据结构。
 */
export interface StatsProviderErrorPayload {
  /**
   * provider 标识。
   */
  providerId: string;
  /**
   * error Count 值，由当前实例内部维护。
   */
  errorCount: number;
  /**
   * error Rate 值，由当前实例内部维护。
   */
  errorRate: number;
}

/**
 * 描述统计事件发布时携带的数据结构。
 */
export interface StatsPluginErrorPayload {
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * error Count 值，由当前实例内部维护。
   */
  errorCount: number;
  /**
   * 消息数据。
   */
  message: string;
}
