// Caption 提供商，用于指定图片描述功能连接的后端服务类型
export type CaptionProvider = 'openai_vision' | 'local' | 'custom';
// Caption 任务状态，描述图片描述任务从创建到完成的完整生命周期阶段
export type CaptionTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

/**
 * 描述调用图片描述能力时需要传入的参数。
 * 用于启动图片描述任务时的输入，由 UI 层或自动触发流程传入 ImageCaptionRuntime.startCaption()。
 */
export interface CaptionParams {
  /**
   * 要描述的目标图片的附件标识，用于在附件系统中定位图片文件并构造视觉请求。
   */
  imageAttachmentId: string;
  /**
   * 图片描述服务提供商，如 openai_vision、local、custom，决定调用哪个后端 API 发出视觉描述请求。
   */
  provider: CaptionProvider;
  /**
   * 描述提示词，用于引导图片描述生成方向，例如"详细描述这张图片的内容"。
   */
  prompt: string;
  /**
   * 使用的模型名称，传递给视觉 API（如 gpt-4-vision-preview）指定具体模型版本。
   */
  model: string;
  /**
   * 是否在上传图片后自动触发描述任务，用于支持"上传即描述"的无缝工作流。
   */
  autoCaption: boolean;
}

/**
 * 描述图片描述模块在运行时交换的数据结构。
 * 用于追踪单次描述任务的完整状态流转，通过事件在各个阶段发布给 UI 层和外部订阅者。
 */
export interface CaptionTask {
  /**
   * 描述任务唯一标识，格式为 caption-{自增序号}，用于在内存索引中查找、更新任务状态。
   */
  taskId: string;
  /**
   * 任务创建时传入的描述参数，包含目标图片、提供商、提示词等原始输入。
   */
  params: CaptionParams;
  /**
   * 任务当前状态：pending（已创建等待）、running（执行中）、completed（完成）、failed（失败）、cancelled（取消）。
   */
  status: CaptionTaskStatus;
  /**
   * 任务进度百分比（0-100），用于 UI 层显示进度条或加载指示器。
   */
  progress: number;
  /**
   * 描述任务生成的文本内容，由视觉 API 返回的图片描述结果。
   */
  resultText: string;
  /**
   * 描述结果关联的附件标识，用于将生成的描述文本作为附件持久化存储。
   */
  resultAttachmentId: string;
  /**
   * 任务失败时的错误描述信息，用于 UI 层展示失败原因。
   */
  error: string;
  /**
   * 任务创建时间戳（毫秒），用于排序和日志记录。
   */
  createdAt: number;
  /**
   * 任务最后更新时间戳（毫秒），用于追踪任务进度变化的时效性。
   */
  updatedAt: number;
}

/**
 * 描述图片描述操作完成后返回给调用方的结果。
 * 用于 ImageCaptionRuntime.completeCaption() 更新任务状态时作为结果输入。
 */
export interface CaptionResult {
  /**
   * 描述任务唯一标识，用于关联对应的 CaptionTask 记录。
   */
  taskId: string;
  /**
   * 生成的图片描述文本，由视觉 API 响应解析后填入。
   */
  text: string;
  /**
   * 描述结果持久化后的附件标识，用于将描述内容作为附件绑定到目标对象。
   */
  attachmentId: string;
}

/**
 * 构建视觉请求时用于表示图片 URL 的数据结构。
 * 用于构造向视觉 API 发送的多模态消息中的图片引用部分。
 */
export interface VisionImageUrl {
  /**
   * 图片的远程 URL 地址，用于视觉 API 的 image_url 消息块中定位待分析的图片资源。
   */
  url: string;
}
/**
 * 构建视觉请求时多模态消息中的内容片段，支持文本和图片 URL。
 * 用于构造向视觉 API 发送的 content 数组中的单个元素，一个消息可包含多个 content part。
 */
export interface VisionContentPart {
  /**
   * 内容类型：text 或 image_url，决定该 fragment 是文本提示词还是图片引用。
   */
  type: string;
  /**
   * 文本类型片段的文本内容，当 type 为 'text' 时使用，包含描述提示词。
   */
  text: string;
  /**
   * 图片类型片段中的图片 URL 信息，当 type 为 'image_url' 时使用。
   */
  image_url: VisionImageUrl;
}
/**
 * 构建视觉请求时的一条多模态消息，包含角色标识和内容片段列表。
 * 用于构造向视觉 API 发送的消息数组，目前仅包含单条 user 消息。
 */
export interface VisionMessage {
  /**
   * 消息角色，如 user、system，用于标识消息发送方角色。
   */
  role: string;
  /**
   * 多模态内容片段数组，可包含文本和图片 URL，用于向视觉 API 传递提示词和图片引用。
   */
  content: Array<VisionContentPart>;
}

/**
 * 描述发送给视觉 API 的完整请求数据结构。
 * 由 ImageCaptionRuntime.buildVisionRequest() 构建，用于调用外部视觉识别 API。
 */
export interface VisionRequest {
  /**
   * 要使用的视觉模型名称，如 gpt-4-vision-preview。
   */
  model: string;
  /**
   * 对话消息列表，包含携带图片和提示词的 user 消息。
   */
  messages: Array<VisionMessage>;
}

// 事件 payload
export interface CaptionStartedPayload {
  /**
   * 启动时的描述任务对象，用于发布 'caption.started' 事件，通知 UI 层显示任务已创建。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述进度更新事件发布时携带的数据结构。
 * 用于 ImageCaptionRuntime.updateProgress() 发布 'caption.progress' 事件，驱动 UI 层更新进度条。
 */
export interface CaptionProgressPayload {
  /**
   * 更新进度后的描述任务对象，包含当前进度百分比和 running 状态。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述完成事件发布时携带的数据结构。
 * 用于 ImageCaptionRuntime.completeCaption() 发布 'caption.completed' 事件，通知 UI 层显示描述结果。
 */
export interface CaptionCompletedPayload {
  /**
   * 完成后的描述任务对象，包含生成的描述文本和关联附件 ID。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述失败事件发布时携带的数据结构。
 * 用于 ImageCaptionRuntime.failCaption() 发布 'caption.failed' 事件，通知 UI 层显示错误信息。
 */
export interface CaptionFailedPayload {
  /**
   * 失败后的描述任务对象，包含错误描述信息。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述取消事件发布时携带的数据结构。
 * 用于 ImageCaptionRuntime.cancelCaption() 发布 'caption.cancelled' 事件，通知 UI 层任务已取消。
 */
export interface CaptionCancelledPayload {
  /**
   * 取消后的描述任务对象，状态为 cancelled。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述模块导出/备份的整体数据结构。
 * 用于 ImageCaptionRuntime.exportData() 和 importData()，在备份恢复流程中传输全部任务数据。
 */
export interface CaptionExportData {
  /**
   * 所有描述任务记录，用于导出到 JSON 文件保存或在导入时恢复运行时状态。
   */
  tasks: Array<CaptionTask>;
}
