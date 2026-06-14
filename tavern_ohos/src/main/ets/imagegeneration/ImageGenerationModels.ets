// 图片生成后端类型，用于指定图片生成功能连接的服务端引擎
export type ImageGenerationBackend = 'sd_webui' | 'comfyui' | 'openai_image' | 'workers_ai';

// 图片生成任务状态，描述生成任务从创建到完成的完整生命周期阶段
export type ImageGenerationStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// 图片生成参数，用于启动图片生成任务时的输入配置
export interface ImageGenerationParams {
  /**
   * 图片生成后端类型：sd_webui、comfyui、openai_image、workers_ai，决定调用哪个后端 API 构建请求和执行生成。
   */
  backend: ImageGenerationBackend;
  /**
   * 正向提示词，描述期望生成的图像内容，作为生成引擎的主要引导输入。
   */
  prompt: string;
  /**
   * 反向提示词，描述不希望出现在图像中的内容，用于引导生成引擎避免特定元素。
   */
  negativePrompt: string;
  /**
   * 生成图像的宽度（像素），用于所有后端 API 请求的尺寸参数。
   */
  width: number;
  /**
   * 生成图像的高度（像素），用于所有后端 API 请求的尺寸参数。
   */
  height: number;
  /**
   * 采样步数，步数越高细节越丰富，传递给后端引擎控制生成质量和耗时。
   */
  steps: number;
  /**
   * CFG 引导强度，控制提示词对生成结果的贴合程度，值越高越遵循提示词。
   */
  cfg: number;
  /**
   * 随机种子，固定种子可复现相同结果，-1 表示使用随机种子。
   */
  seed: number;
  /**
   * 采样器名称，如 Euler、DPM++ 2M Karras，用于 SD WebUI 等支持多种采样器的引擎。
   */
  sampler: string;
  /**
   * 单次生成图片数量，用于批量生成场景（如 SD WebUI 的 batch_size）。
   */
  batchSize: number;
}

// 图片生成结果元数据
export interface ImageGenerationMetadata {
  /**
   * 生成图片所使用的模型名称，由后端 API 响应中解析而来，用于结果回溯和展示。
   */
  model?: string;
  /**
   * 实际使用的种子值（字符串形式），用于复现生成结果，可能不同于传入的种子（如使用随机种子时）。
   */
  seed?: string;
  /**
   * 后端返回的任务唯一标识，用于追踪后端生成任务状态和日志。
   */
  backendTaskId?: string;
  /**
   * 请求的唯一标识，用于在日志或监控系统中关联前后端请求。
   */
  requestId?: string;
}

// 图片生成任务
export interface ImageGenerationTask {
  /**
   * 生成任务唯一标识，格式为 img-gen-{自增序号}，用于在内存索引中查找、更新和追踪任务状态。
   */
  taskId: string;
  /**
   * 生成图片所使用的后端类型，记录在任务中以便后续处理结果时区分不同后端的响应格式。
   */
  backend: ImageGenerationBackend;
  /**
   * 任务创建时传入的生成参数，包含提示词、尺寸、采样参数等原始输入。
   */
  params: ImageGenerationParams;
  /**
   * 任务当前状态：pending、running、completed、failed、cancelled，驱动 UI 层展示不同状态的界面。
   */
  status: ImageGenerationStatus;
  /**
   * 任务进度百分比（0-100），用于 UI 层显示生成进度条。
   */
  progress: number;
  /**
   * 生成结果图片的附件 ID 列表，用于在图片附件系统中定位生成的图片文件。
   */
  resultAttachmentIds: Array<string>;
  /**
   * 任务失败时的错误描述信息，用于 UI 层展示失败原因。
   */
  error: string;
  /**
   * 生成结果的元数据，包括模型、种子等信息，用于结果展示和复现。
   */
  metadata: ImageGenerationMetadata;
  /**
   * 任务创建时间戳（毫秒），用于排序和任务历史记录。
   */
  createdAt: number;
  /**
   * 任务最后更新时间戳（毫秒），用于追踪任务状态变化的时效性。
   */
  updatedAt: number;
}

// 图片生成预设
export interface ImageGenerationPreset {
  /**
   * 预设唯一标识，格式为 img-preset-{自增序号}，用于在内存索引中查找、更新和管理预设。
   */
  presetId: string;
  /**
   * 预设名称，用于 UI 层面板中显示和用户选择。
   */
  name: string;
  /**
   * 预设中保存的生成参数，包含完整的提示词、尺寸、采样参数等，用于一键恢复生成配置。
   */
  params: ImageGenerationParams;
  /**
   * 预设创建时间戳（毫秒），用于排序记录。
   */
  createdAt: number;
  /**
   * 预设最后更新时间戳（毫秒），用于追踪预设是否被修改过。
   */
  updatedAt: number;
}

// SD WebUI 请求体，用于向 Stable Diffusion WebUI API 发送图片生成请求
export interface SdWebUIRequest {
  /**
   * 正向提示词，映射到 SD WebUI API 的 prompt 字段。
   */
  prompt: string;
  /**
   * 反向提示词，映射到 SD WebUI API 的 negative_prompt 字段。
   */
  negative_prompt: string;
  /**
   * 图像宽度（像素），映射到 SD WebUI API 的 width 字段。
   */
  width: number;
  /**
   * 图像高度（像素），映射到 SD WebUI API 的 height 字段。
   */
  height: number;
  /**
   * 采样步数，映射到 SD WebUI API 的 steps 字段。
   */
  steps: number;
  /**
   * CFG 引导强度，映射到 SD WebUI API 的 cfg_scale 字段。
   */
  cfg_scale: number;
  /**
   * 随机种子，映射到 SD WebUI API 的 seed 字段。
   */
  seed: number;
  /**
   * 采样器名称，映射到 SD WebUI API 的 sampler_name 字段。
   */
  sampler_name: string;
  /**
   * 批量生成数量，映射到 SD WebUI API 的 batch_size 字段。
   */
  batch_size: number;
}

// ComfyUI 请求体，用于向 ComfyUI API 发送图片生成请求
export interface ComfyUIRequest {
  /**
   * ComfyUI 工作流 JSON 对象，用于定义图片生成的节点图和参数配置。
   */
  workflow: Object;
  /**
   * ComfyUI 客户端标识，用于服务端追踪和管理 WebSocket 连接。
   */
  client_id: string;
}

// OpenAI 图片请求体，用于向 OpenAI Image API (DALL-E) 发送图片生成请求
export interface OpenAIImageRequest {
  /**
   * 模型名称，如 dall-e-3，用于 OpenAI Image API 的 model 字段。
   */
  model: string;
  /**
   * 正向提示词，用于 OpenAI Image API 的 prompt 字段。
   */
  prompt: string;
  /**
   * 生成图片数量，用于 OpenAI Image API 的 n 字段。
   */
  n: number;
  /**
   * 生成图片尺寸，如 1024x1024，用于 OpenAI Image API 的 size 字段。
   */
  size: string;
  /**
   * 响应格式，固定为 b64_json（Base64 编码），以便在客户端解析图片数据。
   */
  response_format: string;
}

// Workers AI 请求体，用于向 Cloudflare Workers AI API 发送图片生成请求
export interface WorkersAIRequest {
  /**
   * 正向提示词，用于 Workers AI API 的 prompt 字段。
   */
  prompt: string;
  /**
   * 反向提示词，用于 Workers AI API 的 negative_prompt 字段。
   */
  negative_prompt: string;
  /**
   * 图像宽度（像素），用于 Workers AI API 的 width 字段。
   */
  width: number;
  /**
   * 图像高度（像素），用于 Workers AI API 的 height 字段。
   */
  height: number;
  /**
   * 采样步数，用于 Workers AI API 的 num_steps 字段。
   */
  num_steps: number;
  /**
   * 引导强度，用于 Workers AI API 的 guidance 字段。
   */
  guidance: number;
  /**
   * 随机种子，用于 Workers AI API 的 seed 字段。
   */
  seed: number;
}

// 事件 payload
export interface ImageGenerationStartedPayload {
  /**
   * 启动时的生成任务对象，用于发布 'image.generation.started' 事件，通知 UI 层显示任务已创建。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成进度更新事件发布时携带的数据结构。
 * 用于 ImageGenerationRuntime.updateProgress() 发布 'image.generation.progress' 事件，驱动 UI 层更新进度显示。
 */
export interface ImageGenerationProgressPayload {
  /**
   * 更新进度后的生成任务对象，包含当前进度百分比和 running 状态。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成完成事件发布时携带的数据结构。
 * 用于 ImageGenerationRuntime.completeGeneration() 发布 'image.generation.completed' 事件，通知 UI 层显示生成结果。
 */
export interface ImageGenerationCompletedPayload {
  /**
   * 完成后的生成任务对象，包含结果附件 ID 列表和元数据。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成失败事件发布时携带的数据结构。
 * 用于 ImageGenerationRuntime.failGeneration() 发布 'image.generation.failed' 事件，通知 UI 层显示错误信息。
 */
export interface ImageGenerationFailedPayload {
  /**
   * 失败后的生成任务对象，包含错误描述信息。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成取消事件发布时携带的数据结构。
 * 用于 ImageGenerationRuntime.cancelGeneration() 发布 'image.generation.cancelled' 事件，通知 UI 层任务已取消。
 */
export interface ImageGenerationCancelledPayload {
  /**
   * 取消后的生成任务对象，状态为 cancelled。
   */
  task: ImageGenerationTask;
}

/**
 * 描述图片生成预设保存事件发布时携带的数据结构。
 * 用于 ImageGenerationRuntime.savePreset() 发布 'image.generation.preset.saved' 事件，通知 UI 层预设列表已更新。
 */
export interface ImageGenerationPresetSavedPayload {
  /**
   * 保存后的预设对象，包含预设名称、参数和时间戳。
   */
  preset: ImageGenerationPreset;
}

/**
 * 描述图片生成模块导出/备份的整体数据结构。
 * 用于 ImageGenerationRuntime.exportData() 和 importData()，在备份恢复流程中传输预设和任务数据。
 */
export interface ImageGenerationExportData {
  /**
   * 所有生成预设记录，用于导出保存或在导入时恢复运行时预设列表。
   */
  presets: Array<ImageGenerationPreset>;
  /**
   * 所有生成任务记录，用于导出保存或在导入时恢复运行时任务列表。
   */
  tasks: Array<ImageGenerationTask>;
}
