/**
 * 公共合约定义文件。集中管理整个 Tavern 运行时中用到的枚举常量、类型别名、字符串字面量类型和工具类。
 * 所有 export 项可在运行时任意阶段引用，作为数据格式和标识符的标准化基准。
 */

/**
 * 描述全局作用域标识。调用方可以使用内置常量，也可以传入宿主自定义作用域。
 */
export type TavernScope = string;

/**
 * 描述常见作用域常量。
 */
export interface TavernScopeConstants {
  GLOBAL: string;
  USER: string;
  CHARACTER: string;
  PERSONA: string;
  CHAT: string;
  GROUP: string;
  MESSAGE: string;
  PROFILE: string;
  PLUGIN: string;
  TEMPORARY: string;
  PIPE: string;
  RESOLVED: string;
}

export const TavernScopes: TavernScopeConstants = {
  GLOBAL: 'global',
  USER: 'user',
  CHARACTER: 'character',
  PERSONA: 'persona',
  CHAT: 'chat',
  GROUP: 'group',
  MESSAGE: 'message',
  PROFILE: 'profile',
  PLUGIN: 'plugin',
  TEMPORARY: 'temporary',
  PIPE: 'pipe',
  RESOLVED: 'resolved',
};

/**
 * 描述聊天消息角色。
 */
/**
 * 描述聊天消息角色的字符串字面量类型。固定为 'system'|'user'|'assistant'|'tool'|'function' 五选一。
 */
export type ChatMessageRole = 'system' | 'user' | 'assistant' | 'tool' | 'function';

/**
 * 定义聊天消息角色常量集合的接口。消费方可直接引用此接口声明的属性名称。
 */
export interface ChatMessageRoleConstants {
  SYSTEM: ChatMessageRole;
  USER: ChatMessageRole;
  ASSISTANT: ChatMessageRole;
  TOOL: ChatMessageRole;
  FUNCTION: ChatMessageRole;
}

/**
 * 聊天消息角色常量值。SYSTEM 系统 / USER 用户 / ASSISTANT 助手 / TOOL 工具 / FUNCTION 函数。
 */
export const ChatMessageRoles: ChatMessageRoleConstants = {
  SYSTEM: 'system',
  USER: 'user',
  ASSISTANT: 'assistant',
  TOOL: 'tool',
  FUNCTION: 'function',
};

/**
 * 描述群聊成员角色。该字段允许宿主扩展自定义群成员角色。
 */
export type GroupMemberRole = string;

/**
 * 群聊成员角色常量集合接口。成员在群组中扮演的角色枚举。
 */
export interface GroupMemberRoleConstants {
  SPEAKER: string;
  LISTENER: string;
  MODERATOR: string;
}

/**
 * 群聊成员角色常量集合。`SPEAKER` 可发言，`LISTENER` 仅旁听，`MODERATOR` 可管理发言权。
 */
export const GroupMemberRoles: GroupMemberRoleConstants = {
  SPEAKER: 'speaker',
  LISTENER: 'listener',
  MODERATOR: 'moderator',
};

/**
 * 描述运行时任务类型。该字段允许宿主扩展自定义任务类型。
 */
export type RuntimeTaskType = string;

/**
 * 描述运行时通用任务状态。
 */
/**
 * 运行时通用任务状态的字符串字面量类型。生命周期：pending -> running -> completed/failed/cancelled/aborted。
 */
export type RuntimeTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled' | 'aborted';

/**
 * 运行时通用任务状态常量集合接口。消费方可通过属性名引用状态字符串，避免拼写错误。
 */
export interface RuntimeTaskStatusConstants {
  PENDING: RuntimeTaskStatus;
  RUNNING: RuntimeTaskStatus;
  COMPLETED: RuntimeTaskStatus;
  FAILED: RuntimeTaskStatus;
  CANCELLED: RuntimeTaskStatus;
  ABORTED: RuntimeTaskStatus;
}

/**
 * 运行时通用任务状态常量集合。PENDING 等待中 / RUNNING 运行中 / COMPLETED 已完成 / FAILED 失败 / CANCELLED 已取消 / ABORTED 已终止。
 */
export const RuntimeTaskStatuses: RuntimeTaskStatusConstants = {
  PENDING: 'pending',
  RUNNING: 'running',
  COMPLETED: 'completed',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
  ABORTED: 'aborted',
};

/**
 * 可公开使用的通用异步任务状态常量集合。派生类（ASR、Caption、ImageGeneration、TTS、Translation）共用此结构。
 */
export interface AsyncTaskStatusConstants {
  PENDING: 'pending';
  RUNNING: 'running';
  COMPLETED: 'completed';
  FAILED: 'failed';
  CANCELLED: 'cancelled';
}

/**
 * 通用异步任务状态常量值。PENDING/RUNNING/COMPLETED/FAILED/CANCELLED 五态，
 * 直接复用为 ASR、Caption、ImageGeneration、TTS、Translation 等子模块的状态集。
 */
export const AsyncTaskStatuses: AsyncTaskStatusConstants = {
  PENDING: 'pending',
  RUNNING: 'running',
  COMPLETED: 'completed',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
};

/**
 * ASR（语音识别）任务状态的类型别名，直接复用通用异步任务状态。
 */
export type ASRTaskStatusConstants = AsyncTaskStatusConstants;

/**
 * ASR 任务状态常量，直接引用通用异步任务状态值。
 */
export const ASRTaskStatuses: ASRTaskStatusConstants = AsyncTaskStatuses;

/**
 * Caption（图片理解）任务状态的类型别名，直接复用通用异步任务状态。
 */
export type CaptionTaskStatusConstants = AsyncTaskStatusConstants;

/**
 * Caption 任务状态常量，直接引用通用异步任务状态值。
 */
export const CaptionTaskStatuses: CaptionTaskStatusConstants = AsyncTaskStatuses;

/**
 * ImageGeneration（图片生成）任务状态的类型别名，直接复用通用异步任务状态。
 */
export type ImageGenerationStatusConstants = AsyncTaskStatusConstants;

/**
 * ImageGeneration 任务状态常量，直接引用通用异步任务状态值。
 */
export const ImageGenerationStatuses: ImageGenerationStatusConstants = AsyncTaskStatuses;

/**
 * TTS（文本转语音）任务状态的类型别名，直接复用通用异步任务状态。
 */
export type TTSTaskStatusConstants = AsyncTaskStatusConstants;

/**
 * TTS 任务状态常量，直接引用通用异步任务状态值。
 */
export const TTSTaskStatuses: TTSTaskStatusConstants = AsyncTaskStatuses;

/**
 * Translation（翻译）任务状态的类型别名，直接复用通用异步任务状态。
 */
export type TranslationTaskStatusConstants = AsyncTaskStatusConstants;

/**
 * Translation 任务状态常量，直接引用通用异步任务状态值。
 */
export const TranslationTaskStatuses: TranslationTaskStatusConstants = AsyncTaskStatuses;

/**
 * 描述流式会话状态。
 */
export type StreamSessionStatus = 'running' | 'completed' | 'aborted';

/**
 * 流式会话状态常量集合接口。running 运行中 / completed 已完成 / aborted 已终止。
 */
export interface StreamSessionStatusConstants {
  RUNNING: StreamSessionStatus;
  COMPLETED: StreamSessionStatus;
  ABORTED: StreamSessionStatus;
}

/**
 * 流式会话状态常量值。RUNNING 运行中 / COMPLETED 已完成 / ABORTED 已终止。
 */
export const StreamSessionStatuses: StreamSessionStatusConstants = {
  RUNNING: 'running',
  COMPLETED: 'completed',
  ABORTED: 'aborted',
};

/**
 * 描述 OpenAI-compatible 文本补全 API 类型。该字段允许宿主扩展自定义类型。
 */
export type ConnectionApiType = string;

/**
 * OpenAI-compatible 文本补全 API 类型常量集合接口。涵盖 OpenAI、Ollama、vLLM、KoboldCPP 等后端枚举值。
 */
export interface ConnectionApiTypeConstants {
  OPENAI: string;
  OPENAI_COMPATIBLE: string;
  GENERIC: string;
  OPENROUTER: string;
  OLLAMA: string;
  DREAMGEN: string;
  MANCER: string;
  LLAMACPP: string;
  VLLM: string;
  TOGETHERAI: string;
  INFERMATICAI: string;
  FEATHERLESS: string;
  APHRODITE: string;
  TABBY: string;
  OOBA: string;
  KOBOLDCPP: string;
  HUGGINGFACE: string;
}

/**
 * 连接 API 类型常量值。消费方用于配置不同的 LLM 后端，每个值对应一种服务端兼容协议。
 */
export const ConnectionApiTypes: ConnectionApiTypeConstants = {
  OPENAI: 'openai',
  OPENAI_COMPATIBLE: 'openai-compatible',
  GENERIC: 'generic',
  OPENROUTER: 'openrouter',
  OLLAMA: 'ollama',
  DREAMGEN: 'dreamgen',
  MANCER: 'mancer',
  LLAMACPP: 'llamacpp',
  VLLM: 'vllm',
  TOGETHERAI: 'togetherai',
  INFERMATICAI: 'infermaticai',
  FEATHERLESS: 'featherless',
  APHRODITE: 'aphrodite',
  TABBY: 'tabby',
  OOBA: 'ooba',
  KOBOLDCPP: 'koboldcpp',
  HUGGINGFACE: 'huggingface',
};

/**
 * 描述上游 Provider 标识。该字段允许宿主扩展自定义 Provider。
 */
export type ProviderId = string;

/**
 * 上游 Provider 标识常量集合接口。涵盖 OpenAI、Anthropic、Gemini、DeepSeek 等主流 LLM 提供商。
 */
export interface ProviderIdConstants {
  OPENAI: string;
  OPENAI_COMPATIBLE: string;
  ANTHROPIC: string;
  AZURE: string;
  GEMINI: string;
  KOBOLD: string;
  HORDE: string;
  MINIMAX: string;
  NANOGPT: string;
  NOVELAI: string;
  OPENROUTER: string;
  VOLCENGINE: string;
  OLLAMA: string;
  COHERE: string;
  DEEPSEEK: string;
  LOCAL: string;
  CUSTOM: string;
  SYSTEM: string;
  LOCAL_HTTP: string;
  OPENAI_WHISPER: string;
  OPENAI_VISION: string;
}

/**
 * Provider 标识常量值。消费方用于标记消息来源、配置连接、路由请求到对应后端。
 */
export const ProviderIds: ProviderIdConstants = {
  OPENAI: 'openai',
  OPENAI_COMPATIBLE: 'openai-compatible',
  ANTHROPIC: 'anthropic',
  AZURE: 'azure',
  GEMINI: 'gemini',
  KOBOLD: 'kobold',
  HORDE: 'horde',
  MINIMAX: 'minimax',
  NANOGPT: 'nanogpt',
  NOVELAI: 'novelai',
  OPENROUTER: 'openrouter',
  VOLCENGINE: 'volcengine',
  OLLAMA: 'ollama',
  COHERE: 'cohere',
  DEEPSEEK: 'deepseek',
  LOCAL: 'local',
  CUSTOM: 'custom',
  SYSTEM: 'system',
  LOCAL_HTTP: 'local_http',
  OPENAI_WHISPER: 'openai_whisper',
  OPENAI_VISION: 'openai_vision',
};

/**
 * 描述 tokenizer 策略。该字段允许宿主扩展自定义策略。
 */
export type TokenizerStrategy = string;

/**
 * Tokenizer 策略常量集合接口。涵盖各大模型系列的内置分词器以及通用策略（bytes、word）。
 */
export interface TokenizerStrategyConstants {
  BYTES: string;
  WORD: string;
  OPENAI: string;
  OPENAI_CL100K: string;
  GPT2: string;
  CLAUDE: string;
  LLAMA: string;
  LLAMA3: string;
  MISTRAL: string;
  QWEN2: string;
  GEMMA: string;
  GEMINI: string;
  DEEPSEEK: string;
  PROVIDER: string;
  BEST_MATCH: string;
  API_CURRENT: string;
  API_KOBOLD: string;
  API_TEXTGENERATIONWEBUI: string;
}

/**
 * Tokenizer 策略常量值。BYTES/WORD 为通用策略；其余按模型系列命名，
 * 消费方在消息发送前调用对应策略计算 token 数。
 */
export const TokenizerStrategies: TokenizerStrategyConstants = {
  BYTES: 'bytes',
  WORD: 'word',
  OPENAI: 'openai',
  OPENAI_CL100K: 'openai-cl100k',
  GPT2: 'gpt2',
  CLAUDE: 'claude',
  LLAMA: 'llama',
  LLAMA3: 'llama3',
  MISTRAL: 'mistral',
  QWEN2: 'qwen2',
  GEMMA: 'gemma',
  GEMINI: 'gemini',
  DEEPSEEK: 'deepseek',
  PROVIDER: 'provider',
  BEST_MATCH: 'best-match',
  API_CURRENT: 'api-current',
  API_KOBOLD: 'api-kobold',
  API_TEXTGENERATIONWEBUI: 'api-textgenerationwebui',
};

/**
 * 描述推理内容格式。该字段允许宿主扩展自定义格式。
 */
export type ReasoningFormat = string;

/**
 * 推理内容格式常量集合接口。定义模型返回推理内容时的标记方式。
 */
export interface ReasoningFormatConstants {
  NONE: string;
  TAGGED: string;
  OPENAI: string;
  DEEPSEEK: string;
}

/**
 * 推理内容格式常量值。NONE 无推理过程 / TAGGED 标签包裹 / OPENAI / DEEPSEEK 各平台专有格式。
 */
export const ReasoningFormats: ReasoningFormatConstants = {
  NONE: '',
  TAGGED: 'tagged',
  OPENAI: 'openai',
  DEEPSEEK: 'deepseek',
};

/**
 * 描述预设类别。该字段允许宿主扩展自定义预设类别。
 */
export type PresetKind = string;

/**
 * 预设类别常量集合接口。预设用于存储和管理不同场景下的配置快照。
 */
export interface PresetKindConstants {
  GENERATION: string;
  SYSTEM: string;
  CONTEXT: string;
  INSTRUCT: string;
}

/**
 * 预设类别常量值。GENERATION 生成参数 / SYSTEM 系统提示 / CONTEXT 上下文 / INSTRUCT 指令模板。
 */
export const PresetKinds: PresetKindConstants = {
  GENERATION: 'generation',
  SYSTEM: 'system',
  CONTEXT: 'context',
  INSTRUCT: 'instruct',
};

/**
 * 描述资源类型。该字段允许宿主扩展自定义资源类型。
 */
export type AssetType = string;

/**
 * 资源类型常量集合接口。在资产管理中区分资源的种类。
 */
export interface AssetTypeConstants {
  IMAGE: string;
  BACKGROUND: string;
  THEME: string;
  THUMBNAIL: string;
  AUDIO: string;
}

/**
 * 资源类型常量值。IMAGE 图片 / BACKGROUND 背景 / THEME 主题 / THUMBNAIL 缩略图 / AUDIO 音频。
 */
export const AssetTypes: AssetTypeConstants = {
  IMAGE: 'image',
  BACKGROUND: 'background',
  THEME: 'theme',
  THUMBNAIL: 'thumbnail',
  AUDIO: 'audio',
};

/**
 * 描述附件类别。该字段允许宿主扩展自定义附件类别。
 */
export type AttachmentKind = string;

/**
 * 附件类别常量集合接口。在消息发送或上下文构建时标记附加内容的种类。
 */
export interface AttachmentKindConstants {
  TEXT: string;
  IMAGE: string;
  GENERATED_IMAGE: string;
  AUDIO: string;
  JSON: string;
  FILE: string;
}

/**
 * 附件类别常量值。TEXT 文本 / IMAGE 图片 / GENERATED_IMAGE 生成图片 / AUDIO 音频 / JSON / FILE 文件。
 */
export const AttachmentKinds: AttachmentKindConstants = {
  TEXT: 'text',
  IMAGE: 'image',
  GENERATED_IMAGE: 'generated_image',
  AUDIO: 'audio',
  JSON: 'json',
  FILE: 'file',
};

/**
 * 描述图片或音频格式。该字段允许宿主扩展自定义媒体格式。
 */
export type MediaFormat = string;

/**
 * 媒体格式常量集合接口。在资产管理或导入导出时标识图片/音频的具体编码格式。
 */
export interface MediaFormatConstants {
  PNG: string;
  JPG: string;
  JPEG: string;
  WEBP: string;
  GIF: string;
  MP3: string;
  WAV: string;
  OGG: string;
  FLAC: string;
}

/**
 * 媒体格式常量值。PNG/JPG/JPEG/WEBP/GIF（图片），MP3/WAV/OGG/FLAC（音频）。
 */
export const MediaFormats: MediaFormatConstants = {
  PNG: 'png',
  JPG: 'jpg',
  JPEG: 'jpeg',
  WEBP: 'webp',
  GIF: 'gif',
  MP3: 'mp3',
  WAV: 'wav',
  OGG: 'ogg',
  FLAC: 'flac',
};

/**
 * 描述角色卡格式常量。
 */
export interface CharacterCardFormatConstants {
  V1: 'v1';
  V2: 'v2';
  CHARX: 'charx';
  PNG_METADATA: 'png_metadata';
  WEBP_METADATA: 'webp_metadata';
  UNKNOWN: 'unknown';
}

/**
 * 角色卡格式常量值。V1/V2 主流格式，CHARX 扩展格式，PNG_METADATA/WEBP_METADATA 元数据嵌入，UNKNOWN 未知。
 */
export const CharacterCardFormats: CharacterCardFormatConstants = {
  V1: 'v1',
  V2: 'v2',
  CHARX: 'charx',
  PNG_METADATA: 'png_metadata',
  WEBP_METADATA: 'webp_metadata',
  UNKNOWN: 'unknown',
};

/**
 * 描述图片元数据格式常量。
 */
export interface ImageMetadataFormatConstants {
  PNG: 'png';
  WEBP: 'webp';
  JPEG: 'jpeg';
  UNKNOWN: 'unknown';
}

/**
 * 图片元数据格式常量值。在解码角色卡嵌入元数据时识别图片容器格式：PNG/WEBP/JPEG/UNKNOWN。
 */
export const ImageMetadataFormats: ImageMetadataFormatConstants = {
  PNG: 'png',
  WEBP: 'webp',
  JPEG: 'jpeg',
  UNKNOWN: 'unknown',
};

/**
 * 描述语音识别 Provider 常量。
 */
export interface ASRProviderConstants {
  OPENAI_WHISPER: 'openai_whisper';
  LOCAL_WHISPER: 'local_whisper';
  SYSTEM: 'system';
}

/**
 * 语音识别 Provider 常量值。OPENAI_WHISPER 云端 / LOCAL_WHISPER 本地 / SYSTEM 系统内置。
 */
export const ASRProviders: ASRProviderConstants = {
  OPENAI_WHISPER: 'openai_whisper',
  LOCAL_WHISPER: 'local_whisper',
  SYSTEM: 'system',
};

/**
 * 描述图片理解 Provider 常量。
 */
export interface CaptionProviderConstants {
  OPENAI_VISION: 'openai_vision';
  LOCAL: 'local';
  CUSTOM: 'custom';
}

/**
 * 图片理解 Provider 常量值。OPENAI_VISION OpenAI 视觉 / LOCAL 本地模型 / CUSTOM 自定义 Provider。
 */
export const CaptionProviders: CaptionProviderConstants = {
  OPENAI_VISION: 'openai_vision',
  LOCAL: 'local',
  CUSTOM: 'custom',
};

/**
 * 描述图片生成后端常量。
 */
export interface ImageGenerationBackendConstants {
  SD_WEBUI: 'sd_webui';
  COMFYUI: 'comfyui';
  OPENAI_IMAGE: 'openai_image';
  WORKERS_AI: 'workers_ai';
}

/**
 * 图片生成后端常量值。SD_WEBUI Stable Diffusion / COMFYUI ComfyUI / OPENAI_IMAGE DALL-E / WORKERS_AI Cloudflare Workers AI。
 */
export const ImageGenerationBackends: ImageGenerationBackendConstants = {
  SD_WEBUI: 'sd_webui',
  COMFYUI: 'comfyui',
  OPENAI_IMAGE: 'openai_image',
  WORKERS_AI: 'workers_ai',
};

/**
 * 描述 TTS Provider 常量。
 */
export interface TTSProviderConstants {
  OPENAI: 'openai';
  ELEVENLABS: 'elevenlabs';
  EDGE: 'edge';
  SYSTEM: 'system';
}

/**
 * TTS（文本转语音）Provider 常量值。OPENAI / ELEVENLABS / EDGE（Edge TTS）/ SYSTEM 系统内置。
 */
export const TTSProviders: TTSProviderConstants = {
  OPENAI: 'openai',
  ELEVENLABS: 'elevenlabs',
  EDGE: 'edge',
  SYSTEM: 'system',
};

/**
 * 描述 Embedding Provider 常量。
 */
export interface EmbeddingProviderConstants {
  OPENAI: 'openai';
  OLLAMA: 'ollama';
  GOOGLE: 'google';
  COHERE: 'cohere';
  LLAMACPP: 'llamacpp';
  VLLM: 'vllm';
  LOCAL_HTTP: 'local_http';
}

/**
 * Embedding Provider 常量值。覆盖 OpenAI / Ollama / Google / Cohere / llama.cpp / vLLM / local-http。
 */
export const EmbeddingProviders: EmbeddingProviderConstants = {
  OPENAI: 'openai',
  OLLAMA: 'ollama',
  GOOGLE: 'google',
  COHERE: 'cohere',
  LLAMACPP: 'llamacpp',
  VLLM: 'vllm',
  LOCAL_HTTP: 'local_http',
};

/**
 * 描述表情分类常量。
 */
export interface ExpressionClassificationConstants {
  JOY: 'joy';
  SADNESS: 'sadness';
  ANGER: 'anger';
  FEAR: 'fear';
  SURPRISE: 'surprise';
  DISGUST: 'disgust';
  NEUTRAL: 'neutral';
  LOVE: 'love';
  CUSTOM: 'custom';
}

/**
 * 表情分类常量值。JOY/ANGLER/SADNESS 等基本情绪，CUSTOM 供宿主扩展。
 */
export const ExpressionClassifications: ExpressionClassificationConstants = {
  JOY: 'joy',
  SADNESS: 'sadness',
  ANGER: 'anger',
  FEAR: 'fear',
  SURPRISE: 'surprise',
  DISGUST: 'disgust',
  NEUTRAL: 'neutral',
  LOVE: 'love',
  CUSTOM: 'custom',
};

/**
 * 描述缩略图类别。该字段允许宿主扩展自定义缩略图类别。
 */
export type ThumbnailType = string;

/**
 * 缩略图类别常量集合接口。在生成缩略图时标识缩略图的用途。
 */
export interface ThumbnailTypeConstants {
  BACKGROUND: string;
  AVATAR: string;
  PERSONA: string;
}

/**
 * 缩略图类别常量值。BACKGROUND 用于背景 / AVATAR 用于头像 / PERSONA 用于人设。
 */
export const ThumbnailTypes: ThumbnailTypeConstants = {
  BACKGROUND: 'bg',
  AVATAR: 'avatar',
  PERSONA: 'persona',
};

/**
 * 描述代理解析模式。
 */
export type ProxyResolutionMode = 'direct' | 'proxy';

/**
 * 代理解析模式集合接口。direct 直连 / proxy 通过代理服务器。
 */
export interface ProxyResolutionModeConstants {
  DIRECT: ProxyResolutionMode;
  PROXY: ProxyResolutionMode;
}

/**
 * 代理解析模式常量。DIRECT 直连 / PROXY 通过代理转发网络请求。
 */
export const ProxyResolutionModes: ProxyResolutionModeConstants = {
  DIRECT: 'direct',
  PROXY: 'proxy',
};

/**
 * 描述诊断记录类型。该字段允许宿主扩展自定义诊断类型。
 */
export type DiagnosticKind = string;

/**
 * 诊断记录类型常量集合接口。在诊断收集阶段标记每条记录的功能分类。
 */
export interface DiagnosticKindConstants {
  PROMPT: string;
  EVENT: string;
  PLUGIN: string;
  COMMAND: string;
  SCRIPT: string;
  TOOL: string;
  STREAM: string;
}

/**
 * 诊断记录类型常量值。PROMPT/EVENT/PLUGIN/COMMAND/SCRIPT/TOOL/STREAM 覆盖运行时各功能域。
 */
export const DiagnosticKinds: DiagnosticKindConstants = {
  PROMPT: 'prompt',
  EVENT: 'event',
  PLUGIN: 'plugin',
  COMMAND: 'command',
  SCRIPT: 'script',
  TOOL: 'tool',
  STREAM: 'stream',
};

/**
 * 描述诊断状态。
 */
export type DiagnosticStatus = 'ok' | 'warning' | 'error';

/**
 * 诊断状态常量集合接口。ok 正常 / warning 警告 / error 错误。
 */
export interface DiagnosticStatusConstants {
  OK: DiagnosticStatus;
  WARNING: DiagnosticStatus;
  ERROR: DiagnosticStatus;
}

/**
 * 诊断状态常量值。OK 正常 / WARNING 警告 / ERROR 错误。
 */
export const DiagnosticStatuses: DiagnosticStatusConstants = {
  OK: 'ok',
  WARNING: 'warning',
  ERROR: 'error',
};

/**
 * 描述健康状态。
 */
/**
 * 健康状态类型。healthy 正常运行 / degraded 降级运行（部分功能不可用）。
 */
export type HealthStatus = 'healthy' | 'degraded';

/**
 * 描述备份类别。该字段允许宿主扩展自定义备份类别。
 */
export type BackupKind = string;

/**
 * 备份类别常量集合接口。在备份操作时标识备份的范围和目的。
 */
export interface BackupKindConstants {
  FULL: string;
  MANUAL: string;
  MIGRATION: string;
}

/**
 * 备份类别常量值。FULL 全量备份 / MANUAL 手动备份 / MIGRATION 迁移备份。
 */
export const BackupKinds: BackupKindConstants = {
  FULL: 'full',
  MANUAL: 'manual',
  MIGRATION: 'migration',
};

/**
 * 描述设置值类型。该字段允许宿主扩展自定义设置类型。
 */
export type SettingValueType = string;

/**
 * 设置值类型常量集合接口。在设置管理中标识每个条目的值的数据类型。
 */
export interface SettingValueTypeConstants {
  STRING: string;
  NUMBER: string;
  BOOLEAN: string;
  JSON: string;
}

/**
 * 设置值类型常量。STRING 字符串 / NUMBER 数字 / BOOLEAN 布尔 / JSON 序列化对象。
 */
export const SettingValueTypes: SettingValueTypeConstants = {
  STRING: 'string',
  NUMBER: 'number',
  BOOLEAN: 'boolean',
  JSON: 'json',
};

/**
 * 描述模块数据来源。该字段允许宿主扩展自定义来源。
 */
export type RuntimeSource = string;

/**
 * 模块数据来源常量集合接口。在插件加载/配置注册时标记来源层级。
 */
export interface RuntimeSourceConstants {
  CORE: string;
  BUILTIN: string;
  PLUGIN: string;
  USER: string;
  TEST: string;
}

/**
 * 模块数据来源常量值。CORE 框架核心 / BUILTIN 内置模块 / PLUGIN 三方插件 / USER 用户自定义 / TEST 测试。
 */
export const RuntimeSources: RuntimeSourceConstants = {
  CORE: 'core',
  BUILTIN: 'builtin',
  PLUGIN: 'plugin',
  USER: 'user',
  TEST: 'test',
};

/**
 * 描述内容包类型常量。
 */
export interface ContentTypeConstants {
  EXTENSION: 'extension';
  ASSET: 'asset';
  CHARACTER: 'character';
  BACKGROUND: 'background';
  THEME: 'theme';
}

/**
 * 内容包类型常量值。EXTENSION 扩展 / ASSET 资源 / CHARACTER 角色 / BACKGROUND 背景 / THEME 主题。
 */
export const ContentTypes: ContentTypeConstants = {
  EXTENSION: 'extension',
  ASSET: 'asset',
  CHARACTER: 'character',
  BACKGROUND: 'background',
  THEME: 'theme',
};

/**
 * 描述内容包来源常量。
 */
export interface ContentSourceConstants {
  URL: 'url';
  FILE: 'file';
  GITHUB: 'github';
  MARKETPLACE: 'marketplace';
}

/**
 * 内容包来源常量值。URL 远程链接 / FILE 本地文件 / GITHUB GitHub / MARKETPLACE 插件市场。
 */
export const ContentSources: ContentSourceConstants = {
  URL: 'url',
  FILE: 'file',
  GITHUB: 'github',
  MARKETPLACE: 'marketplace',
};

/**
 * 描述内容安装状态常量。
 */
export interface InstallStatusConstants {
  PENDING: 'pending';
  DOWNLOADING: 'downloading';
  INSTALLING: 'installing';
  INSTALLED: 'installed';
  FAILED: 'failed';
}

/**
 * 内容安装状态常量值。PENDING -> DOWNLOADING -> INSTALLING -> INSTALLED / FAILED。
 */
export const InstallStatuses: InstallStatusConstants = {
  PENDING: 'pending',
  DOWNLOADING: 'downloading',
  INSTALLING: 'installing',
  INSTALLED: 'installed',
  FAILED: 'failed',
};

/**
 * 描述迁移状态常量。
 */
export interface MigrationStatusConstants {
  PENDING: 'pending';
  RUNNING: 'running';
  COMPLETED: 'completed';
  FAILED: 'failed';
  ROLLED_BACK: 'rolled_back';
}

/**
 * 迁移状态常量值。PENDING -> RUNNING -> COMPLETED / FAILED / ROLLED_BACK 回滚。
 */
export const MigrationStatuses: MigrationStatusConstants = {
  PENDING: 'pending',
  RUNNING: 'running',
  COMPLETED: 'completed',
  FAILED: 'failed',
  ROLLED_BACK: 'rolled_back',
};

/**
 * 描述翻译方向常量。
 */
export interface TranslationDirectionConstants {
  INPUT: 'input';
  OUTPUT: 'output';
}

/**
 * 翻译方向常量值。INPUT 输入翻译（用户消息 -> 目标语言）/ OUTPUT 输出翻译（AI回复 -> 目标语言）。
 */
export const TranslationDirections: TranslationDirectionConstants = {
  INPUT: 'input',
  OUTPUT: 'output',
};

/**
 * 描述翻译作用域常量。
 */
export interface TranslationScopeConstants {
  MESSAGE_INPUT: 'message_input';
  MESSAGE_OUTPUT: 'message_output';
  PROMPT: 'prompt';
  TTS: 'tts';
  DATA_BANK: 'databank';
}

/**
 * 翻译作用域常量值。MESSAGE_INPUT/MESSAGE_OUTPUT/PROMPT/TTS/DATA_BANK 分别对应不同文本区域的翻译开关。
 */
export const TranslationScopes: TranslationScopeConstants = {
  MESSAGE_INPUT: 'message_input',
  MESSAGE_OUTPUT: 'message_output',
  PROMPT: 'prompt',
  TTS: 'tts',
  DATA_BANK: 'databank',
};

/**
 * 描述恢复类型常量。
 */
export interface RecoveryTypeConstants {
  USER_PASSWORD: 'user_password';
  DATA_CORRUPTION: 'data_corruption';
  SESSION_RESTORE: 'session_restore';
}

/**
 * 恢复类型常量值。USER_PASSWORD 密码恢复 / DATA_CORRUPTION 数据损坏修复 / SESSION_RESTORE 会话恢复。
 */
export const RecoveryTypes: RecoveryTypeConstants = {
  USER_PASSWORD: 'user_password',
  DATA_CORRUPTION: 'data_corruption',
  SESSION_RESTORE: 'session_restore',
};

/**
 * 描述 Markdown 扩展常量。
 */
export interface MarkdownExtensionConstants {
  UNDERLINE: 'underline';
  STRIKETHROUGH: 'strikethrough';
  CODE_BLOCK: 'code_block';
  EXCLUSION: 'exclusion';
}

/**
 * Markdown 扩展常量值。UNDERLINE 下划线 / STRIKETHROUGH 删除线 / CODE_BLOCK 代码块 / EXCLUSION 排除标记。
 */
export const MarkdownExtensions: MarkdownExtensionConstants = {
  UNDERLINE: 'underline',
  STRIKETHROUGH: 'strikethrough',
  CODE_BLOCK: 'code_block',
  EXCLUSION: 'exclusion',
};

/**
 * 描述 Prompt 段类型。该字段允许宿主扩展自定义段类型。
 */
export type PromptSectionType = string;

export interface PromptSectionTypeConstants {
  SYSTEM: string;
  PERSONA: string;
  CHARACTER: string;
  WORLD_INFO: string;
  AUTHOR_NOTE: string;
  MESSAGE: string;
}

/**
 * Prompt 段类型常量值。SYSTEM/PERSONA/CHARACTER/WORLD_INFO/AUTHOR_NOTE/MESSAGE 覆盖 prompt 构建中各段来源。
 */
export const PromptSectionTypes: PromptSectionTypeConstants = {
  SYSTEM: 'system',
  PERSONA: 'persona',
  CHARACTER: 'character',
  WORLD_INFO: 'world_info',
  AUTHOR_NOTE: 'author_note',
  MESSAGE: 'message',
};

/**
 * 描述工具调用内容类型。
 */
export type ToolCallContentType = 'function';

/**
 * 工具调用内容类型常量集合接口。目前仅有 FUNCTION 函数调用。
 */
export interface ToolCallContentTypeConstants {
  FUNCTION: ToolCallContentType;
}

/**
 * 工具调用内容类型常量值。FUNCTION 表示工具调用为函数调用。
 */
export const ToolCallContentTypes: ToolCallContentTypeConstants = {
  FUNCTION: 'function',
};

/**
 * 描述视觉内容片段类型。
 */
export type VisionContentPartType = 'text' | 'image_url';

/**
 * 视觉内容片段类型常量集合接口。text 纯文本 / image_url 图片 URL。
 */
export interface VisionContentPartTypeConstants {
  TEXT: VisionContentPartType;
  IMAGE_URL: VisionContentPartType;
}

/**
 * 视觉内容片段类型常量值。TEXT 纯文本 / IMAGE_URL 图片 URL 引用。
 */
export const VisionContentPartTypes: VisionContentPartTypeConstants = {
  TEXT: 'text',
  IMAGE_URL: 'image_url',
};

/**
 * 描述搜索结果类型。该字段允许宿主扩展自定义搜索结果类型。
 */
export type SearchResultType = string;

/**
 * 搜索结果类型常量集合接口。在搜索模块中标识命中的资源种类。
 */
export interface SearchResultTypeConstants {
  CHARACTER: string;
  CHAT: string;
  MESSAGE: string;
  WORLD_INFO: string;
  DATA_BANK: string;
  ASSET: string;
}

/**
 * 搜索结果类型常量值。CHARACTER/CHAT/MESSAGE/WORLD_INFO/DATA_BANK/ASSET 覆盖可搜索的资源类别。
 */
export const SearchResultTypes: SearchResultTypeConstants = {
  CHARACTER: 'character',
  CHAT: 'chat',
  MESSAGE: 'message',
  WORLD_INFO: 'world_info',
  DATA_BANK: 'databank',
  ASSET: 'asset',
};

/**
 * 描述密钥引用字符串。
 */
export type SecretRef = string;

/**
 * 描述密钥读取权限。该字段允许宿主扩展自定义权限。
 */
export type SecretPermission = string;

/**
 * 密钥权限常量集合接口。在密钥访问控制中定义授予的读权限。
 */
export interface SecretPermissionConstants {
  READ_SECRET: string;
}

/**
 * 密钥权限常量值。READ_SECRET 表示有读取密钥内容的权限。
 */
export const SecretPermissions: SecretPermissionConstants = {
  READ_SECRET: 'secret:read',
};

/**
 * 描述运行时权限标识。该字段允许宿主扩展自定义权限。
 */
export type RuntimePermission = string;

/**
 * 运行时权限常量集合接口。在安全子系统中定义插件/脚本可申请的权限位。
 */
export interface RuntimePermissionConstants {
  READ_SECRET: string;
  FILE_READ: string;
  FILE_WRITE: string;
  NETWORK: string;
  COMMAND_EXECUTE: string;
}

/**
 * 运行时权限常量值。READ_SECRET 读取密钥 / FILE_READ 读取文件 / FILE_WRITE 写入文件 / NETWORK 网络访问 / COMMAND_EXECUTE 执行命令。
 */
export const RuntimePermissions: RuntimePermissionConstants = {
  READ_SECRET: 'secret:read',
  FILE_READ: 'file:read',
  FILE_WRITE: 'file:write',
  NETWORK: 'network',
  COMMAND_EXECUTE: 'command:execute',
};

/**
 * 提供密钥引用字符串的统一构造和解析入口。
 */
export class SecretRefs {
  /**
   * 创建密钥引用字符串。格式 `secret:{providerId}:{id}`。
   * 在需要记录密钥位置时调用此方法统一构造引用标识。
   */
  static create(providerId: string, id: string): SecretRef {
    return `secret:${providerId}:${id}`;
  }

  /**
   * 从密钥引用字符串中提取 Provider 标识部分。返回空字符串表示格式非法。
   * 解析时使用方应确保引用字符串来自 {@link create} 方法。
   */
  static providerId(secretRef: SecretRef): string {
    const parts = secretRef.split(':');
    if (parts.length < 3 || parts[0] !== 'secret') {
      return '';
    }
    return parts[1];
  }

  /**
   * 从密钥引用字符串中提取 ID 部分（providerId 之后的所有内容）。返回空字符串表示格式非法。
   */
  static id(secretRef: SecretRef): string {
    const parts = secretRef.split(':');
    if (parts.length < 3 || parts[0] !== 'secret') {
      return '';
    }
    return parts.slice(2).join(':');
  }

  /**
   * 校验密钥引用字符串的格式是否合法。providerId 和 id 同时非空时返回 true。
   */
  static isValid(secretRef: SecretRef): boolean {
    return SecretRefs.providerId(secretRef).length > 0 && SecretRefs.id(secretRef).length > 0;
  }
}
