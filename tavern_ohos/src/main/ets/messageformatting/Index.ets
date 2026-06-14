/**
 * 消息格式化模块 - 提供文本格式化和 Markdown 扩展管理能力。
 * 支持启停各类 Markdown 扩展（下划线、删除线、代码块、排除规则），
 * 并对聊天消息文本应用格式清理（如排除规则下的加粗移除）。
 * 在消息展示到 UI 前调用 formatText，确保消息文本按用户配置的格式规则渲染。
 */
export { MessageFormattingRuntime } from './MessageFormattingRuntime';
export type { FormattedResult, FormattingConfig, MarkdownExtension } from './MessageFormattingModels';
