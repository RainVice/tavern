export type MarkdownExtension = 'underline'|'strikethrough'|'code_block'|'exclusion';
export interface FormattingConfig { enabledExtensions: Array<MarkdownExtension>; codeBlockLanguages: Array<string>; }
export interface FormattedResult { original: string; formatted: string; }
