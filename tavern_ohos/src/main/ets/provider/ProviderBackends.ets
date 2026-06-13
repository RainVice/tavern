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
  buildChatRequest(model: string, maxTokens: number, systemPrompt: string,
                   messages: Array<ProviderBackendMessage>, stream: boolean): AnthropicRequest {
    return { model, max_tokens: maxTokens, system: systemPrompt, messages, stream };
  }
}

// Azure OpenAI 后端
export class AzureBackend {
  buildChatRequest(deployment: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number): AzureRequest {
    return { messages, model: deployment, stream, max_tokens: maxTokens };
  }
}

// Google Gemini 后端
export class GeminiBackend {
  buildChatRequest(contents: Array<GeminiContent>,
                   systemInstruction: GeminiSystemInstruction,
                   generationConfig: GeminiGenerationConfig): GeminiRequest {
    return { contents, systemInstruction, generationConfig };
  }
}

// Kobold / KoboldCpp 后端
export class KoboldBackend {
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
  buildTextRequest(prompt: string, params: ProviderBackendParameters,
                   models: Array<string>): HordeRequest {
    return { prompt, params, models };
  }
}

// MiniMax 后端
export class MiniMaxBackend {
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number): MiniMaxRequest {
    return { model, messages, stream, max_tokens: maxTokens };
  }
}

// NanoGPT 后端
export class NanoGPTBackend {
  buildTextRequest(prompt: string, maxTokens: number, temperature: number,
                   stop: Array<string>): NanoGPTRequest {
    return { prompt, max_tokens: maxTokens, temperature, stop };
  }
}

// NovelAI 后端
export class NovelAIBackend {
  buildTextRequest(input: string, model: string,
                   parameters: ProviderBackendParameters): NovelAIRequest {
    return { input, model, parameters };
  }
}

// OpenRouter 后端
export class OpenRouterBackend {
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number,
                   provider: OpenRouterProviderOptions): OpenRouterRequest {
    return { model, messages, stream, max_tokens: maxTokens, provider };
  }
}

// Volcengine / 火山引擎 后端
export class VolcengineBackend {
  buildChatRequest(model: string, messages: Array<ProviderBackendMessage>,
                   stream: boolean, maxTokens: number,
                   parameters: ProviderBackendParameters): VolcengineRequest {
    return { model, messages, stream, max_tokens: maxTokens, parameters };
  }
}
