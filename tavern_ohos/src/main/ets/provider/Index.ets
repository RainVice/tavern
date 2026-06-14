/**
 * Provider 模块统一导出入口。
 *
 * 公开以下能力：
 * - OpenAICompatibleNormalizer：OpenAI 兼容格式的流式响应归一化工具
 * - OpenAIOhosProviderStreamSource：基于 openai_ohos 库的 OpenAI 兼容流式请求源
 * - ProviderRuntime：Provider 流式请求的无 UI 运行时，管理任务生命周期和事件发布
 * - ProviderSSEParser：SSE (Server-Sent Events) 协议解析器
 *
 * 导出的类型：
 * - ProviderModels：核心运行时数据结构，包括能力声明、消息、请求体、流式任务等
 * - ProviderBackendModels：各后端（Anthropic/Azure/Gemini/Kobold 等）的请求体类型
 * - ProviderBackends：各后端的请求构建器类
 */
export { OpenAICompatibleNormalizer } from './OpenAICompatibleNormalizer';
export { OpenAIOhosProviderStreamSource } from './OpenAIOhosProviderSource';
export { ProviderRuntime } from './ProviderRuntime';
export { ProviderSSEParser } from './ProviderSSEParser';
export type { OpenAIOhosProviderStreamSourceOptions } from './OpenAIOhosProviderSource';
export type {
  OpenAICompatibleChatChoice,
  OpenAICompatibleChatChunk,
  OpenAICompatibleChatDelta,
  ProviderCapability,
  ProviderChatMessage,
  ProviderGenerationPayload,
  ProviderNormalizedChunk,
  ProviderSSEEvent,
  ProviderStreamHandle,
  ProviderStreamRequest,
  ProviderStreamSink,
  ProviderStreamSource,
  ProviderStreamStartParams,
  ProviderStreamTask,
  ProviderTextCompletionBody,
  ProviderTextCompletionBuildParams,
  ProviderTextCompletionOptions,
  ProviderTextCompletionRequest,
} from './ProviderModels';

export type {
  AnthropicRequest, AzureRequest, GeminiRequest, KoboldRequest, HordeRequest,
  MiniMaxRequest, NanoGPTRequest, NovelAIRequest, OpenRouterRequest, VolcengineRequest,
  ProviderBackendName,
} from './ProviderBackendModels';
export {
  ANTHROPIC_CAPABILITY,
  AZURE_CAPABILITY,
  GEMINI_CAPABILITY,
  KOBOLD_CAPABILITY,
  HORDE_CAPABILITY,
  MINIMAX_CAPABILITY,
  NANOGPT_CAPABILITY,
  NOVELAI_CAPABILITY,
  OPENROUTER_CAPABILITY,
  VOLCENGINE_CAPABILITY,
  getBackendCapability,
} from './ProviderBackendModels';
export {
  AnthropicBackend, AzureBackend, GeminiBackend, KoboldBackend, HordeBackend,
  MiniMaxBackend, NanoGPTBackend, NovelAIBackend, OpenRouterBackend, VolcengineBackend,
} from './ProviderBackends';
