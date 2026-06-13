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
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
const AZURE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'azure', model: 'azure-openai',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: true, supportsLogprobs: true, supportsSeed: true,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 128000, tokenizer: 'openai',
};
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
const GEMINI_CAPABILITY_DATA: ProviderCapability = {
  provider: 'gemini', model: 'gemini',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: false, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: false, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 1000000, tokenizer: 'gemini',
};
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
const KOBOLD_CAPABILITY_DATA: ProviderCapability = {
  provider: 'kobold', model: 'kobold',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
const HORDE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'horde', model: 'horde',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
const MINIMAX_CAPABILITY_DATA: ProviderCapability = {
  provider: 'minimax', model: 'minimax',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 245760, tokenizer: 'llama',
};
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
const NANOGPT_CAPABILITY_DATA: ProviderCapability = {
  provider: 'nanogpt', model: 'nanogpt',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 4096, tokenizer: 'llama',
};
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
const NOVELAI_CAPABILITY_DATA: ProviderCapability = {
  provider: 'novelai', model: 'novelai',
  supportsStreaming: true, supportsSystemPrompt: false, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: true, supportsChatCompletion: false,
  maxContext: 8192, tokenizer: 'llama',
};
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
const OPENROUTER_CAPABILITY_DATA: ProviderCapability = {
  provider: 'openrouter', model: 'openrouter',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: true,
  supportsReasoning: true, supportsVisionInput: true, supportsImageOutput: false,
  supportsJsonSchema: true, supportsLogprobs: true, supportsSeed: true,
  supportsStopStrings: true, supportsAssistantPrefill: true,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 200000, tokenizer: 'openai',
};
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
const VOLCENGINE_CAPABILITY_DATA: ProviderCapability = {
  provider: 'volcengine', model: 'volcengine',
  supportsStreaming: true, supportsSystemPrompt: true, supportsTools: false,
  supportsReasoning: false, supportsVisionInput: false, supportsImageOutput: false,
  supportsJsonSchema: false, supportsLogprobs: false, supportsSeed: false,
  supportsStopStrings: true, supportsAssistantPrefill: false,
  supportsTextCompletion: false, supportsChatCompletion: true,
  maxContext: 32768, tokenizer: 'llama',
};

/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const ANTHROPIC_CAPABILITY: ProviderCapability = cloneProviderCapability(ANTHROPIC_CAPABILITY_DATA);
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const AZURE_CAPABILITY: ProviderCapability = cloneProviderCapability(AZURE_CAPABILITY_DATA);
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const GEMINI_CAPABILITY: ProviderCapability = cloneProviderCapability(GEMINI_CAPABILITY_DATA);
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const KOBOLD_CAPABILITY: ProviderCapability = cloneProviderCapability(KOBOLD_CAPABILITY_DATA);
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const HORDE_CAPABILITY: ProviderCapability = cloneProviderCapability(HORDE_CAPABILITY_DATA);
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const MINIMAX_CAPABILITY: ProviderCapability = cloneProviderCapability(MINIMAX_CAPABILITY_DATA);
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const NANOGPT_CAPABILITY: ProviderCapability = cloneProviderCapability(NANOGPT_CAPABILITY_DATA);
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const NOVELAI_CAPABILITY: ProviderCapability = cloneProviderCapability(NOVELAI_CAPABILITY_DATA);
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const OPENROUTER_CAPABILITY: ProviderCapability = cloneProviderCapability(OPENROUTER_CAPABILITY_DATA);
/**
 * 定义Provider 请求模块使用的固定配置值。
 */
export const VOLCENGINE_CAPABILITY: ProviderCapability = cloneProviderCapability(VOLCENGINE_CAPABILITY_DATA);

/**
 * 读取指定BackendCapability，不存在时抛出错误。
 * @param name 显示名称或注册名称。
 * @returns 更新或读取后的记录副本。
 */
export function getBackendCapability(name: ProviderBackendName): ProviderCapability {
  /**
   * 执行 switch 的内部处理步骤，供当前模块复用。
   */
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
 * 复制Provider Capability 值，避免外部修改内部状态。
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
  /**
   * role 值，由当前实例内部维护。
   */
  role: string;
  /**
   * 内容。
   */
  content: string;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface GeminiPart {
  /**
   * 文本内容。
   */
  text: string;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface GeminiContent {
  /**
   * role 值，由当前实例内部维护。
   */
  role: string;
  /**
   * 路径分段，由当前实例内部维护。
   */
  parts: Array<GeminiPart>;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface GeminiSystemInstruction {
  /**
   * 路径分段，由当前实例内部维护。
   */
  parts: Array<GeminiPart>;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface GeminiGenerationConfig {
  /**
   * temperature 值，由当前实例内部维护。
   */
  temperature: number;
  /**
   * max Output Tokens 列表，由当前实例内部维护。
   */
  maxOutputTokens: number;
  /**
   * top P 值，由当前实例内部维护。
   */
  topP: number;
  /**
   * stop Sequences 列表，由当前实例内部维护。
   */
  stopSequences: Array<string>;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface ProviderBackendParameters {
  /**
   * temperature 值，由当前实例内部维护。
   */
  temperature: number;
  /**
   * top P 值，由当前实例内部维护。
   */
  topP: number;
  /**
   * top K 值，由当前实例内部维护。
   */
  topK: number;
  /**
   * repetition Penalty 值，由当前实例内部维护。
   */
  repetitionPenalty: number;
  /**
   * max Tokens 列表，由当前实例内部维护。
   */
  maxTokens: number;
  /**
   * stop 值，由当前实例内部维护。
   */
  stop: Array<string>;
  /**
   * 扩展 JSON 字符串。
   */
  extraJson: string;
}

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
export interface OpenRouterProviderOptions {
  /**
   * order 值，由当前实例内部维护。
   */
  order: Array<string>;
  /**
   * allow Fallbacks 列表，由当前实例内部维护。
   */
  allowFallbacks: boolean;
}

/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface AnthropicRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string; max_tokens: number; system: string;
  /**
   * 消息列表。
   */
  messages: Array<ProviderBackendMessage>; stream: boolean;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface AzureRequest {
  /**
   * 消息列表。
   */
  messages: Array<ProviderBackendMessage>; model: string;
  /**
   * stream 值，由当前实例内部维护。
   */
  stream: boolean; max_tokens: number;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface GeminiRequest {
  /**
   * contents 列表，由当前实例内部维护。
   */
  contents: Array<GeminiContent>;
  /**
   * system Instruction 值，由当前实例内部维护。
   */
  systemInstruction: GeminiSystemInstruction;
  /**
   * generation Config 值，由当前实例内部维护。
   */
  generationConfig: GeminiGenerationConfig;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface KoboldRequest {
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string; max_length: number; temperature: number;
  /**
   * top p 值，由当前实例内部维护。
   */
  top_p: number; rep_pen: number; stop_sequence: Array<string>;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface HordeRequest {
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string; params: ProviderBackendParameters; models: Array<string>;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface MiniMaxRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string; messages: Array<ProviderBackendMessage>;
  /**
   * stream 值，由当前实例内部维护。
   */
  stream: boolean; max_tokens: number;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface NanoGPTRequest {
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string; max_tokens: number; temperature: number; stop: Array<string>;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface NovelAIRequest {
  /**
   * 输入数据。
   */
  input: string; model: string; parameters: ProviderBackendParameters;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface OpenRouterRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string; messages: Array<ProviderBackendMessage>;
  /**
   * stream 值，由当前实例内部维护。
   */
  stream: boolean; max_tokens: number; provider: OpenRouterProviderOptions;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface VolcengineRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string; messages: Array<ProviderBackendMessage>;
  /**
   * stream 值，由当前实例内部维护。
   */
  stream: boolean; max_tokens: number; parameters: ProviderBackendParameters;
}
