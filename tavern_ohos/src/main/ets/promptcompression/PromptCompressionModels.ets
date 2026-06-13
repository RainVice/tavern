export interface CompressionConfig { enabled: boolean; strategy: 'trim'|'summarize'|'truncate';
  maxTokens: number; preserveSystemPrompt: boolean; preserveLastMessages: number; }
export interface CompressionResult { originalTokens: number; compressedTokens: number; isCompressed: boolean; }
export interface CompressionAppliedPayload { result: CompressionResult; }
