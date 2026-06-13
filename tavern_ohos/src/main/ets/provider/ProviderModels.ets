export interface ProviderCapability {
  provider: string;
  model: string;
  supportsStreaming: boolean;
  supportsSystemPrompt: boolean;
  supportsTools: boolean;
  supportsReasoning: boolean;
  supportsVisionInput: boolean;
  supportsImageOutput: boolean;
  supportsJsonSchema: boolean;
  supportsLogprobs: boolean;
  supportsSeed: boolean;
  supportsStopStrings: boolean;
  supportsAssistantPrefill: boolean;
  supportsTextCompletion: boolean;
  supportsChatCompletion: boolean;
  maxContext: number;
  tokenizer: string;
}

export interface ProviderChatMessage {
  role: string;
  content: string;
}

export interface ProviderStreamRequest {
  provider: string;
  model: string;
  messages: Array<ProviderChatMessage>;
  temperature: number;
  maxTokens: number;
  stop: Array<string>;
  stream: boolean;
}

export interface ProviderTextCompletionBuildParams {
  apiType: string;
  model: string;
  prompt: string;
  temperature: number;
  maxTokens: number;
  stop: Array<string>;
  stream: boolean;
  topP?: number;
  presencePenalty?: number;
  frequencyPenalty?: number;
  seed?: number;
}

export interface ProviderTextCompletionRequest {
  apiType: string;
  path: string;
  body: ProviderTextCompletionBody;
}

export interface ProviderTextCompletionBody {
  model: string;
  prompt: string;
  temperature: number;
  max_tokens?: number;
  max_new_tokens?: number;
  num_predict?: number;
  stop: Array<string>;
  stream: boolean;
  top_p?: number;
  presence_penalty?: number;
  frequency_penalty?: number;
  seed?: number;
  raw?: boolean;
  options?: ProviderTextCompletionOptions;
}

export interface ProviderTextCompletionOptions {
  temperature: number;
  num_predict: number;
  stop: Array<string>;
  top_p?: number;
  presence_penalty?: number;
  frequency_penalty?: number;
  seed?: number;
}

export interface ProviderStreamStartParams {
  taskId: string;
  chatId: string;
  messageId: string;
  request: ProviderStreamRequest;
  source: ProviderStreamSource;
}

export interface ProviderStreamHandle {
  close(): void;
}

export interface ProviderStreamSink {
  onChunk(chunk: string): Promise<void>;
  onError(message: string): Promise<void>;
  onDone(): Promise<void>;
}

export interface ProviderStreamSource {
  start(request: ProviderStreamRequest, sink: ProviderStreamSink): Promise<ProviderStreamHandle>;
}

export interface ProviderStreamTask {
  taskId: string;
  sessionId: string;
  chatId: string;
  messageId: string;
  provider: string;
  model: string;
  status: string;
  error: string;
  finishReason: string;
  createdAt: number;
  updatedAt: number;
}

export interface ProviderGenerationPayload {
  task: ProviderStreamTask;
}

export interface ProviderSSEEvent {
  event: string;
  data: string;
  id: string;
}

export interface ProviderNormalizedChunk {
  textDelta: string;
  reasoningDelta: string;
  finishReason: string;
  rawJson: string;
}

export interface OpenAICompatibleChatChunk {
  choices: Array<OpenAICompatibleChatChoice>;
}

export interface OpenAICompatibleChatChoice {
  delta?: OpenAICompatibleChatDelta;
  finish_reason?: string | null;
}

export interface OpenAICompatibleChatDelta {
  content?: string | null;
  reasoning_content?: string | null;
  reasoning?: string | null;
}
