/**
 * 描述Prompt 压缩模块在运行时交换的数据结构。
 */
export interface CompressionConfig {
  /**
   * 启用状态，用于控制 Prompt 压缩功能在发送给 LLM 之前是否生效。
   */
  enabled: boolean;
  /**
   * 压缩策略（trim/summarize/truncate），用于决定超出 token 限制时的处理方式。
   */
  strategy: 'trim'|'summarize'|'truncate';
  /**
   * 最大 token 数，用于触发压缩的阈值——当前 token 数超过此值时执行压缩。
   */
  maxTokens: number;
  /**
   * 保留系统 Prompt 状态，用于在压缩时决定是否跳过系统提示词部分以免丢失上下文。
   */
  preserveSystemPrompt: boolean;
  /**
   * 保留最近消息数量，用于在压缩时确保尾部最近 N 条对话消息不被截断以维持连贯性。
   */
  preserveLastMessages: number;
}
/**
 * 描述Prompt 压缩操作完成后返回给调用方的结果。
 */
export interface CompressionResult {
  /**
   * original Tokens 列表，用于记录压缩前 Prompt 的 token 总数以便对比压缩效果。
   */
  originalTokens: number;
  /**
   * compressed Tokens 列表，用于记录压缩后 token 总数；若未压缩则等于 originalTokens。
   */
  compressedTokens: number;
  /**
   * 是否已执行压缩，true 表示 token 数已缩减至 maxTokens 以内——调用方据此判断是否需要调整后续流程。
   */
  isCompressed: boolean;
}
/**
 * 描述Prompt 压缩事件发布时携带的数据结构。
 */
export interface CompressionAppliedPayload {
  /**
   * 处理结果，用于通知宿主或其他 Runtime 压缩已完成并携带 token 变化详情。
   */
  result: CompressionResult;
}
