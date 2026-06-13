// TTS 提供商类型
export type TTSProvider = 'openai' | 'elevenlabs' | 'edge' | 'system';

// TTS 任务状态
export type TTSTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// TTS 语音配置
export interface TTSVoiceProfile {
  profileId: string;
  name: string;
  provider: TTSProvider;
  voiceId: string;
  language: string;
  speed: number;
  pitch: number;
  format: string;
  createdAt: number;
  updatedAt: number;
}

// TTS 合成请求参数
export interface TTSSynthesisParams {
  text: string;
  voiceProfileId: string;
  skipCodeBlocks: boolean;
  speed: number;
  pitch: number;
  format: string;
}

// TTS 合成任务
export interface TTSTask {
  taskId: string;
  params: TTSSynthesisParams;
  status: TTSTaskStatus;
  progress: number;
  resultAttachmentId: string;
  duration: number;
  error: string;
  createdAt: number;
  updatedAt: number;
}

// TTS 音频附件结果
export interface TTSAudioResult {
  taskId: string;
  attachmentId: string;
  duration: number;
  format: string;
}

// OpenAI TTS 请求体
export interface OpenAITTSRequest {
  model: string;
  input: string;
  voice: string;
  speed: number;
  response_format: string;
}

// Edge TTS 请求体
export interface EdgeTTSRequest {
  text: string;
  voice: string;
  rate: number;
  pitch: number;
}

// 事件 payload
export interface TTSSynthesisStartedPayload {
  task: TTSTask;
}

export interface TTSSynthesisProgressPayload {
  task: TTSTask;
}

export interface TTSSynthesisCompletedPayload {
  task: TTSTask;
}

export interface TTSSynthesisFailedPayload {
  task: TTSTask;
}

export interface TTSSynthesisCancelledPayload {
  task: TTSTask;
}

export interface TTSVoiceProfileSavedPayload {
  profile: TTSVoiceProfile;
}

export interface TTSExportData {
  profiles: Array<TTSVoiceProfile>;
  tasks: Array<TTSTask>;
}
