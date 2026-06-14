import type {
  AnthropicRequest, AzureRequest, GeminiRequest,
  KoboldRequest, HordeRequest, MiniMaxRequest,
  NanoGPTRequest, NovelAIRequest, OpenRouterRequest,
  VolcengineRequest, ProviderBackendMessage, GeminiContent,
  GeminiSystemInstruction, GeminiGenerationConfig, ProviderBackendParameters,
  OpenRouterProviderOptions,
} from './ProviderBackendModels';

// Anthropic / Claude 后端
export class AnthropicBackend {
  /**
   * 构建 Anthropic (Claude) API 的聊天补全请求体。
   * @param model Anthropic 模型名称（如 "claude-sonnet-4"）。
   * @param maxTokens 生成的最大 token 数。
   * @param systemPrompt 系统提示词内容。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @returns Anthropic 格式的聊天补全请求体。
   */
  buildChatRequest(model: string, maxTokens: number, systemPrompt: string,
                   messages: Array<ProviderBackendMessage>, stream: boolean): AnthropicRequest {
    return { model, max_tokens: maxTokens, system: systemPrompt, messages, stream };
  }
}

// Azure OpenAI 后端
export class AzureBackend {
  /**
   * 构建 Azure OpenAI API 的聊天补全请求体。
   * @param deployment Azure 部署名称，作为 model 字段发送。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @param maxTokens 生成的最大 token 数。
   * @returns Azure OpenAI 格式的聊天补全请求体。
   */
  buildChatRequest(deployment: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number): AzureRequest {
    return { messages, model: deployment, stream, max_tokens: maxTokens };
  }
}

// Google Gemini 后端
export class GeminiBackend {
  /**
   * 构建 Google Gemini API 的聊天补全请求体。
   * @param contents 对话内容列表，包含角色和文本片段。
   * @param systemInstruction 系统指令。
   * @param generationConfig 生成配置参数（温度、maxTokens 等）。
   * @returns Gemini 格式的聊天补全请求体。
   */
  buildChatRequest(contents: Array<GeminiContent>,
                   systemInstruction: GeminiSystemInstruction,
                   generationConfig: GeminiGenerationConfig): GeminiRequest {
    return { contents, systemInstruction, generationConfig };
  }
}

// Kobold / KoboldCpp 后端
export class KoboldBackend {
  /**
   * 构建 Kobold/KoboldCpp API 的文本补全请求体。
   * @param prompt 提示词文本。
   * @param maxLength 生成的最大 token 数。
   * @param temperature 温度参数。
   * @param topP Top-P 采样参数。
   * @param repPen 重复惩罚系数。
   * @param stopSequences 停止字符串列表。
   * @returns Kobold 格式的文本补全请求体。
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

// Horde 后端
export class HordeBackend {
  /**
   * 构建 Horde API 的文本补全请求体。
   * @param prompt 提示词文本。
   * @param params 后端参数集合，包含温度、采样参数和停止字符串。
   * @param models 请求使用的模型列表。
   * @returns Horde 格式的文本补全请求体。
   */
  buildTextRequest(prompt: string, params: ProviderBackendParameters,
                   models: Array<string>): HordeRequest {
    return { prompt, params, models };
  }
}

// MiniMax 后端
export class MiniMaxBackend {
  /**
   * 构建 MiniMax API 的聊天补全请求体。
   * @param model 模型名称。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @param maxTokens 生成的最大 token 数。
   * @returns MiniMax 格式的聊天补全请求体。
   */
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number): MiniMaxRequest {
    return { model, messages, stream, max_tokens: maxTokens };
  }
}

// NanoGPT 后端
export class NanoGPTBackend {
  /**
   * 构建 NanoGPT API 的文本补全请求体。
   * @param prompt 提示词文本。
   * @param maxTokens 生成的最大 token 数。
   * @param temperature 温度参数。
   * @param stop 停止字符串列表。
   * @returns NanoGPT 格式的文本补全请求体。
   */
  buildTextRequest(prompt: string, maxTokens: number, temperature: number,
                   stop: Array<string>): NanoGPTRequest {
    return { prompt, max_tokens: maxTokens, temperature, stop };
  }
}

// NovelAI 后端
export class NovelAIBackend {
  /**
   * 构建 NovelAI API 的文本补全请求体。
   * @param input 输入文本。
   * @param model 模型名称。
   * @param parameters 后端参数集合，包含采样和生成参数。
   * @returns NovelAI 格式的文本补全请求体。
   */
  buildTextRequest(input: string, model: string,
                   parameters: ProviderBackendParameters): NovelAIRequest {
    return { input, model, parameters };
  }
}

// OpenRouter 后端
export class OpenRouterBackend {
  /**
   * 构建 OpenRouter API 的聊天补全请求体。
   * @param model 模型名称。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @param maxTokens 生成的最大 token 数。
   * @param provider 路由提供商选项，控制模型回退策略。
   * @returns OpenRouter 格式的聊天补全请求体。
   */
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number,
                   provider: OpenRouterProviderOptions): OpenRouterRequest {
    return { model, messages, stream, max_tokens: maxTokens, provider };
  }
}

// Volcengine / 火山引擎 后端
export class VolcengineBackend {
  /**
   * 构建火山引擎 API 的聊天补全请求体。
   * @param model 模型名称。
   * @param messages 对话历史消息列表。
   * @param stream 是否启用流式输出。
   * @param maxTokens 生成的最大 token 数。
   * @param parameters 后端参数集合，包含采样和生成参数。
   * @returns 火山引擎格式的聊天补全请求体。
   */
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number,
                   parameters: ProviderBackendParameters): VolcengineRequest {
    return { model, messages, stream, max_tokens: maxTokens, parameters };
  }
}
