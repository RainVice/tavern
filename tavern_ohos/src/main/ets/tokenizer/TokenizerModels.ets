/**
 * 描述调用token 统计能力时需要传入的参数。
 * 在注册分词器配置时传入，用于定义模型的分词策略和上下文窗口大小。
 */
export interface TokenizerProfileCreateParams {
  /**
   * 配置唯一标识，用于在 TokenizerRuntime 中索引和管理配置。
   */
  id: string;
  /**
   * 配置名称，用于 UI 展示和日志记录。
   */
  name: string;
  /**
   * 分词策略（如 "bytes" / "word"），决定 token 数的计算方式。
   */
  strategy: string;
  /**
   * 每个 token 平均字节数估算值，在 bytes 策略下用于将字节数换算为 token 数。
   */
  bytesPerToken: number;
  /**
   * 最大上下文 token 数，用于 token 预算计算和消息裁剪的判断上限。
   */
  maxContext: number;
  /**
   * 每条消息的额外 token 开销（可选），用于模拟 API 调用中每条消息的固定 token 消耗。
   */
  messageOverhead?: number;
}

/**
 * 描述分词器配置的完整记录。
 * 在 TokenizerRuntime 中持久化，用于 token 计算、预算管理和模型绑定。
 */
export interface TokenizerProfile {
  /**
   * 配置唯一标识，在配置映射表中作为查找键。
   */
  id: string;
  /**
   * 配置名称。
   */
  name: string;
  /**
   * 分词策略。
   */
  strategy: string;
  /**
   * 每个 token 平均字节数。
   */
  bytesPerToken: number;
  /**
   * 最大上下文 token 数。
   */
  maxContext: number;
  /**
   * 每条消息的额外 token 开销。
   */
  messageOverhead: number;
  /**
   * 创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 最近更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述token 统计模块在运行时交换的数据结构。
 * 用于定义用户可选的 tokenizer 实现，每个选项关联一个分词器配置。
 */
export interface TokenizerOption {
  /**
   * 选项唯一编号，在选项列表中作为索引。
   */
  id: number;
  /**
   * 选项键名（如 "gpt2" / "llama" / "claude"），用于在模型选择时匹配对应的 tokenizer。
   */
  key: string;
  /**
   * 选项显示名称，用于 UI 展示。
   */
  name: string;
  /**
   * 关联的分词器配置标识，用于定位 TokenizerProfile 进行 token 计算。
   */
  profileId: string;
  /**
   * 是否自带编码能力（本地可计算 token 数），用于区分纯估算和本地精确计算。
   */
  canEncode: boolean;
  /**
   * 是否为远程 API tokenizer，由外部 API 返回 token 数而非本地估算。
   */
  remote: boolean;
}

/**
 * 描述调用分词器选择能力时需要传入的参数。
 * 在自动选择最佳 tokenizer 时传入，包含 API 和模型的相关信息。
 */
export interface TokenizerSelectionInput {
  /**
   * API 类型（如 "openai" / "kobold"），用于辅助推断最适合的 tokenizer。
   */
  api: string;
  /**
   * 提供商名称（可选），用于更精确地匹配 tokenizer。
   */
  provider?: string;
  /**
   * 模型名称（可选），用于根据模型名称精确匹配绑定的 tokenizer 配置。
   */
  model?: string;
  /**
   * 远程 API 是否支持 tokenizer（可选），用于决定是否使用远程 tokenizer 选项。
   */
  remoteTokenizerSupported?: boolean;
  /**
   * 是否已显示过 tokenizer 警告（可选），用于避免重复提示。
   */
  tokenizerWarningShown?: boolean;
}

/**
 * 描述分词器选择操作完成后返回的结果。
 * 在自动选择 tokenizer 时由 selectBestTokenizer 返回。
 */
export interface TokenizerSelectionResult {
  /**
   * 选中的分词器选项。
   */
  option: TokenizerOption;
  /**
   * 选中的配置标识，用于后续的 token 计算和预算管理。
   */
  profileId: string;
  /**
   * 选中的 tokenizer 键名。
   */
  tokenizerKey: string;
  /**
   * 是否为远程 tokenizer。
   */
  remote: boolean;
  /**
   * 选择原因说明，用于日志和分析。
   */
  reason: string;
}

/**
 * 描述token 统计模块在运行时交换的数据结构。
 * 用于 token 预算计算和消息裁剪流程中表示一条消息。
 */
export interface TokenMessage {
  /**
   * 消息角色（如 "system" / "user" / "assistant"），用于裁剪时决定优先保留 system 消息。
   */
  role: string;
  /**
   * 消息文本内容，用于计算该消息占用的 token 数。
   */
  content: string;
}

/**
 * 描述分词统计模块在运行时交换的消息片段结构。
 * 在 countMessages 的返回结果中，记录每条消息的 token 占用详情。
 */
export interface TokenMessagePart {
  /**
   * 消息角色。
   */
  role: string;
  /**
   * 消息文本内容。
   */
  content: string;
  /**
   * 该消息占用的 token 数量，包含 messageOverhead。
   */
  tokens: number;
}

/**
 * 描述单条文本的 token 计数结果。
 * 在 countText 的返回结果中，记录文本的 token 统计信息。
 */
export interface TokenCountResult {
  /**
   * 使用的配置标识，用于关联回对应的分词器配置。
   */
  profileId: string;
  /**
   * 被统计的文本内容。
   */
  text: string;
  /**
   * 统计出的 token 数量。
   */
  tokens: number;
  /**
   * 使用的分词策略。
   */
  strategy: string;
  /**
   * 结果是否来自缓存，用于加速相同文本的重复统计。
   */
  fromCache: boolean;
}

/**
 * 描述多条消息的 token 计数结果。
 * 在 countMessages 的返回结果中，记录消息列表的汇总 token 统计。
 */
export interface TokenMessageCountResult {
  /**
   * 使用的配置标识。
   */
  profileId: string;
  /**
   * 所有消息的总 token 数。
   */
  tokens: number;
  /**
   * 每条消息的 token 计数组件，供预算计算或裁剪时逐条分析。
   */
  parts: Array<TokenMessagePart>;
}

/**
 * 描述 token 预算计算结果。
 * 在 buildBudget 的返回结果中，用于判断当前消息列表是否超出上下文限制。
 */
export interface TokenBudgetResult {
  /**
   * 使用的配置标识。
   */
  profileId: string;
  /**
   * 最大上下文 token 数，来自配置的 maxContext。
   */
  maxContext: number;
  /**
   * 为生成回复预留的 token 数，确保 AI 模型有足够空间生成回复。
   */
  completionReserve: number;
  /**
   * 可用于提示词的最大 token 数，等于 maxContext - completionReserve。
   */
  availablePromptTokens: number;
  /**
   * 当前提示词占用的 token 数，由 countMessages 计算得出。
   */
  promptTokens: number;
  /**
   * 提示词是否能在预算内放下，供宿主判断是否需要进行消息裁剪。
   */
  fits: boolean;
  /**
   * 参与预算计算的消息列表。
   */
  messages: Array<TokenMessage>;
}

/**
 * 描述 token 预算裁剪结果。
 * 在 trimMessagesToBudget 的返回结果中，包含裁剪后的消息列表和移除统计。
 */
export interface TokenTrimResult {
  /**
   * 裁剪后的预算计算结果。
   */
  result: TokenBudgetResult;
  /**
   * 裁剪后的消息列表，确保满足预算要求。
   */
  messages: Array<TokenMessage>;
  /**
   * 被移除的消息数量，供日志和 UI 提示使用。
   */
  removedCount: number;
}

/**
 * 描述token 统计事件发布时携带的数据结构。
 * TokenizerRuntime 在注册配置后发布 tokenizer.profile.registered 事件。
 */
export interface TokenizerProfilePayload {
  /**
   * 已注册或更新的配置记录。
   */
  profile: TokenizerProfile;
}

/**
 * 描述分词统计事件发布时携带的数据结构。
 * TokenizerRuntime 在 countText 后发布 tokenizer.counted 事件。
 */
export interface TokenizerCountedPayload {
  /**
   * 计数结果。
   */
  result: TokenCountResult;
}

/**
 * 描述 token 预算计算事件发布时携带的数据结构。
 * TokenizerRuntime 在 buildBudget 后发布 tokenizer.budget.built 事件。
 */
export interface TokenBudgetPayload {
  /**
   * 预算计算结果。
   */
  result: TokenBudgetResult;
}
