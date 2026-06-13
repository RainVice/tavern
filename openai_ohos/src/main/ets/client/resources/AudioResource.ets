import type {
  SpeechCreateParams,
  SpeechResponse,
  Transcription,
  TranscriptionCreateParams,
  TranslationCreateParams,
  Voice,
  VoiceConsent,
  VoiceConsentCreateParams,
  VoiceConsentDeleted,
  VoiceConsentListParams,
  VoiceConsentListResponse,
  VoiceConsentUpdateParams,
  VoiceCreateParams,
} from '../../models/Audio';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { buildCursorListPath, buildFilePart, buildTextPart, encodePathParam } from '../core/RequestUtils';
import type { OpenAIMultipartFormData } from '../core/Types';

/**
 * Audio speech 资源入口。
 *
 * API：`POST /v1/audio/speech`。
 * 说明：把文本合成为语音，响应数据以 base64 字符串放入 `SpeechResponse.data`。
 */
export interface OpenAIAudioSpeechResource {
  /**
   * 创建语音。
   *
   * API：`POST /v1/audio/speech`。
   * 说明：返回 base64 编码的音频数据。
   */
  create(params: SpeechCreateParams): Promise<SpeechResponse>;
}

/**
 * Audio transcriptions 资源入口。
 *
 * API：`POST /v1/audio/transcriptions`。
 * 说明：multipart 上传音频并转写为文本。
 */
export interface OpenAIAudioTranscriptionsResource {
  create(params: TranscriptionCreateParams): Promise<Transcription>;
}

/**
 * Audio translations 资源入口。
 *
 * API：`POST /v1/audio/translations`。
 * 说明：multipart 上传音频并翻译为英文。
 */
export interface OpenAIAudioTranslationsResource {
  create(params: TranslationCreateParams): Promise<Transcription>;
}

/**
 * Audio voices 资源入口。
 *
 * API：`POST /v1/audio/voices`。
 * 说明：创建自定义声音。
 */
export interface OpenAIAudioVoicesResource {
  create(params: VoiceCreateParams): Promise<Voice>;
}

/**
 * Audio voice consents 资源入口。
 *
 * API：`/v1/audio/voice_consents`。
 * 说明：管理创建自定义声音所需的同意录音。
 */
export interface OpenAIAudioVoiceConsentsResource {
  create(params: VoiceConsentCreateParams): Promise<VoiceConsent>;
  list(params?: VoiceConsentListParams): Promise<VoiceConsentListResponse>;
  retrieve(consentID: string): Promise<VoiceConsent>;
  update(consentID: string, params: VoiceConsentUpdateParams): Promise<VoiceConsent>;
  delete(consentID: string): Promise<VoiceConsentDeleted>;
}

export interface OpenAIAudioResource {
  speech: OpenAIAudioSpeechResource;
  transcriptions: OpenAIAudioTranscriptionsResource;
  translations: OpenAIAudioTranslationsResource;
  voices: OpenAIAudioVoicesResource;
  voiceConsents: OpenAIAudioVoiceConsentsResource;
}

class AudioSpeechResource implements OpenAIAudioSpeechResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: SpeechCreateParams): Promise<SpeechResponse> {
    const data = await this.client.postBinary('/audio/speech', params);
    const format = params.response_format === undefined ? 'mp3' : params.response_format;
    return {
      data: data,
      response_format: format,
    };
  }
}

class AudioTranscriptionsResource implements OpenAIAudioTranscriptionsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: TranscriptionCreateParams): Promise<Transcription> {
    const parts = this.buildTranscriptionParts(params);
    const body = await this.client.postMultipart('/audio/transcriptions', parts);
    return JSON.parse(body) as Transcription;
  }

  private buildTranscriptionParts(params: TranscriptionCreateParams): Array<OpenAIMultipartFormData> {
    const parts: Array<OpenAIMultipartFormData> = [];
    parts.push(buildFilePart('file', params.file));
    parts.push(buildTextPart('model', params.model));
    if (params.language !== undefined) {
      parts.push(buildTextPart('language', params.language));
    }
    if (params.prompt !== undefined) {
      parts.push(buildTextPart('prompt', params.prompt));
    }
    if (params.response_format !== undefined) {
      parts.push(buildTextPart('response_format', params.response_format));
    }
    if (params.temperature !== undefined) {
      parts.push(buildTextPart('temperature', params.temperature.toString()));
    }
    return parts;
  }
}

class AudioTranslationsResource implements OpenAIAudioTranslationsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: TranslationCreateParams): Promise<Transcription> {
    const parts: Array<OpenAIMultipartFormData> = [];
    parts.push(buildFilePart('file', params.file));
    parts.push(buildTextPart('model', params.model));
    if (params.prompt !== undefined) {
      parts.push(buildTextPart('prompt', params.prompt));
    }
    if (params.response_format !== undefined) {
      parts.push(buildTextPart('response_format', params.response_format));
    }
    if (params.temperature !== undefined) {
      parts.push(buildTextPart('temperature', params.temperature.toString()));
    }
    const body = await this.client.postMultipart('/audio/translations', parts);
    return JSON.parse(body) as Transcription;
  }
}

class AudioVoicesResource implements OpenAIAudioVoicesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: VoiceCreateParams): Promise<Voice> {
    const parts: Array<OpenAIMultipartFormData> = [];
    parts.push(buildTextPart('name', params.name));
    parts.push(buildTextPart('consent', params.consent));
    parts.push(buildFilePart('audio_sample', params.audio_sample));
    const body = await this.client.postMultipart('/audio/voices', parts);
    return JSON.parse(body) as Voice;
  }
}

class AudioVoiceConsentsResource implements OpenAIAudioVoiceConsentsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: VoiceConsentCreateParams): Promise<VoiceConsent> {
    const parts: Array<OpenAIMultipartFormData> = [];
    parts.push(buildTextPart('name', params.name));
    parts.push(buildTextPart('language', params.language));
    parts.push(buildFilePart('recording', params.recording));
    const body = await this.client.postMultipart('/audio/voice_consents', parts);
    return JSON.parse(body) as VoiceConsent;
  }

  async list(params?: VoiceConsentListParams): Promise<VoiceConsentListResponse> {
    const body = await this.client.get(buildCursorListPath('/audio/voice_consents', params));
    return JSON.parse(body) as VoiceConsentListResponse;
  }

  async retrieve(consentID: string): Promise<VoiceConsent> {
    const body = await this.client.get('/audio/voice_consents/' + encodePathParam(consentID));
    return JSON.parse(body) as VoiceConsent;
  }

  async update(consentID: string, params: VoiceConsentUpdateParams): Promise<VoiceConsent> {
    const body = await this.client.post('/audio/voice_consents/' + encodePathParam(consentID), params);
    return JSON.parse(body) as VoiceConsent;
  }

  async delete(consentID: string): Promise<VoiceConsentDeleted> {
    const body = await this.client.delete('/audio/voice_consents/' + encodePathParam(consentID));
    return JSON.parse(body) as VoiceConsentDeleted;
  }
}

export class AudioResource implements OpenAIAudioResource {
  speech: OpenAIAudioSpeechResource;
  transcriptions: OpenAIAudioTranscriptionsResource;
  translations: OpenAIAudioTranslationsResource;
  voices: OpenAIAudioVoicesResource;
  voiceConsents: OpenAIAudioVoiceConsentsResource;

  constructor(client: OpenAIRequestClient) {
    this.speech = new AudioSpeechResource(client);
    this.transcriptions = new AudioTranscriptionsResource(client);
    this.translations = new AudioTranslationsResource(client);
    this.voices = new AudioVoicesResource(client);
    this.voiceConsents = new AudioVoiceConsentsResource(client);
  }
}
