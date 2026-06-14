/**
 * 作者注释模块。
 * 导出 AuthorNoteRuntime 类、模块名称常量及相关类型，提供作者注释注入的生成和事件发布能力。
 * 在 Prompt 构建阶段被调用，用于在对话中按预设周期向上下文注入额外提示词。
 */
export { AuthorNoteRuntime } from './AuthorNoteRuntime';
export { AUTHOR_NOTE_MODULE_NAME } from './AuthorNoteModels';
export type {
  AuthorNoteBuildInput,
  AuthorNoteBuiltPayload,
  AuthorNoteCharacterNote,
  AuthorNoteDefaults,
  AuthorNoteInjection,
  AuthorNoteMetadata,
} from './AuthorNoteModels';
