// Caption 提供商
export type CaptionProvider = 'openai_vision' | 'local' | 'custom';
// Caption 任务状态
export type CaptionTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

export interface CaptionParams {
  imageAttachmentId: string;
  provider: CaptionProvider;
  prompt: string;
  model: string;
  autoCaption: boolean;
}

export interface CaptionTask {
  taskId: string;
  params: CaptionParams;
  status: CaptionTaskStatus;
  progress: number;
  resultText: string;
  resultAttachmentId: string;
  error: string;
  createdAt: number;
  updatedAt: number;
}

export interface CaptionResult {
  taskId: string;
  text: string;
  attachmentId: string;
}

export interface VisionImageUrl { url: string; }
export interface VisionContentPart { type: string; text: string; image_url: VisionImageUrl; }
export interface VisionMessage { role: string; content: Array<VisionContentPart>; }
export interface VisionRequest { model: string; messages: Array<VisionMessage>; }

// 事件 payload
export interface CaptionStartedPayload { task: CaptionTask; }
export interface CaptionProgressPayload { task: CaptionTask; }
export interface CaptionCompletedPayload { task: CaptionTask; }
export interface CaptionFailedPayload { task: CaptionTask; }
export interface CaptionCancelledPayload { task: CaptionTask; }
export interface CaptionExportData { tasks: Array<CaptionTask>; }
