import type {
  AnthropicRequest, AzureRequest, GeminiRequest,
  KoboldRequest, HordeRequest, MiniMaxRequest,
  NanoGPTRequest, NovelAIRequest, OpenRouterRequest,
  VolcengineRequest, ProviderBackendMessage, GeminiContent,
  GeminiSystemInstruction, GeminiGenerationConfig, ProviderBackendParameters,
  OpenRouterProviderOptions,
} from './ProviderBackendModels';

// Anthropic (Claude) 后端：构建聊天补全请求体
export class AnthropicBackend {
  /**
   * 构建 Anthropic API 的聊天补全请求体。
   * @param model 模型名称（如 'claude-sonnet-4-20250514'）。
   * @param maxTokens 最大生成 token 数。
   * @param systemPrompt 系统提示词内容。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @returns Anthropic 格式的请求对象。
   */
  buildChatRequest(model: string, maxTokens: number, systemPrompt: string,
                   messages: Array<ProviderBackendMessage>, stream: boolean): AnthropicRequest {
    return { model, max_tokens: maxTokens, system: systemPrompt, messages, stream };
  }
}

// Azure OpenAI 后端：构建聊天补全请求体
export class AzureBackend {
  /**
   * 构建 Azure OpenAI API 的聊天补全请求体。
   * @param deployment 部署名称（对应 Azure 上的模型部署）。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @param maxTokens 最大生成 token 数。
   * @returns Azure OpenAI 格式的请求对象。
   */
  buildChatRequest(deployment: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number): AzureRequest {
    return { messages, model: deployment, stream, max_tokens: maxTokens };
  }
}

// Google Gemini 后端：构建聊天补全请求体
export class GeminiBackend {
  /**
   * 构建 Gemini API 的聊天补全请求体。
   * @param contents 对话内容，按 Gemini 格式组织的 part 列表。
   * @param systemInstruction 系统指令配置。
   * @param generationConfig 生成参数配置（温度、maxTokens 等）。
   * @returns Gemini 格式的请求对象。
   */
  buildChatRequest(contents: Array<GeminiContent>,
                   systemInstruction: GeminiSystemInstruction,
                   generationConfig: GeminiGenerationConfig): GeminiRequest {
    return { contents, systemInstruction, generationConfig };
  }
}

// KoboldCpp 后端：构建文本补全请求体
export class KoboldBackend {
  /**
   * 构建 KoboldCpp API 的文本补全请求体。
   * @param prompt 输入提示文本。
   * @param maxLength 最大生成 token 数。
   * @param temperature 采样温度。
   * @param topP top-p 采样值。
   * @param repPen 重复惩罚系数。
   * @param stopSequences 停止序列列表。
   * @returns KoboldCpp 格式的请求对象。
   */
  buildTextRequest(prompt: string, maxLength: number, temperature: number,
                   topP: number, repPen: number,
                   stopSequences: Array<string>): KoboldRequest {
    return {
      prompt, max_length: maxLength, temperature,
      top_p: topP, rep_pen: repPen, stop_sequence: stopSequences,
    };
  }
}

// Horde 后端：构建文本补全请求体
export class HordeBackend {
  /**
   * 构建 Horde API 的文本补全请求体。
   * @param prompt 输入提示文本。
   * @param params 后端采样参数集合。
   * @param models 可选模型列表。
   * @returns Horde 格式的请求对象。
   */
  buildTextRequest(prompt: string, params: ProviderBackendParameters,
                   models: Array<string>): HordeRequest {
    return { prompt, params, models };
  }
}

// MiniMax 后端：构建聊天补全请求体
export class MiniMaxBackend {
  /**
   * 构建 MiniMax API 的聊天补全请求体。
   * @param model 模型名称。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @param maxTokens 最大生成 token 数。
   * @returns MiniMax 格式的请求对象。
   */
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number): MiniMaxRequest {
    return { model, messages, stream, max_tokens: maxTokens };
  }
}

// NanoGPT 后端：构建文本补全请求体
export class NanoGPTBackend {
  /**
   * 构建 NanoGPT API 的文本补全请求体。
   * @param prompt 输入提示文本。
   * @param maxTokens 最大生成 token 数。
   * @param temperature 采样温度。
   * @param stop 停止字符串列表。
   * @returns NanoGPT 格式的请求对象。
   */
  buildTextRequest(prompt: string, maxTokens: number, temperature: number,
                   stop: Array<string>): NanoGPTRequest {
    return { prompt, max_tokens: maxTokens, temperature, stop };
  }
}

// NovelAI 后端：构建文本补全请求体
export class NovelAIBackend {
  /**
   * 构建 NovelAI API 的文本补全请求体。
   * @param input 输入文本。
   * @param model 模型名称。
   * @param parameters 后端采样参数集合。
   * @returns NovelAI 格式的请求对象。
   */
  buildTextRequest(input: string, model: string,
                   parameters: ProviderBackendParameters): NovelAIRequest {
    return { input, model, parameters };
  }
}

// OpenRouter 后端：构建聊天补全请求体
export class OpenRouterBackend {
  /**
   * 构建 OpenRouter API 的聊天补全请求体。
   * @param model 模型名称。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @param maxTokens 最大生成 token 数。
   * @param provider OpenRouter 供应商路由选项。
   * @returns OpenRouter 格式的请求对象。
   */
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number,
                   provider: OpenRouterProviderOptions): OpenRouterRequest {
    return { model, messages, stream, max_tokens: maxTokens, provider };
  }
}

// 火山引擎后端：构建聊天补全请求体
export class VolcengineBackend {
  /**
   * 构建火山引擎 API 的聊天补全请求体。
   * @param model 模型名称。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @param maxTokens 最大生成 token 数。
   * @param parameters 后端采样参数集合。
   * @returns 火山引擎格式的请求对象。
   */
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number,
                   parameters: ProviderBackendParameters): VolcengineRequest {
    return { model, messages, stream, max_tokens: maxTokens, parameters };
  }
}
