/**
 * 单个聊天会话的统计记录。
 */
export interface StatsChatRecord {
  /**
   * 聊天会话的唯一标识。
   */
  chatId: string;
  /**
   * 消息总数。
   */
  messageCount: number;
  /**
   * 用户消息数。
   */
  userMessages: number;
  /**
   * 助手（AI）消息数。
   */
  assistantMessages: number;
  /**
   * 消耗的 token 总数。
   */
  tokenCount: number;
  /**
   * 消息内容的字节总数。
   */
  byteCount: number;
  /**
   * 记录最后更新时间的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 模型服务提供者的统计记录。
 */
export interface StatsProviderRecord {
  /**
   * 提供者的唯一标识。
   */
  providerId: string;
  /**
   * 总请求次数。
   */
  requestCount: number;
  /**
   * 请求失败次数。
   */
  errorCount: number;
  /**
   * 请求错误率（失败次数/总请求次数的比值）。
   */
  errorRate: number;
  /**
   * 生成完成的总次数。
   */
  generationCount: number;
  /**
   * 累计生成耗时（毫秒）。
   */
  generationTimeMs: number;
  /**
   * 累计提示词 token 数。
   */
  promptTokens: number;
  /**
   * 累计补全 token 数。
   */
  completionTokens: number;
  /**
   * 记录最后更新时间的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 知识库（RAG）查询来源的统计记录。
 */
export interface StatsRagRecord {
  /**
   * 知识库来源的唯一标识。
   */
  sourceId: string;
  /**
   * 查询次数。
   */
  queryCount: number;
  /**
   * 命中次数（成功检索到相关内容）。
   */
  hitCount: number;
  /**
   * 命中率（命中次数/查询次数的比值）。
   */
  hitRate: number;
  /**
   * 记录最后更新时间的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 插件的错误统计记录。
 */
export interface StatsPluginRecord {
  /**
   * 插件的唯一标识。
   */
  pluginId: string;
  /**
   * 累计错误次数。
   */
  errorCount: number;
  /**
   * 最近一次错误信息。
   */
  lastError: string;
  /**
   * 记录最后更新时间的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 单个角色的使用统计记录。
 */
export interface StatsCharacterRecord {
  /**
   * 角色的唯一标识键。
   */
  characterKey: string;
  /**
   * 累计生成耗时（毫秒）。
   */
  totalGenTime: number;
  /**
   * 用户消息数量。
   */
  userMsgCount: number;
  /**
   * 非用户消息数量（AI 回复）。
   */
  nonUserMsgCount: number;
  /**
   * 用户消息的单词总数。
   */
  userWordCount: number;
  /**
   * 非用户消息的单词总数。
   */
  nonUserWordCount: number;
  /**
   * 总滑动（swipe）次数。
   */
  totalSwipeCount: number;
  /**
   * 最近一次聊天的日期时间戳（毫秒）。
   */
  dateLastChat: number;
  /**
   * 首次聊天的日期时间戳（毫秒）。
   */
  dateFirstChat: number;
}

/**
 * 处理消息时需要传入的统计参数。
 */
export interface StatsMessageProcessInput {
  /**
   * 角色的唯一标识键。
   */
  characterKey: string;
  /**
   * 消息文本内容。
   */
  message: string;
  /**
   * 是否为用户发送的消息。
   */
  isUser: boolean;
  /**
   * 处理类型，例如 `"append"`、`"continue"`、`"swipe"`。
   */
  processType: string;
  /**
   * 旧消息文本，编辑操作时传入以计算增量。
   */
  oldMessage?: string;
  /**
   * 生成开始的时间戳（毫秒）。
   */
  genStartedAt?: number;
  /**
   * 生成结束的时间戳（毫秒）。
   */
  genFinishedAt?: number;
  /**
   * 记录的参考时间戳，不传则以当前时间代替。
   */
  now?: number;
}

/**
 * 用户维度的汇总统计数据。
 */
export interface StatsTotals {
  /**
   * 累计生成耗时（毫秒）。
   */
  totalGenTime: number;
  /**
   * 用户消息数量。
   */
  userMsgCount: number;
  /**
   * 非用户消息数量（AI 回复）。
   */
  nonUserMsgCount: number;
  /**
   * 用户消息的单词总数。
   */
  userWordCount: number;
  /**
   * 非用户消息的单词总数。
   */
  nonUserWordCount: number;
  /**
   * 总滑动（swipe）次数。
   */
  totalSwipeCount: number;
  /**
   * 最近一次聊天的日期时间戳（毫秒）。
   */
  dateLastChat: number;
  /**
   * 首次聊天的日期时间戳（毫秒）。
   */
  dateFirstChat: number;
}

/**
 * 当前统计数据的完整快照，包含所有维度的聚合值。
 */
export interface StatsSnapshot {
  /**
   * 总提示词 token 数。
   */
  totalPromptTokens: number;
  /**
   * 总补全 token 数。
   */
  totalCompletionTokens: number;
  /**
   * 总 token 数（提示词 + 补全）。
   */
  totalTokens: number;
  /**
   * 总消息数。
   */
  totalMessages: number;
  /**
   * 用户消息数。
   */
  userMessages: number;
  /**
   * 助手（AI）消息数。
   */
  assistantMessages: number;
  /**
   * 聊天消息的总字节数。
   */
  totalChatBytes: number;
  /**
   * 总生成次数。
   */
  totalGenerations: number;
  /**
   * 总生成耗时（毫秒）。
   */
  totalGenerationTimeMs: number;
  /**
   * 提供者错误总数。
   */
  providerErrors: number;
  /**
   * 知识库查询总数。
   */
  ragQueries: number;
  /**
   * 知识库命中总数。
   */
  ragHits: number;
  /**
   * 插件错误总数。
   */
  pluginErrors: number;
  /**
   * 各聊天会话的统计列表。
   */
  chatStats: Array<StatsChatRecord>;
  /**
   * 各模型服务提供者的统计列表。
   */
  providerStats: Array<StatsProviderRecord>;
  /**
   * 各知识库来源的统计列表。
   */
  ragStats: Array<StatsRagRecord>;
  /**
   * 各插件的统计列表。
   */
  pluginStats: Array<StatsPluginRecord>;
  /**
   * 各角色的统计列表。
   */
  characterStats: Array<StatsCharacterRecord>;
}

/**
 * 单次模型生成的采样统计记录。
 */
export interface StatsGenerationSample {
  /**
   * 模型服务提供者的唯一标识。
   */
  providerId: string;
  /**
   * 生成开始的时间戳（毫秒）。
   */
  startedAt: number;
  /**
   * 生成结束的时间戳（毫秒）。
   */
  finishedAt: number;
  /**
   * 生成耗时（毫秒）。
   */
  durationMs: number;
  /**
   * 提示词 token 数。
   */
  promptTokens: number;
  /**
   * 补全 token 数。
   */
  completionTokens: number;
}

/**
 * 统计更新事件发布时携带的载荷。
 */
export interface StatsUpdatedPayload {
  /**
   * 完整的统计快照。
   */
  snapshot: StatsSnapshot;
}

/**
 * 模型提供者错误事件发布时携带的载荷。
 */
export interface StatsProviderErrorPayload {
  /**
   * 模型服务提供者的唯一标识。
   */
  providerId: string;
  /**
   * 累计错误次数。
   */
  errorCount: number;
  /**
   * 当前错误率（失败次数/总请求次数的比值）。
   */
  errorRate: number;
}

/**
 * 插件错误事件发布时携带的载荷。
 */
export interface StatsPluginErrorPayload {
  /**
   * 插件的唯一标识。
   */
  pluginId: string;
  /**
   * 累计错误次数。
   */
  errorCount: number;
  /**
   * 最近一次错误的错误消息。
   */
  message: string;
}
