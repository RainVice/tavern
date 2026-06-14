/**
 * 描述统计持久化或内存索引中的一条记录。
 * 由 recordMessage / recordTokenUsage 方法更新，代表一个聊天的统计数据。
 */
export interface StatsChatRecord {
  /**
   * 聊天标识，在 chats 映射表中作为唯一键，用于 recordMessage 和 recordTokenUsage 定位目标聊天。
   */
  chatId: string;
  /**
   * 消息数量，在 recordMessage 中每次调用 +1，用于统计该聊天的消息总量。
   */
  messageCount: number;
  /**
   * 用户消息数，在 recordMessage 中根据 role === "user" 递增。
   */
  userMessages: number;
  /**
   * AI 助手消息数，在 recordMessage 中根据 role !== "user" 递增。
   */
  assistantMessages: number;
  /**
   * 消耗的 token 总数，在 recordMessage 和 recordTokenUsage 中累加 prompt + completion token。
   */
  tokenCount: number;
  /**
   * 消息字节数，在 recordMessage 中传入的 byteCount 累加。
   */
  byteCount: number;
  /**
   * 记录最近更新时间戳（毫秒），每次 recordMessage / recordTokenUsage 更新时设置。
   */
  updatedAt: number;
}

/**
 * 描述统计持久化或内存索引中的一条记录。
 * 由 recordProviderRequest / recordGeneration / recordTokenUsage 等方法更新，
 * 代表一个 provider 的请求和生成统计数据。
 */
export interface StatsProviderRecord {
  /**
   * provider 标识，在 providers 映射表中作为唯一键。
   */
  providerId: string;
  /**
   * 请求次数，在 recordProviderRequest 中每次调用 +1。
   */
  requestCount: number;
  /**
   * 错误次数，在 recordProviderRequest 中当 isError 为 true 时 +1。
   */
  errorCount: number;
  /**
   * 错误率（错误数 / 请求总数），由 recordProviderRequest 在每次请求后重新计算。
   */
  errorRate: number;
  /**
   * 生成次数，在 recordGeneration 中每次调用 +1。
   */
  generationCount: number;
  /**
   * 生成总耗时（毫秒），在 recordGeneration 中累加每次生成的耗时。
   */
  generationTimeMs: number;
  /**
   * prompt 消耗的 token 数，在 recordTokenUsage 和 recordGeneration 中累加。
   */
  promptTokens: number;
  /**
   * completion 消耗的 token 数，在 recordTokenUsage 和 recordGeneration 中累加。
   */
  completionTokens: number;
  /**
   * 记录最近更新时间戳（毫秒），每次相关方法更新时设置。
   */
  updatedAt: number;
}

/**
 * 描述统计持久化或内存索引中的一条记录。
 * 由 recordRagQuery 方法更新，代表一个知识库源（RAG source）的查询统计数据。
 */
export interface StatsRagRecord {
  /**
   * source 标识，在 ragSources 映射表中作为唯一键。
   */
  sourceId: string;
  /**
   * 查询次数，在 recordRagQuery 中每次调用 +1。
   */
  queryCount: number;
  /**
   * 命中次数，在 recordRagQuery 中当 hit 为 true 时 +1。
   */
  hitCount: number;
  /**
   * 命中率（命中数 / 查询总数），由 recordRagQuery 在每次查询后重新计算。
   */
  hitRate: number;
  /**
   * 记录最近更新时间戳（毫秒），每次 recordRagQuery 调用时更新。
   */
  updatedAt: number;
}

/**
 * 描述统计持久化或内存索引中的一条记录。
 * 由 recordPluginError 方法更新，代表一个插件的错误统计数据。
 */
export interface StatsPluginRecord {
  /**
   * plugin 标识，在 plugins 映射表中作为唯一键。
   */
  pluginId: string;
  /**
   * 错误次数，在 recordPluginError 中每次调用 +1，并在错误数达到阈值时触发错误事件。
   */
  errorCount: number;
  /**
   * 最近一次错误信息，在 recordPluginError 中每次调用时更新为最新的错误消息。
   */
  lastError: string;
  /**
   * 记录最近更新时间戳（毫秒），每次 recordPluginError 调用时更新。
   */
  updatedAt: number;
}

/**
 * 描述统计持久化或内存索引中的一条记录。
 * 由 processCharacterMessage 方法更新，代表一个角色的消息和生成统计数据。
 */
export interface StatsCharacterRecord {
  /**
   * 角色唯一键值，在 characters 映射表中作为唯一键，用于定位和聚合角色统计数据。
   */
  characterKey: string;
  /**
   * 累计生成耗时（毫秒），在 processCharacterMessage 中累加每次生成的持续时间。
   */
  totalGenTime: number;
  /**
   * 用户消息计数，在 processCharacterMessage 中根据 isUser 和 processType 处理。
   */
  userMsgCount: number;
  /**
   * 非用户消息计数（AI 回复），在 processCharacterMessage 中根据 isUser 和 processType 处理。
   */
  nonUserMsgCount: number;
  /**
   * 用户消息字数，在 processCharacterMessage 中对用户消息通过 countWords 统计字数并累加。
   */
  userWordCount: number;
  /**
   * 非用户消息字数，在 processCharacterMessage 中对 AI 消息通过 countWords 统计字数并累加。
   */
  nonUserWordCount: number;
  /**
   * 滑动重试总次数，在 processCharacterMessage 中当 processType === "swipe" 时 +1。
   */
  totalSwipeCount: number;
  /**
   * 最近聊天日期的时间戳（毫秒），在 processCharacterMessage 中每次更新为当前时间。
   */
  dateLastChat: number;
  /**
   * 首次聊天日期的时间戳（毫秒），在统计记录首次创建时设置，之后保持不变。
   */
  dateFirstChat: number;
}

/**
 * 描述调用统计能力时需要传入的参数。
 * 在 processCharacterMessage 方法中传入，描述一次角色消息处理操作的信息。
 */
export interface StatsMessageProcessInput {
  /**
   * 角色键值，用于 processCharacterMessage 定位在 characters 映射中的统计记录。
   */
  characterKey: string;
  /**
   * 待处理的消息文本，在 processCharacterMessage 中通过 countWords 统计字数。
   */
  message: string;
  /**
   * 是否为用户发送的消息，在 processCharacterMessage 中决定更新 userMsgCount 还是 nonUserMsgCount，
   * 以及累加 userWordCount 还是 nonUserWordCount。
   */
  isUser: boolean;
  /**
   * 处理类型（如 "append"、"swipe"、"continue"），
   * 在 processCharacterMessage 中决定消息计数和字数的增量计算方式，
   * "append" 和 "continue" 类型计算变化量（diff），其他类型直接累加。
   */
  processType: string;
  /**
   * 编辑消息时的旧文本（可选），在 "append"、"continue" 类型中用于计算字数变化量。
   */
  oldMessage?: string;
  /**
   * 生成开始时间戳（可选），在 processCharacterMessage 中与 genFinishedAt 配合计算生成耗时。
   */
  genStartedAt?: number;
  /**
   * 生成结束时间戳（可选），在 processCharacterMessage 中与 genStartedAt 配合计算生成耗时。
   */
  genFinishedAt?: number;
  /**
   * 当前时间戳（可选），用于统一时间基准，未传入时在 processCharacterMessage 内部使用 Date.now()。
   */
  now?: number;
}

/**
 * 描述统计模块在运行时交换的数据结构。
 * 由 getUserStatsTotals 方法构建并返回，基于所有角色统计记录的聚合总计。
 */
export interface StatsTotals {
  /**
   * 累计生成时间（毫秒），汇总所有角色的 totalGenTime。
   */
  totalGenTime: number;
  /**
   * 用户消息计数，汇总所有角色的 userMsgCount。
   */
  userMsgCount: number;
  /**
   * 非用户（AI）消息计数，汇总所有角色的 nonUserMsgCount。
   */
  nonUserMsgCount: number;
  /**
   * 用户消息字数，汇总所有角色的 userWordCount。
   */
  userWordCount: number;
  /**
   * 非用户（AI）消息字数，汇总所有角色的 nonUserWordCount。
   */
  nonUserWordCount: number;
  /**
   * 滑动重试总次数，汇总所有角色的 totalSwipeCount。
   */
  totalSwipeCount: number;
  /**
   * 最近聊天日期的时间戳（毫秒），取所有角色 dateLastChat 的最大值。
   */
  dateLastChat: number;
  /**
   * 首次聊天日期的时间戳（毫秒），取所有角色 dateFirstChat 的最小值。
   */
  dateFirstChat: number;
}

/**
 * 描述统计模块在运行时交换的数据结构。
 * 由 getSnapshot 方法构建并返回，代表当前所有统计数据的完整汇总。
 */
export interface StatsSnapshot {
  /**
   * prompt token 总数，汇总所有 provider 的 promptTokens。
   */
  totalPromptTokens: number;
  /**
   * completion token 总数，汇总所有 provider 的 completionTokens。
   */
  totalCompletionTokens: number;
  /**
   * token 总数（prompt + completion），是 totalPromptTokens 与 totalCompletionTokens 之和。
   */
  totalTokens: number;
  /**
   * 消息总数，汇总所有聊天的 messageCount。
   */
  totalMessages: number;
  /**
   * 用户消息数，汇总所有聊天的 userMessages。
   */
  userMessages: number;
  /**
   * AI 助手消息数，汇总所有聊天的 assistantMessages。
   */
  assistantMessages: number;
  /**
   * 聊天总字节数，汇总所有聊天的 byteCount。
   */
  totalChatBytes: number;
  /**
   * 生成总次数，汇总所有 provider 的 generationCount。
   */
  totalGenerations: number;
  /**
   * 生成总耗时（毫秒），汇总所有 provider 的 generationTimeMs。
   */
  totalGenerationTimeMs: number;
  /**
   * provider 错误总数，汇总所有 provider 的 errorCount。
   */
  providerErrors: number;
  /**
   * 知识库查询总数，汇总所有 RAG source 的 queryCount。
   */
  ragQueries: number;
  /**
   * 知识库命中总数，汇总所有 RAG source 的 hitCount。
   */
  ragHits: number;
  /**
   * 插件错误总数，汇总所有 plugin 的 errorCount。
   */
  pluginErrors: number;
  /**
   * 各聊天统计记录列表，按聊天 ID 排序。
   */
  chatStats: Array<StatsChatRecord>;
  /**
   * 各 provider 统计记录列表，按 provider ID 排序。
   */
  providerStats: Array<StatsProviderRecord>;
  /**
   * 各知识库来源统计记录列表，按 source ID 排序。
   */
  ragStats: Array<StatsRagRecord>;
  /**
   * 各插件统计记录列表，按 plugin ID 排序。
   */
  pluginStats: Array<StatsPluginRecord>;
  /**
   * 各角色统计记录列表，按角色键值排序。
   */
  characterStats: Array<StatsCharacterRecord>;
}

/**
 * 描述统计模块在运行时交换的数据结构。
 * 由 recordGeneration 方法构建并返回，代表一次 AI 文本生成的样本，包含耗时和 token 消耗。
 */
export interface StatsGenerationSample {
  /**
   * provider 标识，标识此次生成由哪个 provider 执行。
   */
  providerId: string;
  /**
   * 生成开始时间戳（毫秒），在 recordGeneration 中由调用方传入。
   */
  startedAt: number;
  /**
   * 生成结束时间戳（毫秒），在 recordGeneration 中由调用方传入。
   */
  finishedAt: number;
  /**
   * 生成耗时（毫秒），在 recordGeneration 中通过 finishedAt - startedAt 计算。
   */
  durationMs: number;
  /**
   * prompt token 数，在 recordGeneration 中由调用方传入并累加到 provider.promptTokens。
   */
  promptTokens: number;
  /**
   * completion token 数，在 recordGeneration 中由调用方传入并累加到 provider.completionTokens。
   */
  completionTokens: number;
}

/**
 * 描述统计事件发布时携带的数据结构。
 * 当任何统计记录发生变更时，通过事件总线发布最新的完整统计快照。
 */
export interface StatsUpdatedPayload {
  /**
   * 更新后的统计快照，宿主可监听 "stats.updated" 事件来刷新 UI 统计展示面板。
   */
  snapshot: StatsSnapshot;
}

/**
 * 描述统计事件发布时携带的数据结构。
 * 当 recordProviderRequest 检测到错误时，通过事件总线通知宿主或监控模块。
 */
export interface StatsProviderErrorPayload {
  /**
   * 发生错误的 provider 标识，宿主可据此在 UI 中高亮显示对应 provider 的错误状态。
   */
  providerId: string;
  /**
   * 累计错误次数，供宿主评估该 provider 的稳定性。
   */
  errorCount: number;
  /**
   * 当前错误率，供宿主决定是否切换 provider 或发出告警。
   */
  errorRate: number;
}

/**
 * 描述统计事件发布时携带的数据结构。
 * 当 recordPluginError 记录插件错误时，通过事件总线通知宿主或监控模块。
 */
export interface StatsPluginErrorPayload {
  /**
   * 发生错误的插件标识，宿主可据此在 UI 中高亮显示对应插件的错误状态。
   */
  pluginId: string;
  /**
   * 累计错误次数，供宿主评估该插件的稳定性。
   */
  errorCount: number;
  /**
   * 错误消息内容，供宿主在 UI 中展示具体的错误原因。
   */
  message: string;
}
