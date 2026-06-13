// 图片生成后端类型
export type ImageGenerationBackend = 'sd_webui' | 'comfyui' | 'openai_image' | 'workers_ai';

// 图片生成任务状态
export type ImageGenerationStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// 图片生成参数
export interface ImageGenerationParams {
  /**
   * 后端类型，由当前实例内部维护。
   */
  backend: ImageGenerationBackend;
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * negative Prompt 值，由当前实例内部维护。
   */
  negativePrompt: string;
  /**
   * width 值，由当前实例内部维护。
   */
  width: number;
  /**
   * height 值，由当前实例内部维护。
   */
  height: number;
  /**
   * steps 列表，由当前实例内部维护。
   */
  steps: number;
  /**
   * cfg 值，由当前实例内部维护。
   */
  cfg: number;
  /**
   * seed 值，由当前实例内部维护。
   */
  seed: number;
  /**
   * sampler 值，由当前实例内部维护。
   */
  sampler: string;
  /**
   * batch Size 值，由当前实例内部维护。
   */
  batchSize: number;
}

// 图片生成结果元数据
export interface ImageGenerationMetadata {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model?: string;
  /**
   * seed 值，由当前实例内部维护。
   */
  seed?: string;
  /**
   * backend Task 标识。
   */
  backendTaskId?: string;
  /**
   * request 标识。
   */
  requestId?: string;
}

// 图片生成任务
export interface ImageGenerationTask {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * 后端类型，由当前实例内部维护。
   */
  backend: ImageGenerationBackend;
  /**
   * 调用参数。
   */
  params: ImageGenerationParams;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: ImageGenerationStatus;
  /**
   * progress 列表，由当前实例内部维护。
   */
  progress: number;
  /**
   * result Attachment 标识列表。
   */
  resultAttachmentIds: Array<string>;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: ImageGenerationMetadata;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

// 图片生成预设
export interface ImageGenerationPreset {
  /**
   * preset 标识。
   */
  presetId: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * 调用参数。
   */
  params: ImageGenerationParams;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

// SD WebUI 请求体
export interface SdWebUIRequest {
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * negative prompt 值，由当前实例内部维护。
   */
  negative_prompt: string;
  /**
   * width 值，由当前实例内部维护。
   */
  width: number;
  /**
   * height 值，由当前实例内部维护。
   */
  height: number;
  /**
   * steps 列表，由当前实例内部维护。
   */
  steps: number;
  /**
   * cfg scale 值，由当前实例内部维护。
   */
  cfg_scale: number;
  /**
   * seed 值，由当前实例内部维护。
   */
  seed: number;
  /**
   * sampler name 值，由当前实例内部维护。
   */
  sampler_name: string;
  /**
   * batch size 值，由当前实例内部维护。
   */
  batch_size: number;
}

// ComfyUI 请求体
export interface ComfyUIRequest {
  /**
   * workflow 值，由当前实例内部维护。
   */
  workflow: Object;
  /**
   * client id 值，由当前实例内部维护。
   */
  client_id: string;
}

// OpenAI 图片请求体
export interface OpenAIImageRequest {
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * n 值，由当前实例内部维护。
   */
  n: number;
  /**
   * size 值，由当前实例内部维护。
   */
  size: string;
  /**
   * response format 值，由当前实例内部维护。
   */
  response_format: string;
}

// Workers AI 图片请求体
export interface WorkersAIRequest {
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * negative prompt 值，由当前实例内部维护。
   */
  negative_prompt: string;
  /**
   * width 值，由当前实例内部维护。
   */
  width: number;
  /**
   * height 值，由当前实例内部维护。
   */
  height: number;
  /**
   * num steps 列表，由当前实例内部维护。
   */
  num_steps: number;
  /**
   * guidance 值，由当前实例内部维护。
   */
  guidance: number;
  /**
   * seed 值，由当前实例内部维护。
   */
  seed: number;
}

// 事件 payload
export interface ImageGenerationStartedPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成事件发布时携带的数据结构。
 */
export interface ImageGenerationProgressPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成事件发布时携带的数据结构。
 */
export interface ImageGenerationCompletedPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成事件发布时携带的数据结构。
 */
export interface ImageGenerationFailedPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成事件发布时携带的数据结构。
 */
export interface ImageGenerationCancelledPayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成事件发布时携带的数据结构。
 */
export interface ImageGenerationPresetSavedPayload {
  /**
   * preset 值，由当前实例内部维护。
   */
  preset: ImageGenerationPreset;
}

/**
 * 描述图片生成模块在运行时交换的数据结构。
 */
export interface ImageGenerationExportData {
  /**
   * presets 列表，由当前实例内部维护。
   */
  presets: Array<ImageGenerationPreset>;
  /**
   * tasks 列表，由当前实例内部维护。
   */
  tasks: Array<ImageGenerationTask>;
}
