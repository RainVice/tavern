import type { ProviderCapability } from './ProviderModels';

// 后端名称
export type ProviderBackendName =
  | 'anthropic' | 'azure' | 'gemini' | 'kobold' | 'horde'
  | 'minimax' | 'nanogpt' | 'novelai' | 'openrouter' | 'volcengine';

// ---- 能力声明 ----
const ANTHROPIC_CAPABILITY_DATA: ProviderCapability = {
  provider: 'anthropic', model: 'claude',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: true, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: true,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 200000, tokenizer: 'claude',
};
const AZURE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'azure', model: 'azure-openai',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: true, supportsLogprobs: true, supportsSeed: true,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 128000, tokenizer: 'openai',
};
const GEMINI_CAPABILITY_DATA: ProviderCapability = {
  provider: 'gemini', model: 'gemini',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: false, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: false, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 1000000, tokenizer: 'gemini',
};
const KOBOLD_CAPABILITY_DATA: ProviderCapability = {
  provider: 'kobold', model: 'kobold',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
const HORDE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'horde', model: 'horde',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
const MINIMAX_CAPABILITY_DATA: ProviderCapability = {
  provider: 'minimax', model: 'minimax',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 245760, tokenizer: 'llama',
};
const NANOGPT_CAPABILITY_DATA: ProviderCapability = {
  provider: 'nanogpt', model: 'nanogpt',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
const NOVELAI_CAPABILITY_DATA: ProviderCapability = {
  provider: 'novelai', model: 'novelai',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 8192, tokenizer: 'llama',
};
const OPENROUTER_CAPABILITY_DATA: ProviderCapability = {
  provider: 'openrouter', model: 'openrouter',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: true, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: true, supportsLogprobs: true, supportsSeed: true,
  supportsStopStrings: true, supportsAssistantPrefill: true,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 200000, tokenizer: 'openai',
};
const VOLCENGINE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'volcengine', model: 'volcengine',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 32768, tokenizer: 'llama',
};

export const ANTHROPIC_CAPABILITY: ProviderCapability = cloneProviderCapability(ANTHROPIC_CAPABILITY_DATA);
export const AZURE_CAPABILITY: ProviderCapability = cloneProviderCapability(AZURE_CAPABILITY_DATA);
export const GEMINI_CAPABILITY: ProviderCapability = cloneProviderCapability(GEMINI_CAPABILITY_DATA);
export const KOBOLD_CAPABILITY: ProviderCapability = cloneProviderCapability(KOBOLD_CAPABILITY_DATA);
export const HORDE_CAPABILITY: ProviderCapability = cloneProviderCapability(HORDE_CAPABILITY_DATA);
export const MINIMAX_CAPABILITY: ProviderCapability = cloneProviderCapability(MINIMAX_CAPABILITY_DATA);
export const NANOGPT_CAPABILITY: ProviderCapability = cloneProviderCapability(NANOGPT_CAPABILITY_DATA);
export const NOVELAI_CAPABILITY: ProviderCapability = cloneProviderCapability(NOVELAI_CAPABILITY_DATA);
export const OPENROUTER_CAPABILITY: ProviderCapability = cloneProviderCapability(OPENROUTER_CAPABILITY_DATA);
export const VOLCENGINE_CAPABILITY: ProviderCapability = cloneProviderCapability(VOLCENGINE_CAPABILITY_DATA);

// 能力查询
export function getBackendCapability(name: ProviderBackendName): ProviderCapability {
  switch (name) {
    case 'anthropic': return cloneProviderCapability(ANTHROPIC_CAPABILITY_DATA);
    case 'azure': return cloneProviderCapability(AZURE_CAPABILITY_DATA);
    case 'gemini': return cloneProviderCapability(GEMINI_CAPABILITY_DATA);
    case 'kobold': return cloneProviderCapability(KOBOLD_CAPABILITY_DATA);
    case 'horde': return cloneProviderCapability(HORDE_CAPABILITY_DATA);
    case 'minimax': return cloneProviderCapability(MINIMAX_CAPABILITY_DATA);
    case 'nanogpt': return cloneProviderCapability(NANOGPT_CAPABILITY_DATA);
    case 'novelai': return cloneProviderCapability(NOVELAI_CAPABILITY_DATA);
    case 'openrouter': return cloneProviderCapability(OPENROUTER_CAPABILITY_DATA);
    case 'volcengine': return cloneProviderCapability(VOLCENGINE_CAPABILITY_DATA);
    default: throw new Error(`未知后端: ${name}`);
  }
}

function cloneProviderCapability(capability: ProviderCapability): ProviderCapability {
  return {
    provider: capability.provider,
    model: capability.model,
    supportsStreaming: capability.supportsStreaming,
    supportsSystemPrompt: capability.supportsSystemPrompt,
    supportsTools: capability.supportsTools,
    supportsReasoning: capability.supportsReasoning,
    supportsVisionInput: capability.supportsVisionInput,
    supportsImageOutput: capability.supportsImageOutput,
    supportsJsonSchema: capability.supportsJsonSchema,
    supportsLogprobs: capability.supportsLogprobs,
    supportsSeed: capability.supportsSeed,
    supportsStopStrings: capability.supportsStopStrings,
    supportsAssistantPrefill: capability.supportsAssistantPrefill,
    supportsTextCompletion: capability.supportsTextCompletion,
    supportsChatCompletion: capability.supportsChatCompletion,
    maxContext: capability.maxContext,
    tokenizer: capability.tokenizer,
  };
}

// ---- 各后端请求体类型 ----
export interface ProviderBackendMessage {
  role: string;
  content: string;
}

export interface GeminiPart {
  text: string;
}

export interface GeminiContent {
  role: string;
  parts: Array<GeminiPart>;
}

export interface GeminiSystemInstruction {
  parts: Array<GeminiPart>;
}

export interface GeminiGenerationConfig {
  temperature: number;
  maxOutputTokens: number;
  topP: number;
  stopSequences: Array<string>;
}

export interface ProviderBackendParameters {
  temperature: number;
  topP: number;
  topK: number;
  repetitionPenalty: number;
  maxTokens: number;
  stop: Array<string>;
  extraJson: string;
}

export interface OpenRouterProviderOptions {
  order: Array<string>;
  allowFallbacks: boolean;
}

export interface AnthropicRequest {
  model: string; max_tokens: number; system: string;
  messages: Array<ProviderBackendMessage>; stream: boolean;
}
export interface AzureRequest {
  messages: Array<ProviderBackendMessage>; model: string;
  stream: boolean; max_tokens: number;
}
export interface GeminiRequest {
  contents: Array<GeminiContent>;
  systemInstruction: GeminiSystemInstruction;
  generationConfig: GeminiGenerationConfig;
}
export interface KoboldRequest {
  prompt: string; max_length: number; temperature: number;
  top_p: number; rep_pen: number; stop_sequence: Array<string>;
}
export interface HordeRequest {
  prompt: string; params: ProviderBackendParameters; models: Array<string>;
}
export interface MiniMaxRequest {
  model: string; messages: Array<ProviderBackendMessage>;
  stream: boolean; max_tokens: number;
}
export interface NanoGPTRequest {
  prompt: string; max_tokens: number; temperature: number; stop: Array<string>;
}
export interface NovelAIRequest {
  input: string; model: string; parameters: ProviderBackendParameters;
}
export interface OpenRouterRequest {
  model: string; messages: Array<ProviderBackendMessage>;
  stream: boolean; max_tokens: number; provider: OpenRouterProviderOptions;
}
export interface VolcengineRequest {
  model: string; messages: Array<ProviderBackendMessage>;
  stream: boolean; max_tokens: number; parameters: ProviderBackendParameters;
}
