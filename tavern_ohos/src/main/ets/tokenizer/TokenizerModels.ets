/**
 * 描述调用token 统计能力时需要传入的参数。
 */
export interface TokenizerProfileCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * strategy 值，由当前实例内部维护。
   */
  strategy: string;
  /**
   * bytes Per Token 值，由当前实例内部维护。
   */
  bytesPerToken: number;
  /**
   * max Context 值，由当前实例内部维护。
   */
  maxContext: number;
  /**
   * message Overhead 值，由当前实例内部维护。
   */
  messageOverhead?: number;
}

/**
 * 描述token 统计模块在运行时交换的数据结构。
 */
export interface TokenizerProfile {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * strategy 值，由当前实例内部维护。
   */
  strategy: string;
  /**
   * bytes Per Token 值，由当前实例内部维护。
   */
  bytesPerToken: number;
  /**
   * max Context 值，由当前实例内部维护。
   */
  maxContext: number;
  /**
   * message Overhead 值，由当前实例内部维护。
   */
  messageOverhead: number;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述token 统计模块在运行时交换的数据结构。
 */
export interface TokenizerOption {
  /**
   * 标识。
   */
  id: number;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * profile 标识。
   */
  profileId: string;
  /**
   * can Encode 值，由当前实例内部维护。
   */
  canEncode: boolean;
  /**
   * remote 值，由当前实例内部维护。
   */
  remote: boolean;
}

/**
 * 描述调用token 统计能力时需要传入的参数。
 */
export interface TokenizerSelectionInput {
  /**
   * api 值，由当前实例内部维护。
   */
  api: string;
  /**
   * provider 值，由当前实例内部维护。
   */
  provider?: string;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model?: string;
  /**
   * remote Tokenizer Supported 值，由当前实例内部维护。
   */
  remoteTokenizerSupported?: boolean;
  /**
   * tokenizer Warning Shown 值，由当前实例内部维护。
   */
  tokenizerWarningShown?: boolean;
}

/**
 * 描述token 统计操作完成后返回给调用方的结果。
 */
export interface TokenizerSelectionResult {
  /**
   * option 值，由当前实例内部维护。
   */
  option: TokenizerOption;
  /**
   * profile 标识。
   */
  profileId: string;
  /**
   * tokenizer Key 值，由当前实例内部维护。
   */
  tokenizerKey: string;
  /**
   * remote 值，由当前实例内部维护。
   */
  remote: boolean;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
}

/**
 * 描述token 统计模块在运行时交换的数据结构。
 */
export interface TokenMessage {
  /**
   * role 值，由当前实例内部维护。
   */
  role: string;
  /**
   * 内容。
   */
  content: string;
}

/**
 * 描述token 统计模块在运行时交换的数据结构。
 */
export interface TokenMessagePart {
  /**
   * role 值，由当前实例内部维护。
   */
  role: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * tokens 列表，由当前实例内部维护。
   */
  tokens: number;
}

/**
 * 描述token 统计操作完成后返回给调用方的结果。
 */
export interface TokenCountResult {
  /**
   * profile 标识。
   */
  profileId: string;
  /**
   * 文本内容。
   */
  text: string;
  /**
   * tokens 列表，由当前实例内部维护。
   */
  tokens: number;
  /**
   * strategy 值，由当前实例内部维护。
   */
  strategy: string;
  /**
   * from Cache 值，由当前实例内部维护。
   */
  fromCache: boolean;
}

/**
 * 描述token 统计操作完成后返回给调用方的结果。
 */
export interface TokenMessageCountResult {
  /**
   * profile 标识。
   */
  profileId: string;
  /**
   * tokens 列表，由当前实例内部维护。
   */
  tokens: number;
  /**
   * 路径分段，由当前实例内部维护。
   */
  parts: Array<TokenMessagePart>;
}

/**
 * 描述token 统计操作完成后返回给调用方的结果。
 */
export interface TokenBudgetResult {
  /**
   * profile 标识。
   */
  profileId: string;
  /**
   * max Context 值，由当前实例内部维护。
   */
  maxContext: number;
  /**
   * completion Reserve 值，由当前实例内部维护。
   */
  completionReserve: number;
  /**
   * available Prompt Tokens 列表，由当前实例内部维护。
   */
  availablePromptTokens: number;
  /**
   * prompt Tokens 列表，由当前实例内部维护。
   */
  promptTokens: number;
  /**
   * fits 列表，由当前实例内部维护。
   */
  fits: boolean;
  /**
   * 消息列表。
   */
  messages: Array<TokenMessage>;
}

/**
 * 描述token 统计操作完成后返回给调用方的结果。
 */
export interface TokenTrimResult {
  /**
   * 处理结果。
   */
  result: TokenBudgetResult;
  /**
   * 消息列表。
   */
  messages: Array<TokenMessage>;
  /**
   * removed Count 值，由当前实例内部维护。
   */
  removedCount: number;
}

/**
 * 描述token 统计事件发布时携带的数据结构。
 */
export interface TokenizerProfilePayload {
  /**
   * profile 值，由当前实例内部维护。
   */
  profile: TokenizerProfile;
}

/**
 * 描述token 统计事件发布时携带的数据结构。
 */
export interface TokenizerCountedPayload {
  /**
   * 处理结果。
   */
  result: TokenCountResult;
}

/**
 * 描述token 统计事件发布时携带的数据结构。
 */
export interface TokenBudgetPayload {
  /**
   * 处理结果。
   */
  result: TokenBudgetResult;
}
