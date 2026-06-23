import type {
  ChatMessageRole,
  ProviderId,
  TokenizerStrategy,
} from '../contracts/PublicContracts';

/**
 * 描述创建 TokenizerProfile 时需要传入的参数。
 */
export interface TokenizerProfileCreateParams {
  /**
   * 配置文件唯一标识。
   */
  id: string;
  /**
   * 配置文件显示名称。
   */
  name: string;
  /**
   * 分词策略。
   */
  strategy: TokenizerStrategy;
  /**
   * 每个 token 的预估字节数。
   */
  bytesPerToken: number;
  /**
   * 最大上下文长度（token 数）。
   */
  maxContext: number;
  /**
   * 每条消息的额外 token 开销（可选，默认 0）。
   */
  messageOverhead?: number;
}

/**
 * 描述分词器配置文件的完整记录。
 */
export interface TokenizerProfile {
  /**
   * 配置文件唯一标识。
   */
  id: string;
  /**
   * 配置文件显示名称。
   */
  name: string;
  /**
   * 分词策略。
   */
  strategy: TokenizerStrategy;
  /**
   * 每个 token 的预估字节数。
   */
  bytesPerToken: number;
  /**
   * 最大上下文长度（token 数）。
   */
  maxContext: number;
  /**
   * 每条消息的额外 token 开销。
   */
  messageOverhead: number;
  /**
   * 记录创建时间戳（单位 ms）。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（单位 ms）。
   */
  updatedAt: number;
}

/**
 * 描述一个可选的分词器选项。
 */
export interface TokenizerOption {
  /**
   * 选项编号。
   */
  id: number;
  /**
   * 选项键名。
   */
  key: string;
  /**
   * 选项显示名称。
   */
  name: string;
  /**
   * 关联的配置文件标识。
   */
  profileId: string;
  /**
   * 是否支持本地编码。
   */
  canEncode: boolean;
  /**
   * 是否为远程分词器。
   */
  remote: boolean;
}

/**
 * 描述选择最佳分词器时需要传入的参数。
 */
export interface TokenizerSelectionInput {
  /**
   * API 名称（如 openai、kobold）。
   */
  api: string;
  /**
   * 提供商标识。
   */
  provider?: ProviderId;
  /**
   * 模型名称。
   */
  model?: string;
  /**
   * 是否支持远程分词器。
   */
  remoteTokenizerSupported?: boolean;
  /**
   * 远程分词器警告是否已展示。
   */
  tokenizerWarningShown?: boolean;
}

/**
 * 描述选择最佳分词器的计算结果。
 */
export interface TokenizerSelectionResult {
  /**
   * 选中的分词器选项。
   */
  option: TokenizerOption;
  /**
   * 选中的配置文件标识。
   */
  profileId: string;
  /**
   * 分词器键名。
   */
  tokenizerKey: string;
  /**
   * 是否为远程分词器。
   */
  remote: boolean;
  /**
   * 选择原因说明。
   */
  reason: string;
}

/**
 * 描述一条消息记录，包含角色和内容。
 */
export interface TokenMessage {
  /**
   * 消息角色。
   */
  role: ChatMessageRole;
  /**
   * 消息文本内容。
   */
  content: string;
}

/**
 * 描述一条消息的分段统计结果，包含角色、内容和 token 数。
 */
export interface TokenMessagePart {
  /**
   * 消息角色。
   */
  role: ChatMessageRole;
  /**
   * 消息文本内容。
   */
  content: string;
  /**
   * 该分段的 token 数。
   */
  tokens: number;
}

/**
 * 描述单次文本 token 计数的结果。
 */
export interface TokenCountResult {
  /**
   * 使用的配置文件标识。
   */
  profileId: string;
  /**
   * 被统计的文本内容。
   */
  text: string;
  /**
   * 文本的 token 数量。
   */
  tokens: number;
  /**
   * 使用的分词策略。
   */
  strategy: TokenizerStrategy;
  /**
   * 是否从缓存中获取结果。
   */
  fromCache: boolean;
}

/**
 * 描述多条消息的 token 统计结果。
 */
export interface TokenMessageCountResult {
  /**
   * 使用的配置文件标识。
   */
  profileId: string;
  /**
   * 消息总 token 数。
   */
  tokens: number;
  /**
   * 每条消息的分段统计结果。
   */
  parts: Array<TokenMessagePart>;
}

/**
 * 描述上下文预算的计算结果（上下文是否足够容纳消息）。
 */
export interface TokenBudgetResult {
  /**
   * 使用的配置文件标识。
   */
  profileId: string;
  /**
   * 模型最大上下文长度（token 数）。
   */
  maxContext: number;
  /**
   * 为生成回复预留的 token 数。
   */
  completionReserve: number;
  /**
   * 实际可用于提示的 token 数上限。
   */
  availablePromptTokens: number;
  /**
   * 提示实际消耗的 token 数。
   */
  promptTokens: number;
  /**
   * 当前提示是否在上下文限制内。
   */
  fits: boolean;
  /**
   * 参与预算计算的消息列表。
   */
  messages: Array<TokenMessage>;
}

/**
 * 描述裁剪消息以适配上下文预算后的结果。
 */
export interface TokenTrimResult {
  /**
   * 裁剪后的预算计算结果。
   */
  result: TokenBudgetResult;
  /**
   * 裁剪后的剩余消息列表。
   */
  messages: Array<TokenMessage>;
  /**
   * 被移除的消息数量。
   */
  removedCount: number;
}

/**
 * 描述分词器 profile 相关事件发布时携带的数据结构。
 */
export interface TokenizerProfilePayload {
  /**
   * 关联的配置文件。
   */
  profile: TokenizerProfile;
}

/**
 * 描述 token 统计事件发布时携带的数据结构。
 */
export interface TokenizerCountedPayload {
  /**
   * token 计数结果。
   */
  result: TokenCountResult;
}

/**
 * 描述预算计算结果事件发布时携带的数据结构。
 */
export interface TokenBudgetPayload {
  /**
   * 预算计算结果。
   */
  result: TokenBudgetResult;
}
