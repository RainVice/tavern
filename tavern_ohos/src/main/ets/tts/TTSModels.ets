import type { MediaFormat } from '../contracts/PublicContracts';

/**
 * TTS 提供商类型：openai、elevenlabs、edge 或 system（系统内置）。
 */
export type TTSProvider = 'openai' | 'elevenlabs' | 'edge' | 'system';

/**
 * TTS 合成任务状态：pending（等待中）、running（进行中）、completed（已完成）、failed（失败）、cancelled（已取消）。
 */
export type TTSTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

/**
 * TTS 语音配置，定义一种音色的完整参数。
 */
export interface TTSVoiceProfile {
  /**
   * 语音配置的唯一标识。
   */
  profileId: string;
  /**
   * 语音配置的名称。
   */
  name: string;
  /**
   * 提供商类型。
   */
  provider: TTSProvider;
  /**
   * 音色标识，由提供商定义。
   */
  voiceId: string;
  /**
   * 语言代码。
   */
  language: string;
  /**
   * 语速倍率。
   */
  speed: number;
  /**
   * 音高调整值。
   */
  pitch: number;
  /**
   * 音频格式。
   */
  format: MediaFormat;
  /**
   * 配置创建时间戳。
   */
  createdAt: number;
  /**
   * 配置最后更新时间戳。
   */
  updatedAt: number;
}

/**
 * TTS 合成请求参数，指定要合成的文本和音色配置。
 */
export interface TTSSynthesisParams {
  /**
   * 待合成的文本内容。
   */
  text: string;
  /**
   * 使用的语音配置标识。
   */
  voiceProfileId: string;
  /**
   * 是否跳过代码块内容的合成。
   */
  skipCodeBlocks: boolean;
  /**
   * 语速倍率。
   */
  speed: number;
  /**
   * 音高调整值。
   */
  pitch: number;
  /**
   * 音频输出格式。
   */
  format: MediaFormat;
}

/**
 * TTS 合成任务记录，包含合成过程中的状态和结果信息。
 */
export interface TTSTask {
  /**
   * 任务唯一标识。
   */
  taskId: string;
  /**
   * 合成请求参数。
   */
  params: TTSSynthesisParams;
  /**
   * 任务状态。
   */
  status: TTSTaskStatus;
  /**
   * 任务进度百分比（0-100）。
   */
  progress: number;
  /**
   * 合成结果附件的标识。
   */
  resultAttachmentId: string;
  /**
   * 合成音频的时长（秒）。
   */
  duration: number;
  /**
   * 任务失败时的错误描述。
   */
  error: string;
  /**
   * 任务创建时间戳。
   */
  createdAt: number;
  /**
   * 任务最后更新时间戳。
   */
  updatedAt: number;
}

/**
 * TTS 合成音频的结果信息。
 */
export interface TTSAudioResult {
  /**
   * 关联的任务标识。
   */
  taskId: string;
  /**
   * 合成音频的附件标识。
   */
  attachmentId: string;
  /**
   * 音频时长（秒）。
   */
  duration: number;
  /**
   * 音频格式。
   */
  format: MediaFormat;
}

/**
 * OpenAI TTS API 的请求体结构。
 */
export interface OpenAITTSRequest {
  /**
   * 模型名称。
   */
  model: string;
  /**
   * 待合成的输入文本。
   */
  input: string;
  /**
   * 音色标识。
   */
  voice: string;
  /**
   * 语速倍率。
   */
  speed: number;
  /**
   * 响应音频格式。
   */
  response_format: string;
}

/**
 * Edge TTS API 的请求体结构。
 */
export interface EdgeTTSRequest {
  /**
   * 待合成的文本内容。
   */
  text: string;
  /**
   * 音色标识。
   */
  voice: string;
  /**
   * 语速调整值。
   */
  rate: number;
  /**
   * 音高调整值。
   */
  pitch: number;
}

/**
 * TTS 合成任务启动事件发布时携带的负载。
 */
export interface TTSSynthesisStartedPayload {
  /**
   * 已启动的合成任务。
   */
  task: TTSTask;
}

/**
 * TTS 合成任务进度更新事件发布时携带的负载。
 */
export interface TTSSynthesisProgressPayload {
  /**
   * 进度已更新的合成任务。
   */
  task: TTSTask;
}

/**
 * TTS 合成任务完成事件发布时携带的负载。
 */
export interface TTSSynthesisCompletedPayload {
  /**
   * 已完成的合成任务。
   */
  task: TTSTask;
}

/**
 * TTS 合成任务失败事件发布时携带的负载。
 */
export interface TTSSynthesisFailedPayload {
  /**
   * 已失败的合成任务。
   */
  task: TTSTask;
}

/**
 * TTS 合成任务取消事件发布时携带的负载。
 */
export interface TTSSynthesisCancelledPayload {
  /**
   * 已取消的合成任务。
   */
  task: TTSTask;
}

/**
 * TTS 语音配置保存事件发布时携带的负载。
 */
export interface TTSVoiceProfileSavedPayload {
  /**
   * 已保存的语音配置。
   */
  profile: TTSVoiceProfile;
}

/**
 * TTS 数据的导出结构，包含所有语音配置和任务记录。
 */
export interface TTSExportData {
  /**
   * 所有语音配置列表。
   */
  profiles: Array<TTSVoiceProfile>;
  /**
   * 所有合成任务列表。
   */
  tasks: Array<TTSTask>;
}
