import type {
  ChatMessageRole,
  VisionContentPartType,
} from '../contracts/PublicContracts';

/**
 * 图片描述（Image Caption）模块的数据模型定义。
 *
 * 本文件定义了 caption 任务的全生命周期中使用的数据结构，包括参数、
 * 任务记录、结果、事件负载以及外部请求体的类型。
 */

/**
 * 图片描述能力的提供方类型，决定使用何种后端生成描述。
 */
export type CaptionProvider = 'openai_vision' | 'local' | 'custom';
/**
 * 图片描述任务的阶段性状态枚举。
 */
export type CaptionTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

/**
 * 发起图片描述操作所需传入的参数。
 */
export interface CaptionParams {
  /**
   * 被描述图片的附件唯一标识。
   */
  imageAttachmentId: string;
  /**
   * 图片描述能力的提供方类型。
   */
  provider: CaptionProvider;
  /**
   * 向视觉模型发送的描述引导文本。
   */
  prompt: string;
  /**
   * 用于图片描述推理的模型名称。
   */
  model: string;
  /**
   * 是否在消息发送时自动触发描述流程。
   */
  autoCaption: boolean;
}

/**
 * 图片描述任务的运行记录，贯穿任务从创建到结束的完整生命周期。
 */
export interface CaptionTask {
  /**
   * 任务的唯一标识。
   */
  taskId: string;
  /**
   * 发起任务时使用的参数快照。
   */
  params: CaptionParams;
  /**
   * 任务的当前执行状态。
   */
  status: CaptionTaskStatus;
  /**
   * 任务进度百分比，取值范围 0-100。
   */
  progress: number;
  /**
   * 描述完成后生成的文本内容。
   */
  resultText: string;
  /**
   * 描述结果的附件标识（若有）。
   */
  resultAttachmentId: string;
  /**
   * 任务失败时的错误信息。
   */
  error: string;
  /**
   * 任务创建时间戳。
   */
  createdAt: number;
  /**
   * 任务最近一次更新时间戳。
   */
  updatedAt: number;
}

/**
 * 图片描述操作完成后返回给调用方的结果摘要。
 */
export interface CaptionResult {
  /**
   * 对应任务的唯一标识。
   */
  taskId: string;
  /**
   * 描述生成的文本。
   */
  text: string;
  /**
   * 描述结果的附件唯一标识。
   */
  attachmentId: string;
}

/**
 * 指向一张用于视觉推理的图片地址。
 */
export interface VisionImageUrl {
  /**
   * 图片的可访问 URL。
   */
  url: string;
}
/**
 * 视觉消息中的一条内容片段，可以是文本或图片。
 */
export interface VisionContentPart {
  /**
   * 片段类型。
   */
  type: VisionContentPartType;
  /**
   * 文本内容（当类型为 text 时有效）。
   */
  text: string;
  /**
   * 图片地址（当类型为 image_url 时有效）。
   */
  image_url: VisionImageUrl;
}
/**
 * 发送给视觉模型的一条消息，包含角色和内容片段列表。
 */
export interface VisionMessage {
  /**
   * 消息发送角色。
   */
  role: ChatMessageRole;
  /**
   * 消息内容，每条内容可以是图片或文本片段。
   */
  content: Array<VisionContentPart>;
}
/**
 * 发送给外部视觉服务的完整请求数据结构。
 */
export interface VisionRequest {
  /**
   * 用于推理的模型名称。
   */
  model: string;
  /**
   * 对话消息列表。
   */
  messages: Array<VisionMessage>;
}

/**
 * Caption 任务启动事件携带的负载数据。
 */
export interface CaptionStartedPayload {
  /**
   * 已启动的任务记录。
   */
  task: CaptionTask;
}
/**
 * Caption 任务进度更新事件携带的负载数据。
 */
export interface CaptionProgressPayload {
  /**
   * 当前进度的任务记录。
   */
  task: CaptionTask;
}
/**
 * Caption 任务完成事件携带的负载数据。
 */
export interface CaptionCompletedPayload {
  /**
   * 已完成的任务记录。
   */
  task: CaptionTask;
}
/**
 * Caption 任务失败事件携带的负载数据。
 */
export interface CaptionFailedPayload {
  /**
   * 失败的任务记录。
   */
  task: CaptionTask;
}
/**
 * Caption 任务取消事件携带的负载数据。
 */
export interface CaptionCancelledPayload {
  /**
   * 已取消的任务记录。
   */
  task: CaptionTask;
}
/**
 * 用于数据导出 / 导入的 Caption 任务集合。
 */
export interface CaptionExportData {
  /**
   * 全部任务记录列表。
   */
  tasks: Array<CaptionTask>;
}
