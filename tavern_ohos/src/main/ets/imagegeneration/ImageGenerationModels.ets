/**
 * 支持的图片生成后端类型。
 * - 'sd_webui': Stable Diffusion WebUI
 * - 'comfyui': ComfyUI
 * - 'openai_image': OpenAI 图像接口
 * - 'workers_ai': Cloudflare Workers AI
 */
export type ImageGenerationBackend = 'sd_webui' | 'comfyui' | 'openai_image' | 'workers_ai';

/**
 * 图片生成任务的运行状态。
 * - 'pending': 等待执行
 * - 'running': 正在生成
 * - 'completed': 已完成
 * - 'failed': 生成失败
 * - 'cancelled': 已取消
 */
export type ImageGenerationStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

/**
 * 图片生成的核心参数集合，包含提示词、尺寸、采样参数等。
 */
export interface ImageGenerationParams {
  /**
   * 目标后端类型。
   */
  backend: ImageGenerationBackend;
  /**
   * 正向提示词，描述期望生成的画面内容。
   */
  prompt: string;
  /**
   * 反向提示词，描述画面中需要避免的内容。
   */
  negativePrompt: string;
  /**
   * 生成图片的宽度，单位为像素。
   */
  width: number;
  /**
   * 生成图片的高度，单位为像素。
   */
  height: number;
  /**
   * 采样步数，值越大生成细节越丰富但耗时越长。
   */
  steps: number;
  /**
   * 无分类器引导尺度（CFG Scale），值越大生成内容越贴合 prompt。
   */
  cfg: number;
  /**
   * 随机数种子，固定后可复现相同结果。
   */
  seed: number;
  /**
   * 采样器名称，如 Euler、DDIM 等。
   */
  sampler: string;
  /**
   * 单次生成批次数，控制一次生成几张图片。
   */
  batchSize: number;
}

/**
 * 图片生成结果的元数据，包含模型名称、种子、后端任务标识等。
 */
export interface ImageGenerationMetadata {
  /**
   * 生成所使用的模型名称。
   */
  model?: string;
  /**
   * 实际使用的种子值（字符串形式，与后端返回格式一致）。
   */
  seed?: string;
  /**
   * 后端任务标识，用于在对应后端的任务系统中追踪。
   */
  backendTaskId?: string;
  /**
   * 请求标识，用于关联日志或调试追溯。
   */
  requestId?: string;
}

/**
 * 图片生成任务实例，记录任务的完整生命周期数据。
 */
export interface ImageGenerationTask {
  /**
   * 任务唯一标识。
   */
  taskId: string;
  /**
   * 任务关联的后端类型。
   */
  backend: ImageGenerationBackend;
  /**
   * 调用参数副本。
   */
  params: ImageGenerationParams;
  /**
   * 当前运行状态。
   */
  status: ImageGenerationStatus;
  /**
   * 进度百分比，取值范围 0 – 100。
   */
  progress: number;
  /**
   * 生成结果的附件标识列表。
   */
  resultAttachmentIds: Array<string>;
  /**
   * 错误信息，失败时记录原因，正常状态为空字符串。
   */
  error: string;
  /**
   * 生成结果的元数据，如模型名称和种子值。
   */
  metadata: ImageGenerationMetadata;
  /**
   * 任务创建时间戳，单位为毫秒。
   */
  createdAt: number;
  /**
   * 任务最后更新时间戳，单位为毫秒。
   */
  updatedAt: number;
}

/**
 * 图片生成预设，保存一组常用参数以便快速复用。
 */
export interface ImageGenerationPreset {
  /**
   * 预设唯一标识。
   */
  presetId: string;
  /**
   * 预设名称，用于界面显示。
   */
  name: string;
  /**
   * 预设中保存的生成参数。
   */
  params: ImageGenerationParams;
  /**
   * 创建时间戳，单位为毫秒。
   */
  createdAt: number;
  /**
   * 最后更新时间戳，单位为毫秒。
   */
  updatedAt: number;
}

/**
 * Stable Diffusion WebUI 的 API 请求结构，遵循 AUTOMATIC1111 接口格式。
 */
export interface SdWebUIRequest {
  /**
   * 正向提示词。
   */
  prompt: string;
  /**
   * 反向提示词。
   */
  negative_prompt: string;
  /**
   * 图片宽度，单位为像素。
   */
  width: number;
  /**
   * 图片高度，单位为像素。
   */
  height: number;
  /**
   * 采样步数。
   */
  steps: number;
  /**
   * CFG 引导尺度。
   */
  cfg_scale: number;
  /**
   * 随机数种子。
   */
  seed: number;
  /**
   * 采样器名称。
   */
  sampler_name: string;
  /**
   * 批次大小。
   */
  batch_size: number;
}

/**
 * ComfyUI 的 API 请求结构。
 */
export interface ComfyUIRequest {
  /**
   * ComfyUI 工作流 JSON 对象。
   */
  workflow: Object;
  /**
   * 客户端标识，用于追踪请求来源。
   */
  client_id: string;
}

/**
 * OpenAI 图像生成 API 的请求结构。
 */
export interface OpenAIImageRequest {
  /**
   * 模型名称，如 dall-e-3。
   */
  model: string;
  /**
   * 图片描述提示词。
   */
  prompt: string;
  /**
   * 生成数量。
   */
  n: number;
  /**
   * 图片尺寸，如 "1024x1024"。
   */
  size: string;
  /**
   * 返回格式，如 "b64_json" 或 "url"。
   */
  response_format: string;
}

/**
 * Cloudflare Workers AI 图片生成 API 的请求结构。
 */
export interface WorkersAIRequest {
  /**
   * 正向提示词。
   */
  prompt: string;
  /**
   * 反向提示词。
   */
  negative_prompt: string;
  /**
   * 图片宽度，单位为像素。
   */
  width: number;
  /**
   * 图片高度，单位为像素。
   */
  height: number;
  /**
   * 采样步数。
   */
  num_steps: number;
  /**
   * 引导尺度，控制生成内容与提示词的贴合程度。
   */
  guidance: number;
  /**
   * 随机数种子。
   */
  seed: number;
}

/**
 * 图片生成任务启动时发布的事件载荷。
 */
export interface ImageGenerationStartedPayload {
  /**
   * 关联的生成任务。
   */
  task: ImageGenerationTask;
}

/**
 * 图片生成进度更新时发布的事件载荷。
 */
export interface ImageGenerationProgressPayload {
  /**
   * 关联的生成任务，内含当前进度值。
   */
  task: ImageGenerationTask;
}

/**
 * 图片生成完成时发布的事件载荷。
 */
export interface ImageGenerationCompletedPayload {
  /**
   * 关联的生成任务，包含最终生成的附件标识和元数据。
   */
  task: ImageGenerationTask;
}

/**
 * 图片生成失败时发布的事件载荷。
 */
export interface ImageGenerationFailedPayload {
  /**
   * 关联的生成任务，包含失败原因。
   */
  task: ImageGenerationTask;
}

/**
 * 图片生成取消时发布的事件载荷。
 */
export interface ImageGenerationCancelledPayload {
  /**
   * 关联的生成任务。
   */
  task: ImageGenerationTask;
}

/**
 * 预设保存时发布的事件载荷。
 */
export interface ImageGenerationPresetSavedPayload {
  /**
   * 保存后的预设对象。
   */
  preset: ImageGenerationPreset;
}

/**
 * 图片生成模块导入导出时交换的数据结构，包含所有预设和任务记录。
 */
export interface ImageGenerationExportData {
  /**
   * 所有预设记录。
   */
  presets: Array<ImageGenerationPreset>;
  /**
   * 所有任务记录。
   */
  tasks: Array<ImageGenerationTask>;
}
