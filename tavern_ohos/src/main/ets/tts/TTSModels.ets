// TTS 提供商类型
export type TTSProvider = 'openai' | 'elevenlabs' | 'edge' | 'system';

// TTS 任务状态
export type TTSTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// TTS 语音配置
export interface TTSVoiceProfile {
  /**
   * profile 标识。
   */
  profileId: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: TTSProvider;
  /**
   * voice 标识。
   */
  voiceId: string;
  /**
   * language 值，由当前实例内部维护。
   */
  language: string;
  /**
   * speed 值，由当前实例内部维护。
   */
  speed: number;
  /**
   * pitch 值，由当前实例内部维护。
   */
  pitch: number;
  /**
   * format 值，由当前实例内部维护。
   */
  format: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

// TTS 合成请求参数
export interface TTSSynthesisParams {
  /**
   * 文本内容。
   */
  text: string;
  /**
   * voice Profile 标识。
   */
  voiceProfileId: string;
  /**
   * skip Code Blocks 列表，由当前实例内部维护。
   */
  skipCodeBlocks: boolean;
  /**
   * speed 值，由当前实例内部维护。
   */
  speed: number;
  /**
   * pitch 值，由当前实例内部维护。
   */
  pitch: number;
  /**
   * format 值，由当前实例内部维护。
   */
  format: string;
}

// TTS 合成任务
export interface TTSTask {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * 调用参数。
   */
  params: TTSSynthesisParams;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: TTSTaskStatus;
  /**
   * progress 列表，由当前实例内部维护。
   */
  progress: number;
  /**
   * result Attachment 标识。
   */
  resultAttachmentId: string;
  /**
   * duration 值，由当前实例内部维护。
   */
  duration: number;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

// TTS 音频附件结果
export interface TTSAudioResult {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * attachment 标识。
   */
  attachmentId: string;
  /**
   * duration 值，由当前实例内部维护。
   */
  duration: number;
  /**
   * format 值，由当前实例内部维护。
   */
  format: string;
}

// OpenAI TTS 请求体
export interface OpenAITTSRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * 输入数据。
   */
  input: string;
  /**
   * voice 值，由当前实例内部维护。
   */
  voice: string;
  /**
   * speed 值，由当前实例内部维护。
   */
  speed: number;
  /**
   * response format 值，由当前实例内部维护。
   */
  response_format: string;
}

// Edge TTS 请求体
export interface EdgeTTSRequest {
  /**
   * 文本内容。
   */
  text: string;
  /**
   * voice 值，由当前实例内部维护。
   */
  voice: string;
  /**
   * rate 值，由当前实例内部维护。
   */
  rate: number;
  /**
   * pitch 值，由当前实例内部维护。
   */
  pitch: number;
}

// 事件 payload
export interface TTSSynthesisStartedPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TTSTask;
}

/**
 * 描述文字转语音事件发布时携带的数据结构。
 */
export interface TTSSynthesisProgressPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TTSTask;
}

/**
 * 描述文字转语音事件发布时携带的数据结构。
 */
export interface TTSSynthesisCompletedPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TTSTask;
}

/**
 * 描述文字转语音事件发布时携带的数据结构。
 */
export interface TTSSynthesisFailedPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TTSTask;
}

/**
 * 描述文字转语音事件发布时携带的数据结构。
 */
export interface TTSSynthesisCancelledPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TTSTask;
}

/**
 * 描述文字转语音事件发布时携带的数据结构。
 */
export interface TTSVoiceProfileSavedPayload {
  /**
   * profile 值，由当前实例内部维护。
   */
  profile: TTSVoiceProfile;
}

/**
 * 描述文字转语音模块在运行时交换的数据结构。
 */
export interface TTSExportData {
  /**
   * profiles 列表，由当前实例内部维护。
   */
  profiles: Array<TTSVoiceProfile>;
  /**
   * tasks 列表，由当前实例内部维护。
   */
  tasks: Array<TTSTask>;
}
