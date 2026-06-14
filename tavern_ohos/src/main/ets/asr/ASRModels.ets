/**
 * ASR 提供商类型，决定了音频转文字请求的发送目标：
 * - openai_whisper：通过 OpenAI 兼容接口调用远程 Whisper 模型
 * - local_whisper：调用设备端本地 Whisper 模型（需宿端支持）
 * - system：调用操作系统级语音识别能力
 */
export type ASRProvider = 'openai_whisper' | 'local_whisper' | 'system';

/**
 * ASR 任务生命周期状态：
 * - pending：初始排队，等待开始执行
 * - running：转录正在进行中
 * - completed：转录成功完成
 * - failed：转录因错误终止
 * - cancelled：转录被用户主动取消
 */
export type ASRTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

/**
 * 发起一次 ASR 转录请求所需的完整参数集合。
 * 该对象通常在 UI 配置页面中组装完成，然后下发至运行时执行。
 */
export interface ASRTranscriptionParams {
  /**
   * 音频来源标识，用于区分不同会话场景（如当前聊天、历史消息等），由运行时自动注入。
   */
  source: string;
  /**
   * ASR 提供商选择，决定转录请求的发送路径，与运行时配置联动。
   */
  provider: ASRProvider;
  /**
   * 音频语言代码（如 zh、en），用于提示模型提高识别准确率。
   */
  language: string;
  /**
   * 模型名称，传递给 ASR 服务端以选择具体模型版本。
   */
  model: string;
  /**
   * 转录完成后是否自动发送转写文本到当前会话输入框，由用户在配置页面设定。
   */
  autoSend: boolean;
  /**
   * 提示词（prompt），用于向 Whisper 模型提供上下文以改善同音词等场景的准确率。
   */
  prompt: string;
}

/**
 * 表示一条 ASR 转录任务的完整执行记录。
 * 由 ASRRuntime 在每次调用 startTranscription 时创建，
 * 并在转录过程中逐步更新状态与进度字段。
 */
export interface ASRTask {
  /**
   * 全局唯一任务标识，格式为 "asr-{自增序号}"，由运行时在创建时分配。
   */
  taskId: string;
  /**
   * 发起本次转录任务时使用的参数快照。
   */
  params: ASRTranscriptionParams;
  /**
   * 任务当前状态，反映转录在生命周期中的位置。
   */
  status: ASRTaskStatus;
  /**
   * 转录进度百分比（0-100），由运行时在 updateProgress 中刷新。
   */
  progress: number;
  /**
   * 已完成的转写文本内容，completeTranscription 时写入最终结果。
   */
  transcript: string;
  /**
   * 置信度（0-1），仅 completed 状态时有意义，由 ASR 服务端返回。
   */
  confidence: number;
  /**
   * 音频时长（单位：秒），仅 completed 状态时有意义。
   */
  duration: number;
  /**
   * 错误描述信息，仅 failed 或 cancelled 状态时非空。
   */
  error: string;
  /**
   * 任务创建时的时间戳（毫秒），在 startTranscription 中写入。
   */
  createdAt: number;
  /**
   * 任务最近一次状态变更的时间戳（毫秒），随每次更新刷新。
   */
  updatedAt: number;
}

/**
 * ASR 转录完成后的结果数据，由 completeTranscription 接收并写入 ASRTask。
 * 供上层 UI 或后续流程（如自动发送）消费。
 */
export interface ASRTranscriptionResult {
  /**
   * 对应源任务的唯一标识。
   */
  taskId: string;
  /**
   * ASR 服务端返回的完整转写文本。
   */
  transcript: string;
  /**
   * 置信度（0-1），值越高识别越可靠。
   */
  confidence: number;
  /**
   * 音频时长（单位：秒）。
   */
  duration: number;
  /**
   * 音频语言代码（如 zh、en），由服务端自动检测或按请求参数返回。
   */
  language: string;
}

/**
 * 发送至 Whisper API 的 HTTP 请求体数据结构。
 * 遵循 OpenAI Whisper 的 multipart/form-data 规范。
 */
export interface WhisperRequest {
  /**
   * 待识别的音频文件路径（本地路径或临时文件标识）。
   */
  file: string;
  /**
   * Whisper 模型名称（如 whisper-1）。
   */
  model: string;
  /**
   * 音频语言代码（可选），用于提升识别准确率。
   */
  language: string;
  /**
   * 提示词（可选），用于辅助模型在特定上下文下更准确地转录。
   */
  prompt: string;
  /**
   * 响应格式，固定为 'text' 以直接获取转写文本而非 JSON 包体。
   */
  response_format: string;
}

/**
 * ASR 转录任务开始时发布的事件载荷。
 * 由 ASRRuntime.startTranscription 发布至事件总线，供监听方（如 UI 进度显示）消费。
 */
export interface ASRTranscriptionStartedPayload {
  /**
   * 已创建的转录任务对象（副本），包含初始状态值。
   */
  task: ASRTask;
}
/**
 * ASR 转录进度更新时发布的事件载荷。
 * 由 ASRRuntime.updateProgress 在每次进度变化时发布。
 */
export interface ASRTranscriptionProgressPayload {
  /**
   * 包含最新进度值的任务对象（副本）。
   */
  task: ASRTask;
}
/**
 * ASR 转录成功完成时发布的事件载荷。
 * 由 ASRRuntime.completeTranscription 发布，通知 UI 显示最终转写文本。
 */
export interface ASRTranscriptionCompletedPayload {
  /**
   * 包含最终 transcript 和置信度的任务对象（副本）。
   */
  task: ASRTask;
}
/**
 * ASR 转录失败时发布的事件载荷。
 * 由 ASRRuntime.failTranscription 发布，通知 UI 显示错误状态。
 */
export interface ASRTranscriptionFailedPayload {
  /**
   * 包含错误信息的任务对象（副本）。
   */
  task: ASRTask;
}
/**
 * ASR 转录被用户主动取消时发布的事件载荷。
 * 由 ASRRuntime.cancelTranscription 发布，通知 UI 同步取消状态。
 */
export interface ASRTranscriptionCancelledPayload {
  /**
   * 已标记为取消状态的任务对象（副本）。
   */
  task: ASRTask;
}
/**
 * ASR 模块的持久化数据结构，用于跨会话导入导出转录记录。
 * 包含全部已完成和未完成的 ASR 任务列表。
 */
export interface ASRExportData {
  /**
   * 当前存在的所有 ASR 转录任务记录。
   */
  tasks: Array<ASRTask>;
}
