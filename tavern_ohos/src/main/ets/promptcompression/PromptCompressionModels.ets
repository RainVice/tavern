/**
 * 描述Prompt 压缩模块在运行时交换的数据结构。
 */
export interface CompressionConfig {
  /**
   * 启用状态。
   */
  enabled: boolean;
  /**
   * 压缩策略。
   */
  strategy: 'trim'|'summarize'|'truncate';
  /**
   * 最大 token 数。
   */
  maxTokens: number;
  /**
   * 保留系统 Prompt 状态。
   */
  preserveSystemPrompt: boolean;
  /**
   * 保留最近消息数量。
   */
  preserveLastMessages: number;
}
/**
 * 描述Prompt 压缩操作完成后返回给调用方的结果。
 */
export interface CompressionResult {
  /**
   * original Tokens 列表。
   */
  originalTokens: number;
  /**
   * compressed Tokens 列表。
   */
  compressedTokens: number;
  /**
   * is Compressed 值，由当前实例内部维护。
   */
  isCompressed: boolean;
}
/**
 * 描述Prompt 压缩事件发布时携带的数据结构。
 */
export interface CompressionAppliedPayload {
  /**
   * 处理结果。
   */
  result: CompressionResult;
}
