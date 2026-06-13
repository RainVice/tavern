// Caption 提供商
export type CaptionProvider = 'openai_vision' | 'local' | 'custom';
// Caption 任务状态
export type CaptionTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

/**
 * 描述调用图片描述能力时需要传入的参数。
 */
export interface CaptionParams {
  /**
   * image Attachment 标识。
   */
  imageAttachmentId: string;
  /**
   * provider 值，由当前实例内部维护。
   */
  provider: CaptionProvider;
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * auto Caption 值，由当前实例内部维护。
   */
  autoCaption: boolean;
}

/**
 * 描述图片描述模块在运行时交换的数据结构。
 */
export interface CaptionTask {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * 调用参数。
   */
  params: CaptionParams;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: CaptionTaskStatus;
  /**
   * progress 列表，由当前实例内部维护。
   */
  progress: number;
  /**
   * result Text 值，由当前实例内部维护。
   */
  resultText: string;
  /**
   * result Attachment 标识。
   */
  resultAttachmentId: string;
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

/**
 * 描述图片描述操作完成后返回给调用方的结果。
 */
export interface CaptionResult {
  /**
   * 任务标识。
   */
  taskId: string;
  /**
   * 文本内容。
   */
  text: string;
  /**
   * attachment 标识。
   */
  attachmentId: string;
}

/**
 * 描述图片描述模块在运行时交换的数据结构。
 */
export interface VisionImageUrl {
  /**
   * 地址。
   */
  url: string;
}
/**
 * 描述图片描述模块在运行时交换的数据结构。
 */
export interface VisionContentPart {
  /**
   * 类型。
   */
  type: string;
  /**
   * 文本内容。
   */
  text: string;
  /**
   * image url 值，由当前实例内部维护。
   */
  image_url: VisionImageUrl;
}
/**
 * 描述图片描述模块在运行时交换的数据结构。
 */
export interface VisionMessage {
  /**
   * 角色。
   */
  role: string;
  /**
   * 内容。
   */
  content: Array<VisionContentPart>;
}
/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface VisionRequest {
  /**
   * 模型记录。
   */
  model: string;
  /**
   * 消息列表。
   */
  messages: Array<VisionMessage>;
}

// 事件 payload
export interface CaptionStartedPayload {
  /**
   * 任务数据。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述事件发布时携带的数据结构。
 */
export interface CaptionProgressPayload {
  /**
   * 任务数据。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述事件发布时携带的数据结构。
 */
export interface CaptionCompletedPayload {
  /**
   * 任务数据。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述事件发布时携带的数据结构。
 */
export interface CaptionFailedPayload {
  /**
   * 任务数据。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述事件发布时携带的数据结构。
 */
export interface CaptionCancelledPayload {
  /**
   * 任务数据。
   */
  task: CaptionTask;
}
/**
 * 描述图片描述模块在运行时交换的数据结构。
 */
export interface CaptionExportData {
  /**
   * 任务列表。
   */
  tasks: Array<CaptionTask>;
}
