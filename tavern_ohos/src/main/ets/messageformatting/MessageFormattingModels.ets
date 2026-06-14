/**
 * 限定消息格式化模块可接受的字符串取值范围。
 */
export type MarkdownExtension = 'underline'|'strikethrough'|'code_block'|'exclusion';
/**
 * 描述消息格式化模块在运行时交换的数据结构。
 */
export interface FormattingConfig {
  /**
   * enabled Extensions 列表。
   */
  enabledExtensions: Array<MarkdownExtension>;
  /**
   * code Block Languages 列表。
   */
  codeBlockLanguages: Array<string>;
}
/**
 * 描述消息格式化操作完成后返回给调用方的结果。
 */
export interface FormattedResult {
  /**
   * 原始内容。
   */
  original: string;
  /**
   * 格式化内容。
   */
  formatted: string;
}
