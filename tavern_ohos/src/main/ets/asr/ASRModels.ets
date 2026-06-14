// ASR 提供商
export type ASRProvider = 'openai_whisper' | 'local_whisper' | 'system';

// ASR 任务状态
export type ASRTaskStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// ASR 转录参数
export interface ASRTranscriptionParams {
  /**
   * 音频来源类型（如 microphone、file_upload），用于在启动转录流程时决定音频数据的获取方式和权限处理策略。
   */
  source: string;
  /**
   * 语音识别服务提供商，用于在转录流程中选择对应的后端服务适配器（如 OpenAI、本地引擎等）。
   */
  provider: ASRProvider;
  /**
   * 目标音频语言代码（如 zh、en），用于在转录流程中辅助语音识别引擎优化准确度。
   */
  language: string;
  /**
   * ASR 模型名称，用于在转录流程中选择具体的语音识别模型版本。
   */
  model: string;
  /**
   * 转录完成后是否自动发送识别结果，用于在转录完成流程中决定是否将结果直接推送到对话上下文。
   */
  autoSend: boolean;
  /**
   * 传递给 ASR 服务的提示词，用于在转录流程中优化识别准确度，帮助模型理解上下文主题。
   */
  prompt: string;
}

// ASR 转录任务
export interface ASRTask {
  /**
   * 任务唯一标识，用于在转录流程的全生命周期中追踪和管理单个任务的进度与状态。
   */
  taskId: string;
  /**
   * 转录任务的调用参数，包含音频来源、提供商、语言等配置，在启动转录时记录供后续流程使用。
   */
  params: ASRTranscriptionParams;
  /**
   * 任务当前状态，用于在转录流程中追踪任务是否在排队、运行中、已完成或出错。
   */
  status: ASRTaskStatus;
  /**
   * 转录进度百分比（0-100），用于在进度更新流程中向 UI 或调用方反馈当前处理进度。
   */
  progress: number;
  /**
   * 转录后的文本结果，在转录完成流程中由识别引擎填充，供后续发送或存储使用。
   */
  transcript: string;
  /**
   * 识别的置信度（0-1），用于在转录完成流程中评估结果可信度，辅助决定是否自动发送。
   */
  confidence: number;
  /**
   * 音频时长（秒），用于在转录完成后统计音频长度，辅助计算费用或处理时间。
   */
  duration: number;
  /**
   * 任务失败时的错误信息，在转录失败流程中记录失败原因供诊断使用。
   */
  error: string;
  /**
   * 任务创建时间戳（毫秒），用于在任务生命周期中记录起始时刻，辅助超时判断和时间统计。
   */
  createdAt: number;
  /**
   * 任务最近更新时间戳（毫秒），用于追踪任务状态变更时机，辅助进度监控和调试。
   */
  updatedAt: number;
}

// 转录结果
export interface ASRTranscriptionResult {
  /**
   * 任务唯一标识，用于在转录完成流程中将结果关联到原始任务记录。
   */
  taskId: string;
  /**
   * 转录后的文本结果，在转录完成流程中由识别引擎返回，供后续发送或存储使用。
   */
  transcript: string;
  /**
   * 识别的置信度（0-1），用于在转录完成流程中评估结果可靠性。
   */
  confidence: number;
  /**
   * 音频时长（秒），用于在转录完成后统计音频长度。
   */
  duration: number;
  /**
   * 识别出的音频语言，用于在转录完成流程中记录自动检测到的语言信息。
   */
  language: string;
}

// OpenAI Whisper 请求体
export interface WhisperRequest {
  /**
   * 要转录的音频文件路径或数据，用于在构建 Whisper API 请求时指定音频来源。
   */
  file: string;
  /**
   * Whisper 模型名称（如 whisper-1），用于在请求 Whisper API 时指定使用的模型版本。
   */
  model: string;
  /**
   * 音频语言（可空，让模型自动检测），用于在请求 Whisper API 时辅助语言识别。
   */
  language: string;
  /**
   * 辅助提示词，用于在请求 Whisper API 时优化转录准确度，帮助模型理解上下文。
   */
  prompt: string;
  /**
   * Whisper 响应格式（如 text、json、verbose_json），用于指定 API 返回的数据结构格式。
   */
  response_format: string;
}

// 事件 payload
export interface ASRTranscriptionStartedPayload {
  /**
   * 任务数据，包含任务标识、参数和初始状态，在转录启动事件中传递供监听方（如 UI、日志）获取启动详情。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字进度事件发布时携带的数据结构，在转录进度更新流程中由运行时发布，供 UI 或日志模块监听进度变化。
 */
export interface ASRTranscriptionProgressPayload {
  /**
   * 任务数据，包含当前进度和状态，在进度更新事件中传递供监听方展示或记录。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字完成事件发布时携带的数据结构，在转录完成流程中由运行时发布，供 UI 或下游模块获取最终结果。
 */
export interface ASRTranscriptionCompletedPayload {
  /**
   * 任务数据，包含转录结果文本、置信度和音频时长，在完成事件中传递供监听方处理。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字失败事件发布时携带的数据结构，在转录失败流程中由运行时发布，供 UI 或日志模块展示错误信息。
 */
export interface ASRTranscriptionFailedPayload {
  /**
   * 任务数据，包含错误描述，在失败事件中传递供监听方记录或提示用户。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字取消事件发布时携带的数据结构，在转录取消流程中由运行时发布，供 UI 或下游模块响应取消操作。
 */
export interface ASRTranscriptionCancelledPayload {
  /**
   * 任务数据，包含取消标记，在取消事件中传递供监听方清理相关状态。
   */
  task: ASRTask;
}
/**
 * 描述语音转文字模块的导出数据结构，用于在数据备份或与 SillyTavern 数据互通时序列化 ASR 任务列表。
 */
export interface ASRExportData {
  /**
   * 导出的所有 ASR 转录任务列表，在数据导出流程中汇总所有任务记录供外部存储或迁移。
   */
  tasks: Array<ASRTask>;
}
