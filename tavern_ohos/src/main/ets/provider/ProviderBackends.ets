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
   * 根据入参构建Chat Request 值，仅生成数据结构，不直接执行外部请求。
   * @param model 模型名称。
   * @param maxTokens token 数量或 token 内容。

   * @param messages 消息列表。

   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildChatRequest(model: string, maxTokens: number, systemPrompt: string,
                   messages: Array<ProviderBackendMessage>, stream: boolean): AnthropicRequest {
    return { model, max_tokens: maxTokens, system: systemPrompt, messages, stream };
  }
}

// Azure OpenAI 后端
export class AzureBackend {
  /**
   * 根据入参构建Chat Request 值，仅生成数据结构，不直接执行外部请求。

   * @param messages 消息列表。

   * @param maxTokens token 数量或 token 内容。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  buildChatRequest(deployment: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number): AzureRequest {
    return { messages, model: deployment, stream, max_tokens: maxTokens };
  }
}

// Google Gemini 后端
export class GeminiBackend {
  /**
   * 根据入参构建Chat Request 值，仅生成数据结构，不直接执行外部请求。



   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 根据入参构建Text Request 值，仅生成数据结构，不直接执行外部请求。






   * @returns 构建好的请求、Prompt 或中间数据。
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
   * 根据入参构建Text Request 值，仅生成数据结构，不直接执行外部请求。

   * @param params 创建、更新或执行操作所需的参数对象。

   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildTextRequest(prompt: string, params: ProviderBackendParameters,
                   models: Array<string>): HordeRequest {
    return { prompt, params, models };
  }
}

// MiniMax 后端
export class MiniMaxBackend {
  /**
   * 根据入参构建Chat Request 值，仅生成数据结构，不直接执行外部请求。
   * @param model 模型名称。
   * @param messages 消息列表。

   * @param maxTokens token 数量或 token 内容。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number): MiniMaxRequest {
    return { model, messages, stream, max_tokens: maxTokens };
  }
}

// NanoGPT 后端
export class NanoGPTBackend {
  /**
   * 根据入参构建Text Request 值，仅生成数据结构，不直接执行外部请求。

   * @param maxTokens token 数量或 token 内容。


   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildTextRequest(prompt: string, maxTokens: number, temperature: number,
                   stop: Array<string>): NanoGPTRequest {
    return { prompt, max_tokens: maxTokens, temperature, stop };
  }
}

// NovelAI 后端
export class NovelAIBackend {
  /**
   * 根据入参构建Text Request 值，仅生成数据结构，不直接执行外部请求。
   * @param input 待处理的输入对象。
   * @param model 模型名称。

   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildTextRequest(input: string, model: string,
                   parameters: ProviderBackendParameters): NovelAIRequest {
    return { input, model, parameters };
  }
}

// OpenRouter 后端
export class OpenRouterBackend {
  /**
   * 根据入参构建Chat Request 值，仅生成数据结构，不直接执行外部请求。
   * @param model 模型名称。
   * @param messages 消息列表。

   * @param maxTokens token 数量或 token 内容。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 根据入参构建Chat Request 值，仅生成数据结构，不直接执行外部请求。
   * @param model 模型名称。
   * @param messages 消息列表。

   * @param maxTokens token 数量或 token 内容。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number,
                   parameters: ProviderBackendParameters): VolcengineRequest {
    return { model, messages, stream, max_tokens: maxTokens, parameters };
  }
}
