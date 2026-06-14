/**
 * tts 模块导出核心能力和类型。
 *
 * 提供文字转语音运行时管理（TTSRuntime）以及相关模型类型，
 * 包括语音配置、合成参数、任务状态和事件载荷。
 */
export { TTSRuntime } from './TTSRuntime';
export type {
  EdgeTTSRequest,
  OpenAITTSRequest,
  TTSAudioResult,
  TTSExportData,
  TTSProvider,
  TTSSynthesisCancelledPayload,
  TTSSynthesisCompletedPayload,
  TTSSynthesisFailedPayload,
  TTSSynthesisParams,
  TTSSynthesisProgressPayload,
  TTSSynthesisStartedPayload,
  TTSTask,
  TTSTaskStatus,
  TTSVoiceProfile,
  TTSVoiceProfileSavedPayload,
} from './TTSModels';
