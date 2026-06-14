import type { ProviderCapability } from './ProviderModels';

// 后端名称联合类型
export type ProviderBackendName =
  | 'anthropic' | 'azure' | 'gemini' | 'kobold' | 'horde'
  | 'minimax' | 'nanogpt' | 'novelai' | 'openrouter' | 'volcengine';

// ---- 各后端能力声明数据 ----
const ANTHROPIC_CAPABILITY_DATA: ProviderCapability = {
  provider: 'anthropic', model: 'claude',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: true, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: true,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 200000, tokenizer: 'claude',
};
/** Anthropic (Claude) 后端的固定能力声明。 */
const AZURE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'azure', model: 'azure-openai',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: true, supportsLogprobs: true, supportsSeed: true,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 128000, tokenizer: 'openai',
};
/** Azure OpenAI 后端的固定能力声明。 */
const GEMINI_CAPABILITY_DATA: ProviderCapability = {
  provider: 'gemini', model: 'gemini',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: false, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: false, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 1000000, tokenizer: 'gemini',
};
/** Google Gemini 后端的固定能力声明。 */
const KOBOLD_CAPABILITY_DATA: ProviderCapability = {
  provider: 'kobold', model: 'kobold',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
/** Kobold/KoboldCpp 后端的固定能力声明。 */
const HORDE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'horde', model: 'horde',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
/** Horde 后端的固定能力声明。 */
const MINIMAX_CAPABILITY_DATA: ProviderCapability = {
  provider: 'minimax', model: 'minimax',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 245760, tokenizer: 'llama',
};
/** MiniMax 后端的固定能力声明。 */
const NANOGPT_CAPABILITY_DATA: ProviderCapability = {
  provider: 'nanogpt', model: 'nanogpt',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
/** NanoGPT 后端的固定能力声明。 */
const NOVELAI_CAPABILITY_DATA: ProviderCapability = {
  provider: 'novelai', model: 'novelai',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 8192, tokenizer: 'llama',
};
/** NovelAI 后端的固定能力声明。 */
const OPENROUTER_CAPABILITY_DATA: ProviderCapability = {
  provider: 'openrouter', model: 'openrouter',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: true, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: true, supportsLogprobs: true, supportsSeed: true,
  supportsStopStrings: true, supportsAssistantPrefill: true,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 200000, tokenizer: 'openai',
};
/** OpenRouter 后端的固定能力声明。 */
const VOLCENGINE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'volcengine', model: 'volcengine',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 32768, tokenizer: 'llama',
};
/** 火山引擎后端的固定能力声明。 */

/** Anthropic 后端公开的能力声明（只读副本）。 */
export const ANTHROPIC_CAPABILITY: ProviderCapability = cloneProviderCapability(ANTHROPIC_CAPABILITY_DATA);
/** Azure OpenAI 后端公开的能力声明（只读副本）。 */
export const AZURE_CAPABILITY: ProviderCapability = cloneProviderCapability(AZURE_CAPABILITY_DATA);
/** Google Gemini 后端公开的能力声明（只读副本）。 */
export const GEMINI_CAPABILITY: ProviderCapability = cloneProviderCapability(GEMINI_CAPABILITY_DATA);
/** Kobold/KoboldCpp 后端公开的能力声明（只读副本）。 */
export const KOBOLD_CAPABILITY: ProviderCapability = cloneProviderCapability(KOBOLD_CAPABILITY_DATA);
/** Horde 后端公开的能力声明（只读副本）。 */
export const HORDE_CAPABILITY: ProviderCapability = cloneProviderCapability(HORDE_CAPABILITY_DATA);
/** MiniMax 后端公开的能力声明（只读副本）。 */
export const MINIMAX_CAPABILITY: ProviderCapability = cloneProviderCapability(MINIMAX_CAPABILITY_DATA);
/** NanoGPT 后端公开的能力声明（只读副本）。 */
export const NANOGPT_CAPABILITY: ProviderCapability = cloneProviderCapability(NANOGPT_CAPABILITY_DATA);
/** NovelAI 后端公开的能力声明（只读副本）。 */
export const NOVELAI_CAPABILITY: ProviderCapability = cloneProviderCapability(NOVELAI_CAPABILITY_DATA);
/** OpenRouter 后端公开的能力声明（只读副本）。 */
export const OPENROUTER_CAPABILITY: ProviderCapability = cloneProviderCapability(OPENROUTER_CAPABILITY_DATA);
/** 火山引擎后端公开的能力声明（只读副本）。 */
export const VOLCENGINE_CAPABILITY: ProviderCapability = cloneProviderCapability(VOLCENGINE_CAPABILITY_DATA);

/**
 * 根据后端名称获取其能力声明的只读副本。
 * @param name 后端名称，取值范围为 ProviderBackendName。
 * @returns 对应后端的能力声明副本。
 */
export function getBackendCapability(name: ProviderBackendName): ProviderCapability {
  // 根据后端名称路由到对应的能力数据
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

/**
 * 创建 ProviderCapability 的浅拷贝，防止外部代码修改内部常量数据。
 */
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
  /** 消息角色：如 "user"、"assistant"、"system"。 */
  role: string;
  /** 消息文本内容。 */
  content: string;
}

/** Gemini API 中的 Part 结构，表示多模态内容的一个片段。 */
export interface GeminiPart {
  /** 文本内容。 */
  text: string;
}

/** Gemini API 中的 Content 结构，表示一段带有角色的对话内容。 */
export interface GeminiContent {
  /** 该段内容的角色：如 "user"、"model"。 */
  role: string;
  /** 内容片段列表。 */
  parts: Array<GeminiPart>;
}

/** Gemini API 中的 SystemInstruction 结构，表示系统指令。 */
export interface GeminiSystemInstruction {
  /** 系统指令的内容片段列表。 */
  parts: Array<GeminiPart>;
}

/** Gemini API 中的 GenerationConfig 结构，控制文本生成参数。 */
export interface GeminiGenerationConfig {
  /** 采样温度参数。 */
  temperature: number;
  /** 生成的最大 token 数。 */
  maxOutputTokens: number;
  /** Top-P 采样参数。 */
  topP: number;
  /** 停止字符串列表。 */
  stopSequences: Array<string>;
}

/** 通用后端参数集合，用于 Kobold/Horde/NovelAI/火山引擎等后端。 */
export interface ProviderBackendParameters {
  /** 采样温度参数。 */
  temperature: number;
  /** Top-P 采样参数。 */
  topP: number;
  /** Top-K 采样参数，限制到概率最高的 K 个 token。 */
  topK: number;
  /** 重复惩罚系数，降低已生成 token 的重复概率。 */
  repetitionPenalty: number;
  /** 生成的最大 token 数。 */
  maxTokens: number;
  /** 停止字符串列表。 */
  stop: Array<string>;
  /** 扩展配置的 JSON 字符串，用于传递后端特有参数。 */
  extraJson: string;
}

/** OpenRouter 后端的 Provider 选项，控制模型路由策略。 */
export interface OpenRouterProviderOptions {
  /** 排序列表，指定模型提供商的优先级。 */
  order: Array<string>;
  /** 是否允许在首选提供商不可用时回退到其他提供商。 */
  allowFallbacks: boolean;
}

/** Anthropic (Claude) API 的聊天补全请求体结构。 */
export interface AnthropicRequest {
  /** 模型名称。 */
  model: string;
  /** 生成的最大 token 数。 */
  max_tokens: number;
  /** 系统提示词。 */
  system: string;
  /** 对话消息列表。 */
  messages: Array<ProviderBackendMessage>;
  /** 是否启用流式输出。 */
  stream: boolean;
}
/** Azure OpenAI API 的聊天补全请求体结构。 */
export interface AzureRequest {
  /** 消息列表。 */
  messages: Array<ProviderBackendMessage>;
  /** 部署名称。 */
  model: string;
  /** 是否启用流式输出。 */
  stream: boolean;
  /** 生成的最大 token 数。 */
  max_tokens: number;
}
/** Google Gemini API 的聊天补全请求体结构。 */
export interface GeminiRequest {
  /** 对话内容列表。 */
  contents: Array<GeminiContent>;
  /** 系统指令。 */
  systemInstruction: GeminiSystemInstruction;
  /** 生成配置参数。 */
  generationConfig: GeminiGenerationConfig;
}
/** Kobold/KoboldCpp API 的文本补全请求体结构。 */
export interface KoboldRequest {
  /** 提示词文本。 */
  prompt: string;
  /** 生成的最大 token 数。 */
  max_length: number;
  /** 温度参数。 */
  temperature: number;
  /** Top-P 采样参数。 */
  top_p: number;
  /** 重复惩罚系数。 */
  rep_pen: number;
  /** 停止字符串列表。 */
  stop_sequence: Array<string>;
}
/** Horde API 的文本补全请求体结构。 */
export interface HordeRequest {
  /** 提示词文本。 */
  prompt: string;
  /** 后端参数集合。 */
  params: ProviderBackendParameters;
  /** 请求使用的模型列表。 */
  models: Array<string>;
}
/** MiniMax API 的聊天补全请求体结构。 */
export interface MiniMaxRequest {
  /** 模型名称。 */
  model: string;
  /** 对话消息列表。 */
  messages: Array<ProviderBackendMessage>;
  /** 是否启用流式输出。 */
  stream: boolean;
  /** 生成的最大 token 数。 */
  max_tokens: number;
}
/** NanoGPT API 的文本补全请求体结构。 */
export interface NanoGPTRequest {
  /** 提示词文本。 */
  prompt: string;
  /** 生成的最大 token 数。 */
  max_tokens: number;
  /** 温度参数。 */
  temperature: number;
  /** 停止字符串列表。 */
  stop: Array<string>;
}
/** NovelAI API 的文本补全请求体结构。 */
export interface NovelAIRequest {
  /** 输入文本。 */
  input: string;
  /** 模型名称。 */
  model: string;
  /** 后端参数集合。 */
  parameters: ProviderBackendParameters;
}
/** OpenRouter API 的聊天补全请求体结构。 */
export interface OpenRouterRequest {
  /** 模型名称。 */
  model: string;
  /** 对话消息列表。 */
  messages: Array<ProviderBackendMessage>;
  /** 是否启用流式输出。 */
  stream: boolean;
  /** 生成的最大 token 数。 */
  max_tokens: number;
  /** 路由提供商选项。 */
  provider: OpenRouterProviderOptions;
}
/** 火山引擎 API 的聊天补全请求体结构。 */
export interface VolcengineRequest {
  /** 模型名称。 */
  model: string;
  /** 对话消息列表。 */
  messages: Array<ProviderBackendMessage>;
  /** 是否启用流式输出。 */
  stream: boolean;
  /** 生成的最大 token 数。 */
  max_tokens: number;
  /** 后端参数集合。 */
  parameters: ProviderBackendParameters;
}
