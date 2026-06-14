/**
 * 语音转文字（ASR）模块。
 * 导出 ASRRuntime 类及所有相关类型，提供语音识别任务的全生命周期管理（启动、进度更新、完成、失败、取消）、
 * 事件发布通知外部模块、Whisper API 请求体构建以及任务的导入导出能力，
 * 适用于语音输入场景（如语音消息输入、音频文件转录）中驱动语音识别服务和处理结果。
 */
export { ASRRuntime } from './ASRRuntime';
export type {
  ASRExportData,
  ASRProvider,
  ASRTask,
  ASRTaskStatus,
  ASRTranscriptionCancelledPayload,
  ASRTranscriptionCompletedPayload,
  ASRTranscriptionFailedPayload,
  ASRTranscriptionParams,
  ASRTranscriptionProgressPayload,
  ASRTranscriptionResult,
  ASRTranscriptionStartedPayload,
  WhisperRequest,
} from './ASRModels';
