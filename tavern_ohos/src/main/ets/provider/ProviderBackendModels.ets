import type { ProviderCapability } from './ProviderModels';
import type { ChatMessageRole } from '../contracts/PublicContracts';

/**
 * Provider 后端名称的联合类型，标识支持的所有第三方供应商。
 */
export type ProviderBackendName =
  | 'anthropic' | 'azure' | 'gemini' | 'kobold' | 'horde'
  | 'minimax' | 'nanogpt' | 'novelai' | 'openrouter' | 'volcengine';

const ANTHROPIC_CAPABILITY_DATA: ProviderCapability = {
  provider: 'anthropic', model: 'claude',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: true, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: true,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 200000, tokenizer: 'claude',
};
/** Anthropic (Claude) 后端能力声明。 */
const AZURE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'azure', model: 'azure-openai',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: true, supportsLogprobs: true, supportsSeed: true,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 128000, tokenizer: 'openai',
};
/** Gemini 后端能力声明。 */
const GEMINI_CAPABILITY_DATA: ProviderCapability = {
  provider: 'gemini', model: 'gemini',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: false, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: false, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 1000000, tokenizer: 'gemini',
};
/** KoboldCpp 后端能力声明。 */
const KOBOLD_CAPABILITY_DATA: ProviderCapability = {
  provider: 'kobold', model: 'kobold',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
/** Horde 后端能力声明。 */
const HORDE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'horde', model: 'horde',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
/** MiniMax 后端能力声明。 */
const MINIMAX_CAPABILITY_DATA: ProviderCapability = {
  provider: 'minimax', model: 'minimax',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 245760, tokenizer: 'llama',
};
/** NanoGPT 后端能力声明。 */
const NANOGPT_CAPABILITY_DATA: ProviderCapability = {
  provider: 'nanogpt', model: 'nanogpt',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
/** NovelAI 后端能力声明。 */
const NOVELAI_CAPABILITY_DATA: ProviderCapability = {
  provider: 'novelai', model: 'novelai',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 8192, tokenizer: 'llama',
};
/** OpenRouter 后端能力声明。 */
const OPENROUTER_CAPABILITY_DATA: ProviderCapability = {
  provider: 'openrouter', model: 'openrouter',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: true, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: true, supportsLogprobs: true, supportsSeed: true,
  supportsStopStrings: true, supportsAssistantPrefill: true,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 200000, tokenizer: 'openai',
};
/** 火山引擎后端能力声明。 */
const VOLCENGINE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'volcengine', model: 'volcengine',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 32768, tokenizer: 'llama',
};

/** Anthropic (Claude) 后端能力的只读导出副本。 */
export const ANTHROPIC_CAPABILITY: ProviderCapability = cloneProviderCapability(ANTHROPIC_CAPABILITY_DATA);
/** Azure OpenAI 后端能力的只读导出副本。 */
export const AZURE_CAPABILITY: ProviderCapability = cloneProviderCapability(AZURE_CAPABILITY_DATA);
/** Gemini 后端能力的只读导出副本。 */
export const GEMINI_CAPABILITY: ProviderCapability = cloneProviderCapability(GEMINI_CAPABILITY_DATA);
/** KoboldCpp 后端能力的只读导出副本。 */
export const KOBOLD_CAPABILITY: ProviderCapability = cloneProviderCapability(KOBOLD_CAPABILITY_DATA);
/** Horde 后端能力的只读导出副本。 */
export const HORDE_CAPABILITY: ProviderCapability = cloneProviderCapability(HORDE_CAPABILITY_DATA);
/** MiniMax 后端能力的只读导出副本。 */
export const MINIMAX_CAPABILITY: ProviderCapability = cloneProviderCapability(MINIMAX_CAPABILITY_DATA);
/** NanoGPT 后端能力的只读导出副本。 */
export const NANOGPT_CAPABILITY: ProviderCapability = cloneProviderCapability(NANOGPT_CAPABILITY_DATA);
/** NovelAI 后端能力的只读导出副本。 */
export const NOVELAI_CAPABILITY: ProviderCapability = cloneProviderCapability(NOVELAI_CAPABILITY_DATA);
/** OpenRouter 后端能力的只读导出副本。 */
export const OPENROUTER_CAPABILITY: ProviderCapability = cloneProviderCapability(OPENROUTER_CAPABILITY_DATA);
/** 火山引擎后端能力的只读导出副本。 */
export const VOLCENGINE_CAPABILITY: ProviderCapability = cloneProviderCapability(VOLCENGINE_CAPABILITY_DATA);

/**
 * 根据后端名称获取对应的能力声明副本。
 * @param name 后端名称（如 'anthropic'、'azure'）。
 * @returns 能力声明对象的深拷贝副本，可安全修改。
 */
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

/**
 * 深拷贝 ProviderCapability 对象，防止外部篡改内部能力数据。
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

/**
 * 后端消息结构，包含角色和内容，用于构建各供应商 API 请求体。
 */
export interface ProviderBackendMessage {
  /**
   * 消息角色（user、assistant、system）。
   */
  role: ChatMessageRole;
  /**
   * 消息文本内容。
   */
  content: string;
}

/**
 * Gemini API 的 part 结构，表示单段文本内容。
 */
export interface GeminiPart {
  /**
   * 文本内容。
   */
  text: string;
}

/**
 * Gemini API 的 content 结构，包含角色和多个 part 列表。
 */
export interface GeminiContent {
  /**
   * 消息角色。
   */
  role: ChatMessageRole;
  /**
   * 内容分段列表。
   */
  parts: Array<GeminiPart>;
}

/**
 * Gemini API 的 systemInstruction 结构，包含系统提示词的 part 列表。
 */
export interface GeminiSystemInstruction {
  /**
   * 系统指令内容分段列表。
   */
  parts: Array<GeminiPart>;
}

/**
 * Gemini API 的 generationConfig 结构，控制生成参数。
 */
export interface GeminiGenerationConfig {
  /**
   * 采样温度。
   */
  temperature: number;
  /**
   * 最大输出 token 数。
   */
  maxOutputTokens: number;
  /**
   * top-p 采样值。
   */
  topP: number;
  /**
   * 停止序列列表。
   */
  stopSequences: Array<string>;
}

/**
 * 通用的后端采样参数集合，在不同供应商间共享。
 */
export interface ProviderBackendParameters {
  /**
   * 采样温度。
   */
  temperature: number;
  /**
   * top-p 采样值。
   */
  topP: number;
  /**
   * top-k 采样值。
   */
  topK: number;
  /**
   * 重复惩罚系数。
   */
  repetitionPenalty: number;
  /**
   * 最大生成 token 数。
   */
  maxTokens: number;
  /**
   * 停止字符串列表。
   */
  stop: Array<string>;
  /**
   * 扩展自定义参数的 JSON 字符串。
   */
  extraJson: string;
}

/**
 * OpenRouter 供应商路由选项。
 */
export interface OpenRouterProviderOptions {
  /**
   * 供应商优先级排序列表。
   */
  order: Array<string>;
  /**
   * 是否允许请求失败时回退到其他供应商。
   */
  allowFallbacks: boolean;
}

/**
 * Anthropic (Claude) API 的聊天补全请求体结构。
 */
export interface AnthropicRequest {
  /**
   * 模型名称。
   */
  model: string; max_tokens: number; system: string;
  /**
   * 对话消息列表。
   */
  messages: Array<ProviderBackendMessage>; stream: boolean;
}
/**
 * Azure OpenAI API 的聊天补全请求体结构。
 */
export interface AzureRequest {
  /**
   * 对话消息列表。
   */
  messages: Array<ProviderBackendMessage>; model: string;
  /**
   * 是否启用流式输出。
   */
  stream: boolean; max_tokens: number;
}
/**
 * Gemini API 的聊天补全请求体结构。
 */
export interface GeminiRequest {
  /**
   * 对话内容列表。
   */
  contents: Array<GeminiContent>;
  /**
   * 系统指令配置。
   */
  systemInstruction: GeminiSystemInstruction;
  /**
   * 生成参数配置。
   */
  generationConfig: GeminiGenerationConfig;
}
/**
 * KoboldCpp API 的文本补全请求体结构。
 */
export interface KoboldRequest {
  /**
   * 输入提示文本。
   */
  prompt: string; max_length: number; temperature: number;
  /**
   * top-p 采样值。
   */
  top_p: number; rep_pen: number; stop_sequence: Array<string>;
}
/**
 * Horde API 的文本补全请求体结构。
 */
export interface HordeRequest {
  /**
   * 输入提示文本。
   */
  prompt: string; params: ProviderBackendParameters; models: Array<string>;
}
/**
 * MiniMax API 的聊天补全请求体结构。
 */
export interface MiniMaxRequest {
  /**
   * 模型名称。
   */
  model: string; messages: Array<ProviderBackendMessage>;
  /**
   * 是否启用流式输出。
   */
  stream: boolean; max_tokens: number;
}
/**
 * NanoGPT API 的文本补全请求体结构。
 */
export interface NanoGPTRequest {
  /**
   * 输入提示文本。
   */
  prompt: string; max_tokens: number; temperature: number; stop: Array<string>;
}
/**
 * NovelAI API 的文本补全请求体结构。
 */
export interface NovelAIRequest {
  /**
   * 输入数据。
   */
  input: string; model: string; parameters: ProviderBackendParameters;
}
/**
 * OpenRouter API 的聊天补全请求体结构。
 */
export interface OpenRouterRequest {
  /**
   * 模型名称。
   */
  model: string; messages: Array<ProviderBackendMessage>;
  /**
   * 是否启用流式输出。
   */
  stream: boolean; max_tokens: number; provider: OpenRouterProviderOptions;
}
/**
 * 火山引擎 API 的聊天补全请求体结构。
 */
export interface VolcengineRequest {
  /**
   * 模型名称。
   */
  model: string; messages: Array<ProviderBackendMessage>;
  /**
   * 是否启用流式输出。
   */
  stream: boolean; max_tokens: number; parameters: ProviderBackendParameters;
}
