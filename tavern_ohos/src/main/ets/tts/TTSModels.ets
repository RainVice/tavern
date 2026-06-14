// TTS 提供商类型
export type TTSProvider = 'openai' | 'elevenlabs' | 'edge' | 'system';

// TTS 任务状态
export type TTSTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// TTS 语音配置
export interface TTSVoiceProfile {
  /**
   * 语音配置唯一标识，由 saveVoiceProfile 自动生成，用于在配置管理流程中定位。
   */
  profileId: string;
  /**
   * 配置名称，用于 UI 展示和用户识别。
   */
  name: string;
  /**
   * TTS 提供商类型，决定合成请求发送到哪个后端服务（OpenAI / ElevenLabs / Edge / System）。
   */
  provider: TTSProvider;
  /**
   * 音色标识，指定使用的说话人声音。
   */
  voiceId: string;
  /**
   * 语言代码。
   */
  language: string;
  /**
   * 语速值，影响语音合成的播放速度。
   */
  speed: number;
  /**
   * 音调值，影响语音合成的声音高低。
   */
  pitch: number;
  /**
   * 音频格式（如 "mp3" / "wav" / "ogg"）。
   */
  format: string;
  /**
   * 配置创建时间戳。
   */
  createdAt: number;
  /**
   * 最近更新时间戳。
   */
  updatedAt: number;
}

// TTS 合成请求参数
export interface TTSSynthesisParams {
  /**
   * 要合成的文本内容，由消息文本或用户输入提供。
   */
  text: string;
  /**
   * 使用的语音配置标识，用于查找对应的 TTSVoiceProfile。
   */
  voiceProfileId: string;
  /**
   * 是否跳过代码块不合成，用于过滤掉技术内容仅合成自然语言部分。
   */
  skipCodeBlocks: boolean;
  /**
   * 语速值，覆盖语音配置中的默认语速。
   */
  speed: number;
  /**
   * 音调值，覆盖语音配置中的默认音调。
   */
  pitch: number;
  /**
   * 音频格式。
   */
  format: string;
}

// TTS 合成任务
export interface TTSTask {
  /**
   * 任务标识，由 synthesize 自动生成（格式为 "tts-{计数器}"）。
   */
  taskId: string;
  /**
   * 合成参数，包含文本、语音配置和音频设置。
   */
  params: TTSSynthesisParams;
  /**
   * 任务状态。
   */
  status: TTSTaskStatus;
  /**
   * 进度百分比（0-100），由 updateProgress 更新。
   */
  progress: number;
  /**
   * 结果附件标识，合成完成后由 completeSynthesis 写入，关联生成的音频文件。
   */
  resultAttachmentId: string;
  /**
   * 音频时长（秒），由 completeSynthesis 写入。
   */
  duration: number;
  /**
   * 错误信息。
   */
  error: string;
  /**
   * 创建时间戳。
   */
  createdAt: number;
  /**
   * 最近更新时间戳。
   */
  updatedAt: number;
}

// TTS 音频附件结果
export interface TTSAudioResult {
  /**
   * 任务标识，关联到合成任务的 taskId。
   */
  taskId: string;
  /**
   * 附件标识，用于在附件管理系统中定位生成的音频文件。
   */
  attachmentId: string;
  /**
   * 音频时长。
   */
  duration: number;
  /**
   * 音频格式。
   */
  format: string;
}

// OpenAI TTS 请求体
export interface OpenAITTSRequest {
  /**
   * 模型名称（如 "tts-1" / "tts-1-hd"），决定使用的 TTS 模型版本。
   */
  model: string;
  /**
   * 输入文本。
   */
  input: string;
  /**
   * 音色标识。
   */
  voice: string;
  /**
   * 语速值。
   */
  speed: number;
  /**
   * 响应格式。
   */
  response_format: string;
}

// Edge TTS 请求体
export interface EdgeTTSRequest {
  /**
   * 要合成的文本。
   */
  text: string;
  /**
   * 音色标识。
   */
  voice: string;
  /**
   * 语速百分比。
   */
  rate: number;
  /**
   * 音调值。
   */
  pitch: number;
}

// 事件 payload
export interface TTSSynthesisStartedPayload {
  /**
   * 已启动的合成任务。
   */
  task: TTSTask;
}

/**
 * 描述文字转语音进度事件发布时携带的数据结构。
 * TTSRuntime 在 updateProgress 后发布 tts.synthesis.progress 事件。
 */
export interface TTSSynthesisProgressPayload {
  /**
   * 当前合成任务。
   */
  task: TTSTask;
}

/**
 * 描述文字转语音完成事件发布时携带的数据结构。
 * TTSRuntime 在 completeSynthesis 后发布 tts.synthesis.completed 事件。
 */
export interface TTSSynthesisCompletedPayload {
  /**
   * 已完成的合成任务。
   */
  task: TTSTask;
}

/**
 * 描述文字转语音失败事件发布时携带的数据结构。
 * TTSRuntime 在 failSynthesis 后发布 tts.synthesis.failed 事件。
 */
export interface TTSSynthesisFailedPayload {
  /**
   * 失败的合成任务。
   */
  task: TTSTask;
}

/**
 * 描述文字转语音取消事件发布时携带的数据结构。
 * TTSRuntime 在 cancelSynthesis 后发布 tts.synthesis.cancelled 事件。
 */
export interface TTSSynthesisCancelledPayload {
  /**
   * 被取消的合成任务。
   */
  task: TTSTask;
}

/**
 * 描述语音配置保存事件发布时携带的数据结构。
 * TTSRuntime 在 saveVoiceProfile 后发布 tts.voice.profile.saved 事件。
 */
export interface TTSVoiceProfileSavedPayload {
  /**
   * 已保存的语音配置。
   */
  profile: TTSVoiceProfile;
}

/**
 * 描述 TTS 导出数据的结构。
 * 在 exportData 和 importData 流程中使用。
 */
export interface TTSExportData {
  /**
   * 所有语音配置。
   */
  profiles: Array<TTSVoiceProfile>;
  /**
   * 所有任务记录。
   */
  tasks: Array<TTSTask>;
}
