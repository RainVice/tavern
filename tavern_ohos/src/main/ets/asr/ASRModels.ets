// ASR 提供商
export type ASRProvider = 'openai_whisper' | 'local_whisper' | 'system';

// ASR 任务状态
export type ASRTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// ASR 转录参数
export interface ASRTranscriptionParams {
  source: string;
  provider: ASRProvider;
  language: string;
  model: string;
  autoSend: boolean;
  prompt: string;
}

// ASR 转录任务
export interface ASRTask {
  taskId: string;
  params: ASRTranscriptionParams;
  status: ASRTaskStatus;
  progress: number;
  transcript: string;
  confidence: number;
  duration: number;
  error: string;
  createdAt: number;
  updatedAt: number;
}

// 转录结果
export interface ASRTranscriptionResult {
  taskId: string;
  transcript: string;
  confidence: number;
  duration: number;
  language: string;
}

// OpenAI Whisper 请求体
export interface WhisperRequest {
  file: string;
  model: string;
  language: string;
  prompt: string;
  response_format: string;
}

// 事件 payload
export interface ASRTranscriptionStartedPayload { task: ASRTask; }
export interface ASRTranscriptionProgressPayload { task: ASRTask; }
export interface ASRTranscriptionCompletedPayload { task: ASRTask; }
export interface ASRTranscriptionFailedPayload { task: ASRTask; }
export interface ASRTranscriptionCancelledPayload { task: ASRTask; }
export interface ASRExportData { tasks: Array<ASRTask>; }
