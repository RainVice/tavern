export interface TokenizerProfileCreateParams {
  id: string;
  name: string;
  strategy: string;
  bytesPerToken: number;
  maxContext: number;
  messageOverhead?: number;
}

export interface TokenizerProfile {
  id: string;
  name: string;
  strategy: string;
  bytesPerToken: number;
  maxContext: number;
  messageOverhead: number;
  createdAt: number;
  updatedAt: number;
}

export interface TokenizerOption {
  id: number;
  key: string;
  name: string;
  profileId: string;
  canEncode: boolean;
  remote: boolean;
}

export interface TokenizerSelectionInput {
  api: string;
  provider?: string;
  model?: string;
  remoteTokenizerSupported?: boolean;
  tokenizerWarningShown?: boolean;
}

export interface TokenizerSelectionResult {
  option: TokenizerOption;
  profileId: string;
  tokenizerKey: string;
  remote: boolean;
  reason: string;
}

export interface TokenMessage {
  role: string;
  content: string;
}

export interface TokenMessagePart {
  role: string;
  content: string;
  tokens: number;
}

export interface TokenCountResult {
  profileId: string;
  text: string;
  tokens: number;
  strategy: string;
  fromCache: boolean;
}

export interface TokenMessageCountResult {
  profileId: string;
  tokens: number;
  parts: Array<TokenMessagePart>;
}

export interface TokenBudgetResult {
  profileId: string;
  maxContext: number;
  completionReserve: number;
  availablePromptTokens: number;
  promptTokens: number;
  fits: boolean;
  messages: Array<TokenMessage>;
}

export interface TokenTrimResult {
  result: TokenBudgetResult;
  messages: Array<TokenMessage>;
  removedCount: number;
}

export interface TokenizerProfilePayload {
  profile: TokenizerProfile;
}

export interface TokenizerCountedPayload {
  result: TokenCountResult;
}

export interface TokenBudgetPayload {
  result: TokenBudgetResult;
}
