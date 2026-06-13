// ASR 提供商
export type ASRProvider = 'openai_whisper' | 'local_whisper' | 'system';

// ASR 任务状态
export type ASRTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// ASR 转录参数
export interface ASRTranscriptionParams {
  /**
   * 来源类型，由当前实例内部维护。
   */
  source: string;
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: ASRProvider;
  /**
   * language 值，由当前实例内部维护。
   */
  language: string;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * auto Send 值，由当前实例内部维护。
   */
  autoSend: boolean;
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
}

// ASR 转录任务
export interface ASRTask {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * 调用参数。
   */
  params: ASRTranscriptionParams;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: ASRTaskStatus;
  /**
   * progress 列表，由当前实例内部维护。
   */
  progress: number;
  /**
   * transcript 值，由当前实例内部维护。
   */
  transcript: string;
  /**
   * confidence 值，由当前实例内部维护。
   */
  confidence: number;
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

// 转录结果
export interface ASRTranscriptionResult {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * transcript 值，由当前实例内部维护。
   */
  transcript: string;
  /**
   * confidence 值，由当前实例内部维护。
   */
  confidence: number;
  /**
   * duration 值，由当前实例内部维护。
   */
  duration: number;
  /**
   * language 值，由当前实例内部维护。
   */
  language: string;
}

// OpenAI Whisper 请求体
export interface WhisperRequest {
  /**
   * file 值，由当前实例内部维护。
   */
  file: string;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * language 值，由当前实例内部维护。
   */
  language: string;
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * response format 值，由当前实例内部维护。
   */
  response_format: string;
}

// 事件 payload
export interface ASRTranscriptionStartedPayload {
  /**
   * 任务数据。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字事件发布时携带的数据结构。
 */
export interface ASRTranscriptionProgressPayload {
  /**
   * 任务数据。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字事件发布时携带的数据结构。
 */
export interface ASRTranscriptionCompletedPayload {
  /**
   * 任务数据。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字事件发布时携带的数据结构。
 */
export interface ASRTranscriptionFailedPayload {
  /**
   * 任务数据。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字事件发布时携带的数据结构。
 */
export interface ASRTranscriptionCancelledPayload {
  /**
   * 任务数据。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字模块在运行时交换的数据结构。
 */
export interface ASRExportData {
  /**
   * 任务列表。
   */
  tasks: Array<ASRTask>;
}
