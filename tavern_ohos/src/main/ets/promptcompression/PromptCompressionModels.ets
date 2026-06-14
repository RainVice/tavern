/**
 * 决定 Prompt 压缩行为的总配置项。
 */
export interface CompressionConfig {
  /**
   * 是否启用压缩。为 false 时 {@link PromptCompressionRuntime.applyCompression} 直接返回未压缩结果。
   */
  enabled: boolean;
  /**
   * 压缩策略。
   * - `'trim'`: 从头裁剪超出部分的 token。
   * - `'summarize'`: 对超出部分做摘要替换（需要外部实现）。
   * - `'truncate'`: 丢弃超出最大 token 数的尾部消息。
   */
  strategy: 'trim'|'summarize'|'truncate';
  /**
   * 压缩后允许的最大 token 数（含保留的系统 Prompt）。
   */
  maxTokens: number;
  /**
   * true 时 system 角色消息不参与压缩；false 时全量压缩。
   */
  preserveSystemPrompt: boolean;
  /**
   * 从尾部保留的不压缩消息数，用于保留最近的对话上下文。
   */
  preserveLastMessages: number;
}
/**
 * 单次压缩操作执行完毕后的统计结果。
 */
export interface CompressionResult {
  /**
   * 压缩前的原始 token 数量。
   */
  originalTokens: number;
  /**
   * 压缩后的 token 数量。
   */
  compressedTokens: number;
  /**
   * true 表示本次实际执行了压缩（原始 token 超过 {@link CompressionConfig.maxTokens}）；
   * false 表示未做压缩直接返回。
   */
  isCompressed: boolean;
}
/**
 * 压缩事件 `'prompt.compression.applied'` 发布时携带的载荷。
 */
export interface CompressionAppliedPayload {
  /**
   * 已完成的压缩操作结果。
   */
  result: CompressionResult;
}
