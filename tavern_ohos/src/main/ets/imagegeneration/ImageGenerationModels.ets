// 图片生成后端类型
export type ImageGenerationBackend = 'sd_webui' | 'comfyui' | 'openai_image' | 'workers_ai';

// 图片生成任务状态
export type ImageGenerationStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// 图片生成参数
export interface ImageGenerationParams {
  backend: ImageGenerationBackend;
  prompt: string;
  negativePrompt: string;
  width: number;
  height: number;
  steps: number;
  cfg: number;
  seed: number;
  sampler: string;
  batchSize: number;
}

// 图片生成结果元数据
export interface ImageGenerationMetadata {
  model?: string;
  seed?: string;
  backendTaskId?: string;
  requestId?: string;
}

// 图片生成任务
export interface ImageGenerationTask {
  taskId: string;
  backend: ImageGenerationBackend;
  params: ImageGenerationParams;
  status: ImageGenerationStatus;
  progress: number;
  resultAttachmentIds: Array<string>;
  error: string;
  metadata: ImageGenerationMetadata;
  createdAt: number;
  updatedAt: number;
}

// 图片生成预设
export interface ImageGenerationPreset {
  presetId: string;
  name: string;
  params: ImageGenerationParams;
  createdAt: number;
  updatedAt: number;
}

// SD WebUI 请求体
export interface SdWebUIRequest {
  prompt: string;
  negative_prompt: string;
  width: number;
  height: number;
  steps: number;
  cfg_scale: number;
  seed: number;
  sampler_name: string;
  batch_size: number;
}

// ComfyUI 请求体
export interface ComfyUIRequest {
  workflow: Object;
  client_id: string;
}

// OpenAI 图片请求体
export interface OpenAIImageRequest {
  model: string;
  prompt: string;
  n: number;
  size: string;
  response_format: string;
}

// Workers AI 图片请求体
export interface WorkersAIRequest {
  prompt: string;
  negative_prompt: string;
  width: number;
  height: number;
  num_steps: number;
  guidance: number;
  seed: number;
}

// 事件 payload
export interface ImageGenerationStartedPayload {
  task: ImageGenerationTask;
}

export interface ImageGenerationProgressPayload {
  task: ImageGenerationTask;
}

export interface ImageGenerationCompletedPayload {
  task: ImageGenerationTask;
}

export interface ImageGenerationFailedPayload {
  task: ImageGenerationTask;
}

export interface ImageGenerationCancelledPayload {
  task: ImageGenerationTask;
}

export interface ImageGenerationPresetSavedPayload {
  preset: ImageGenerationPreset;
}

export interface ImageGenerationExportData {
  presets: Array<ImageGenerationPreset>;
  tasks: Array<ImageGenerationTask>;
}
