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
export type ChatMessageRole = 'system' | 'user' | 'assistant' | 'tool' | 'function';

export interface ChatMessageRoleConstants {
  SYSTEM: ChatMessageRole;
  USER: ChatMessageRole;
  ASSISTANT: ChatMessageRole;
  TOOL: ChatMessageRole;
  FUNCTION: ChatMessageRole;
}

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

export interface GroupMemberRoleConstants {
  SPEAKER: string;
  LISTENER: string;
  MODERATOR: string;
}

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
export type RuntimeTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled' | 'aborted';

export interface RuntimeTaskStatusConstants {
  PENDING: RuntimeTaskStatus;
  RUNNING: RuntimeTaskStatus;
  COMPLETED: RuntimeTaskStatus;
  FAILED: RuntimeTaskStatus;
  CANCELLED: RuntimeTaskStatus;
  ABORTED: RuntimeTaskStatus;
}

export const RuntimeTaskStatuses: RuntimeTaskStatusConstants = {
  PENDING: 'pending',
  RUNNING: 'running',
  COMPLETED: 'completed',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
  ABORTED: 'aborted',
};

/**
 * 描述可公开使用的通用异步任务状态常量。
 */
export interface AsyncTaskStatusConstants {
  PENDING: 'pending';
  RUNNING: 'running';
  COMPLETED: 'completed';
  FAILED: 'failed';
  CANCELLED: 'cancelled';
}

export const AsyncTaskStatuses: AsyncTaskStatusConstants = {
  PENDING: 'pending',
  RUNNING: 'running',
  COMPLETED: 'completed',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
};

export type ASRTaskStatusConstants = AsyncTaskStatusConstants;
export const ASRTaskStatuses: ASRTaskStatusConstants = AsyncTaskStatuses;

export type CaptionTaskStatusConstants = AsyncTaskStatusConstants;
export const CaptionTaskStatuses: CaptionTaskStatusConstants = AsyncTaskStatuses;

export type ImageGenerationStatusConstants = AsyncTaskStatusConstants;
export const ImageGenerationStatuses: ImageGenerationStatusConstants = AsyncTaskStatuses;

export type TTSTaskStatusConstants = AsyncTaskStatusConstants;
export const TTSTaskStatuses: TTSTaskStatusConstants = AsyncTaskStatuses;

export type TranslationTaskStatusConstants = AsyncTaskStatusConstants;
export const TranslationTaskStatuses: TranslationTaskStatusConstants = AsyncTaskStatuses;

/**
 * 描述流式会话状态。
 */
export type StreamSessionStatus = 'running' | 'completed' | 'aborted';

export interface StreamSessionStatusConstants {
  RUNNING: StreamSessionStatus;
  COMPLETED: StreamSessionStatus;
  ABORTED: StreamSessionStatus;
}

export const StreamSessionStatuses: StreamSessionStatusConstants = {
  RUNNING: 'running',
  COMPLETED: 'completed',
  ABORTED: 'aborted',
};

/**
 * 描述 OpenAI-compatible 文本补全 API 类型。该字段允许宿主扩展自定义类型。
 */
export type ConnectionApiType = string;

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

export interface ReasoningFormatConstants {
  NONE: string;
  TAGGED: string;
  OPENAI: string;
  DEEPSEEK: string;
}

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

export interface PresetKindConstants {
  GENERATION: string;
  SYSTEM: string;
  CONTEXT: string;
  INSTRUCT: string;
}

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

export interface AssetTypeConstants {
  IMAGE: string;
  BACKGROUND: string;
  THEME: string;
  THUMBNAIL: string;
  AUDIO: string;
}

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

export interface AttachmentKindConstants {
  TEXT: string;
  IMAGE: string;
  GENERATED_IMAGE: string;
  AUDIO: string;
  JSON: string;
  FILE: string;
}

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

export interface ThumbnailTypeConstants {
  BACKGROUND: string;
  AVATAR: string;
  PERSONA: string;
}

export const ThumbnailTypes: ThumbnailTypeConstants = {
  BACKGROUND: 'bg',
  AVATAR: 'avatar',
  PERSONA: 'persona',
};

/**
 * 描述代理解析模式。
 */
export type ProxyResolutionMode = 'direct' | 'proxy';

export interface ProxyResolutionModeConstants {
  DIRECT: ProxyResolutionMode;
  PROXY: ProxyResolutionMode;
}

export const ProxyResolutionModes: ProxyResolutionModeConstants = {
  DIRECT: 'direct',
  PROXY: 'proxy',
};

/**
 * 描述诊断记录类型。该字段允许宿主扩展自定义诊断类型。
 */
export type DiagnosticKind = string;

export interface DiagnosticKindConstants {
  PROMPT: string;
  EVENT: string;
  PLUGIN: string;
  COMMAND: string;
  SCRIPT: string;
  TOOL: string;
  STREAM: string;
}

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

export interface DiagnosticStatusConstants {
  OK: DiagnosticStatus;
  WARNING: DiagnosticStatus;
  ERROR: DiagnosticStatus;
}

export const DiagnosticStatuses: DiagnosticStatusConstants = {
  OK: 'ok',
  WARNING: 'warning',
  ERROR: 'error',
};

/**
 * 描述健康状态。
 */
export type HealthStatus = 'healthy' | 'degraded';

/**
 * 描述备份类别。该字段允许宿主扩展自定义备份类别。
 */
export type BackupKind = string;

export interface BackupKindConstants {
  FULL: string;
  MANUAL: string;
  MIGRATION: string;
}

export const BackupKinds: BackupKindConstants = {
  FULL: 'full',
  MANUAL: 'manual',
  MIGRATION: 'migration',
};

/**
 * 描述设置值类型。该字段允许宿主扩展自定义设置类型。
 */
export type SettingValueType = string;

export interface SettingValueTypeConstants {
  STRING: string;
  NUMBER: string;
  BOOLEAN: string;
  JSON: string;
}

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

export interface RuntimeSourceConstants {
  CORE: string;
  BUILTIN: string;
  PLUGIN: string;
  USER: string;
  TEST: string;
}

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

export interface ToolCallContentTypeConstants {
  FUNCTION: ToolCallContentType;
}

export const ToolCallContentTypes: ToolCallContentTypeConstants = {
  FUNCTION: 'function',
};

/**
 * 描述视觉内容片段类型。
 */
export type VisionContentPartType = 'text' | 'image_url';

export interface VisionContentPartTypeConstants {
  TEXT: VisionContentPartType;
  IMAGE_URL: VisionContentPartType;
}

export const VisionContentPartTypes: VisionContentPartTypeConstants = {
  TEXT: 'text',
  IMAGE_URL: 'image_url',
};

/**
 * 描述搜索结果类型。该字段允许宿主扩展自定义搜索结果类型。
 */
export type SearchResultType = string;

export interface SearchResultTypeConstants {
  CHARACTER: string;
  CHAT: string;
  MESSAGE: string;
  WORLD_INFO: string;
  DATA_BANK: string;
  ASSET: string;
}

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

export interface SecretPermissionConstants {
  READ_SECRET: string;
}

export const SecretPermissions: SecretPermissionConstants = {
  READ_SECRET: 'secret:read',
};

/**
 * 描述运行时权限标识。该字段允许宿主扩展自定义权限。
 */
export type RuntimePermission = string;

export interface RuntimePermissionConstants {
  READ_SECRET: string;
  FILE_READ: string;
  FILE_WRITE: string;
  NETWORK: string;
  COMMAND_EXECUTE: string;
}

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
  static create(providerId: string, id: string): SecretRef {
    return `secret:${providerId}:${id}`;
  }

  static providerId(secretRef: SecretRef): string {
    const parts = secretRef.split(':');
    if (parts.length < 3 || parts[0] !== 'secret') {
      return '';
    }
    return parts[1];
  }

  static id(secretRef: SecretRef): string {
    const parts = secretRef.split(':');
    if (parts.length < 3 || parts[0] !== 'secret') {
      return '';
    }
    return parts.slice(2).join(':');
  }

  static isValid(secretRef: SecretRef): boolean {
    return SecretRefs.providerId(secretRef).length > 0 && SecretRefs.id(secretRef).length > 0;
  }
}
