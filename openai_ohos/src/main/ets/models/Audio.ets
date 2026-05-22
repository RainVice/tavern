import type { CursorPageParams, JsonObject, OpenAIListResponse, OpenAIModel } from './Common';

/**
 * TTS 语音名称。
 *
 * API：`POST /v1/audio/speech`。
 * 说明：对应官方语音预设。
 */
export type SpeechVoice = 'alloy' | 'ash' | 'ballad' | 'coral' | 'echo' | 'fable' | 'nova' | 'onyx' | 'sage' | 'shimmer' | 'verse';

/**
 * TTS 输出格式。
 *
 * API：`POST /v1/audio/speech`。
 * 说明：控制返回音频编码格式。
 */
export type SpeechResponseFormat = 'mp3' | 'opus' | 'aac' | 'flac' | 'wav' | 'pcm';

/**
 * 创建语音请求。
 *
 * API：`POST /v1/audio/speech`。
 * 说明：把文本转换为语音音频。
 */
export interface SpeechCreateParams {
  /**
   * 模型 ID。
   *
   * API：Audio speech。
   * 说明：例如 `gpt-4o-mini-tts` 或其他语音模型。
   */
  model: OpenAIModel;

  /**
   * 输入文本。
   *
   * API：Audio speech。
   * 说明：需要合成为语音的文本内容。
   */
  input: string;

  /**
   * 语音。
   *
   * API：Audio speech。
   * 说明：决定音色。
   */
  voice: SpeechVoice;

  /**
   * 输出音频格式。
   *
   * API：Audio speech。
   * 说明：默认通常为 `mp3`。
   */
  response_format?: SpeechResponseFormat;

  /**
   * 语速。
   *
   * API：Audio speech。
   * 说明：控制朗读速度，官方限制范围由服务端校验。
   */
  speed?: number;

  /**
   * 语音指令。
   *
   * API：Audio speech。
   * 说明：部分新模型支持通过 instructions 调整语气、风格或情绪。
   */
  instructions?: string;
}

/**
 * 语音响应。
 *
 * API：`POST /v1/audio/speech`。
 * 说明：实际 HTTP 响应是二进制音频；模型层用该对象描述 client 层归一化后的结果。
 */
export interface SpeechResponse {
  /**
   * 音频数据。
   *
   * API：Audio speech 响应。
   * 说明：HTTP 层可填入 ArrayBuffer、base64 或本地缓存路径；这里用 string 承载跨平台结果。
   */
  data: string;

  /**
   * 音频格式。
   *
   * API：Audio speech 响应。
   * 说明：对应请求的 `response_format`。
   */
  response_format: SpeechResponseFormat;
}

/**
 * 创建转写请求。
 *
 * API：`POST /v1/audio/transcriptions`。
 * 说明：把音频转写成文本。
 */
export interface TranscriptionCreateParams {
  /**
   * 音频文件。
   *
   * API：Audio transcription。
   * 说明：Harmony HTTP 层可把本地 URI、沙箱路径或文件 ID 转为 multipart；模型层先用字符串承载。
   */
  file: string;

  /**
   * 模型 ID。
   *
   * API：Audio transcription。
   * 说明：例如 `gpt-4o-transcribe`、`whisper-1`。
   */
  model: OpenAIModel;

  /**
   * 语言。
   *
   * API：Audio transcription。
   * 说明：可传 ISO-639-1 语言代码帮助提升准确率。
   */
  language?: string;

  /**
   * 提示词。
   *
   * API：Audio transcription。
   * 说明：可提供术语、上下文或格式提示。
   */
  prompt?: string;

  /**
   * 返回格式。
   *
   * API：Audio transcription。
   * 说明：控制返回纯文本、JSON、SRT、verbose JSON 或 VTT。
   */
  response_format?: 'json' | 'text' | 'srt' | 'verbose_json' | 'vtt';

  /**
   * 采样温度。
   *
   * API：Audio transcription。
   * 说明：值越高越随机，0 表示更确定。
   */
  temperature?: number;

  /**
   * 时间戳粒度。
   *
   * API：Audio transcription。
   * 说明：verbose JSON 下可请求按 segment 或 word 返回时间戳。
   */
  timestamp_granularities?: Array<'word' | 'segment'>;

  /**
   * 是否流式返回。
   *
   * API：Audio transcription。
   * 说明：支持流式转写事件的模型可使用。
   */
  stream?: boolean;
}

/**
 * 创建翻译请求。
 *
 * API：`POST /v1/audio/translations`。
 * 说明：把音频翻译成英文文本。
 */
export interface TranslationCreateParams {
  /**
   * 音频文件。
   *
   * API：Audio translation。
   * 说明：Harmony HTTP 层负责转换为 multipart 上传。
   */
  file: string;

  /**
   * 模型 ID。
   *
   * API：Audio translation。
   * 说明：常见为 `whisper-1`。
   */
  model: OpenAIModel;

  /**
   * 提示词。
   *
   * API：Audio translation。
   * 说明：提供上下文可提升翻译质量。
   */
  prompt?: string;

  /**
   * 返回格式。
   *
   * API：Audio translation。
   * 说明：控制返回纯文本、JSON、SRT、verbose JSON 或 VTT。
   */
  response_format?: 'json' | 'text' | 'srt' | 'verbose_json' | 'vtt';

  /**
   * 采样温度。
   *
   * API：Audio translation。
   * 说明：值越低越确定。
   */
  temperature?: number;
}

/**
 * 音频转写或翻译响应。
 *
 * API：`POST /v1/audio/transcriptions`、`POST /v1/audio/translations`。
 * 说明：JSON/verbose JSON 响应使用该模型，纯文本/SRT/VTT 可由 client 层作为 string 返回。
 */
export interface Transcription {
  /**
   * 文本结果。
   *
   * API：Audio transcription、Audio translation 响应。
   * 说明：转写或翻译后的文本。
   */
  text: string;

  /**
   * 任务类型。
   *
   * API：Audio transcription verbose JSON 响应。
   * 说明：例如 `transcribe` 或 `translate`。
   */
  task?: string;

  /**
   * 语言。
   *
   * API：Audio transcription verbose JSON 响应。
   * 说明：检测或请求使用的语言。
   */
  language?: string;

  /**
   * 音频时长。
   *
   * API：Audio transcription verbose JSON 响应。
   * 说明：单位通常为秒。
   */
  duration?: number;

  /**
   * 分段结果。
   *
   * API：Audio transcription verbose JSON 响应。
   * 说明：包含每个语音片段的起止时间和文本等信息。
   */
  segments?: Array<JsonObject>;

  /**
   * 词级结果。
   *
   * API：Audio transcription verbose JSON 响应。
   * 说明：当请求 word 时间戳时返回。
   */
  words?: Array<JsonObject>;
}

/**
 * 自定义 Voice 对象。
 *
 * API：`POST /v1/audio/voices`。
 * 说明：创建后可用于 TTS 和 Realtime audio output。
 */
export interface Voice {
  /** 对象类型。API：Audio voices。说明：固定为 `audio.voice`。 */
  object: 'audio.voice';
  /** Voice ID。API：Audio voices。说明：后续作为 voice custom object 引用。 */
  id: string;
  /** 名称。API：Audio voices。说明：创建自定义声音时提供的名称。 */
  name: string;
  /** 创建时间。API：Audio voices。说明：Unix 秒级时间戳。 */
  created_at: number;
}

/**
 * 创建 Voice 参数。
 *
 * API：`POST /v1/audio/voices`。
 * 说明：需要音频样本和已上传的 consent recording。
 */
export interface VoiceCreateParams {
  /** 名称。API：Create voice。说明：新 voice 的显示名称。 */
  name: string;
  /** Consent ID。API：Create voice。说明：授权录音 ID，例如 `cons_1234`。 */
  consent: string;
  /** 音频样本。API：Create voice。说明：本地音频文件路径或 URI，multipart 字段为 `audio_sample`。 */
  audio_sample: string;
}

/**
 * Voice consent 对象。
 *
 * API：`/v1/audio/voice_consents`。
 * 说明：授权创建自定义 voice 的同意录音 metadata。
 */
export interface VoiceConsent {
  /** 对象类型。API：Audio voice consents。说明：固定为 `audio.voice_consent`。 */
  object: 'audio.voice_consent';
  /** Consent ID。API：Audio voice consents。说明：创建 voice 时引用。 */
  id: string;
  /** 名称。API：Audio voice consents。说明：同意录音标签。 */
  name: string;
  /** 语言。API：Audio voice consents。说明：BCP 47 语言标签，例如 `en-US`。 */
  language: string;
  /** 创建时间。API：Audio voice consents。说明：Unix 秒级时间戳。 */
  created_at: number;
}

/**
 * 创建 Voice consent 参数。
 *
 * API：`POST /v1/audio/voice_consents`。
 * 说明：上传同意录音，供后续创建自定义 voice。
 */
export interface VoiceConsentCreateParams {
  /** 名称。API：Create voice consent。说明：同意录音标签。 */
  name: string;
  /** 语言。API：Create voice consent。说明：BCP 47 语言标签。 */
  language: string;
  /** 录音文件。API：Create voice consent。说明：本地文件路径或 URI，multipart 字段为 `recording`。 */
  recording: string;
}

/**
 * 更新 Voice consent 参数。
 *
 * API：`POST /v1/audio/voice_consents/{consent_id}`。
 * 说明：只更新 metadata，不替换底层音频。
 */
export interface VoiceConsentUpdateParams {
  /** 名称。API：Update voice consent。说明：新的同意录音标签。 */
  name: string;
}

/** Voice consent 列表参数。API：List voice consents。说明：支持 limit/after 分页。 */
export interface VoiceConsentListParams extends CursorPageParams {
}

/** Voice consent 列表响应。API：List voice consents。说明：列表元素为 consent metadata。 */
export type VoiceConsentListResponse = OpenAIListResponse<VoiceConsent>;

/** 删除 Voice consent 响应。API：Delete voice consent。说明：表示删除结果。 */
export interface VoiceConsentDeleted {
  /** 对象类型。API：Delete voice consent。说明：通常为 `audio.voice_consent`。 */
  object: string;
  /** Consent ID。API：Delete voice consent。说明：被删除的 consent ID。 */
  id: string;
  /** 删除结果。API：Delete voice consent。说明：`true` 表示已删除。 */
  deleted: boolean;
}
