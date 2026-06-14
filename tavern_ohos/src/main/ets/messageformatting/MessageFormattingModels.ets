/**
 * 限定消息格式化模块可接受的 Markdown 扩展名称，用于 FormattingConfig.enabledExtensions 的取值。
 * 在 formatText 中根据配置启用或禁用对应的格式化规则。
 * - underline: 下划线支持
 * - strikethrough: 删除线支持
 * - code_block: 代码块支持
 * - exclusion: 排除规则（移除加粗标记等）
 */
export type MarkdownExtension = 'underline'|'strikethrough'|'code_block'|'exclusion';
/**
 * 描述消息格式化模块的配置结构。
 * 由 MessageFormattingRuntime 内部维护，通过 setConfig / getConfig 进行读写，
 * formatText 在格式化消息时依据此配置选择应用的格式化规则。
 */
export interface FormattingConfig {
  /**
   * 当前已启用的 Markdown 扩展列表，决定 formatText 执行时启用了哪些格式化规则（如 underline、strikethrough 等）。
   */
  enabledExtensions: Array<MarkdownExtension>;
  /**
   * 代码块中支持的编程语言列表，用于代码块语法高亮和语言标识。
   */
  codeBlockLanguages: Array<string>;
}
/**
 * 描述消息格式化操作完成后返回给调用方的结果。
 * 由 MessageFormattingRuntime.formatText 返回，调用方（如消息展示 UI）使用 formatted 渲染消息，
 * 并可通过 original 对比格式化前后的差异。
 */
export interface FormattedResult {
  /**
   * 格式化前的原始消息文本，供调用方在需要时获取原文或对比差异。
   */
  original: string;
  /**
   * 格式化后的消息文本，已应用当前配置的所有格式化规则，为最终展示内容。
   */
  formatted: string;
}
