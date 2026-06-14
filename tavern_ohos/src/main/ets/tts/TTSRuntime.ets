import { EventBus } from '../runtime/EventBus';
import type { MediaFormat } from '../contracts/PublicContracts';
import type {
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

/**
 * 提供文字转语音相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class TTSRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 语音配置映射表，以配置标识为键。
   */
  private profiles: Map<string, TTSVoiceProfile> = new Map<string, TTSVoiceProfile>();
  /**
   * 合成任务映射表，以任务标识为键。
   */
  private tasks: Map<string, TTSTask> = new Map<string, TTSTask>();
  /**
   * 语音配置计数器，用于生成唯一配置标识。
   */
  private profileCounter: number = 0;
  /**
   * 任务计数器，用于生成唯一任务标识。
   */
  private taskCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 发起一次 TTS 合成任务，创建任务记录并发布任务启动事件。
   * @param params 合成请求参数。
   * @returns 新创建的合成任务副本。
   */
  synthesize(params: TTSSynthesisParams): TTSTask {
    this.taskCounter += 1;
    // task 标识。
    const taskId = `tts-${this.taskCounter}`;
    const now = Date.now();
    const task: TTSTask = {
      taskId: taskId,
      params: this.cloneParams(params),
      status: 'pending',
      progress: 0,
      resultAttachmentId: '',
      duration: 0,
      error: '',
      createdAt: now,
      updatedAt: now,
    };
    this.tasks.set(taskId, this.cloneTask(task));
    const payload: TTSSynthesisStartedPayload = { task: this.cloneTask(task) };
    this.events.publish<TTSSynthesisStartedPayload>('tts.synthesis.started', payload);
    return this.cloneTask(task);
  }

  /**
   * 更新合成任务的进度，并发布进度更新事件。
   * @param taskId 目标任务标识。
   * @param progress 进度百分比（0-100）。
   * @returns 更新后的任务副本。
   */
  updateProgress(taskId: string, progress: number): TTSTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running';
    task.updatedAt = Date.now();
    const payload: TTSSynthesisProgressPayload = { task: this.cloneTask(task) };
    this.events.publish<TTSSynthesisProgressPayload>('tts.synthesis.progress', payload);
    return this.cloneTask(task);
  }

  /**
   * 标记合成任务为完成状态，记录音频附件信息。
   * @param taskId 目标任务标识。
   * @param result 合成音频的结果信息。
   * @returns 更新后的任务副本。
   */
  completeSynthesis(taskId: string, result: TTSAudioResult): TTSTask {
    const task = this.requireTask(taskId);
    task.status = 'completed';
    task.progress = 100;
    task.resultAttachmentId = result.attachmentId;
    task.duration = result.duration;
    task.updatedAt = Date.now();
    const payload: TTSSynthesisCompletedPayload = { task: this.cloneTask(task) };
    this.events.publish<TTSSynthesisCompletedPayload>('tts.synthesis.completed', payload);
    return this.cloneTask(task);
  }

  /**
   * 标记合成任务为失败状态，并记录错误信息。
   * @param taskId 目标任务标识。
   * @param error 错误描述。
   * @returns 更新后的任务副本。
   */
  failSynthesis(taskId: string, error: string): TTSTask {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    const payload: TTSSynthesisFailedPayload = { task: this.cloneTask(task) };
    this.events.publish<TTSSynthesisFailedPayload>('tts.synthesis.failed', payload);
    return this.cloneTask(task);
  }

  /**
   * 取消合成任务，并发布取消事件。
   * @param taskId 目标任务标识。
   * @returns 更新后的任务副本。
   */
  cancelSynthesis(taskId: string): TTSTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled';
    task.error = '已取消';
    task.updatedAt = Date.now();
    const payload: TTSSynthesisCancelledPayload = { task: this.cloneTask(task) };
    this.events.publish<TTSSynthesisCancelledPayload>('tts.synthesis.cancelled', payload);
    return this.cloneTask(task);
  }

  /**
   * 读取指定合成任务。
   * @param taskId 目标任务标识。
   * @returns 任务副本。
   */
  getTask(taskId: string): TTSTask {
    return this.cloneTask(this.requireTask(taskId));
  }

  /**
   * 列出所有合成任务，可按状态过滤。
   * @param status 可选的状态过滤条件。
   * @returns 任务副本列表。
   */
  listTasks(status?: TTSTaskStatus): Array<TTSTask> {
    const result = new Array<TTSTask>();
    const values = Array.from(this.tasks.values());
    for (let index = 0; index < values.length; index += 1) {
      if (status === undefined || values[index].status === status) {
        result.push(this.cloneTask(values[index]));
      }
    }
    return result;
  }

  /**
   * 保存一条语音配置，并发布配置保存事件。
   * @param name 配置名称。
   * @param provider 提供商类型。
   * @param voiceId 音色标识。
   * @param language 语言代码。
   * @param speed 语速倍率。
   * @param pitch 音高调整值。
   * @param format 音频格式。
   * @returns 新创建的语音配置副本。
   */
  saveVoiceProfile(
    name: string,
    provider: TTSProvider,
    voiceId: string,
    language: string,
    speed: number,
    pitch: number,
    format: MediaFormat,
  ): TTSVoiceProfile {
    this.profileCounter += 1;
    // profile 标识。
    const profileId = `tts-profile-${this.profileCounter}`;
    const now = Date.now();
    const profile: TTSVoiceProfile = {
      profileId: profileId,
      name: name,
      provider: provider,
      voiceId: voiceId,
      language: language,
      speed: speed,
      pitch: pitch,
      format: format,
      createdAt: now,
      updatedAt: now,
    };
    this.profiles.set(profileId, this.cloneProfile(profile));
    const payload: TTSVoiceProfileSavedPayload = { profile: this.cloneProfile(profile) };
    this.events.publish<TTSVoiceProfileSavedPayload>('tts.voice.profile.saved', payload);
    return this.cloneProfile(profile);
  }

  /**
   * 读取指定语音配置。
   * @param profileId 语音配置标识。
   * @returns 语音配置副本。
   */
  getVoiceProfile(profileId: string): TTSVoiceProfile {
    return this.cloneProfile(this.requireProfile(profileId));
  }

  /**
   * 列出所有语音配置，可按提供商类型过滤。
   * @param provider 可选的服务提供商过滤条件。
   * @returns 语音配置副本列表。
   */
  listVoiceProfiles(provider?: TTSProvider): Array<TTSVoiceProfile> {
    const result = new Array<TTSVoiceProfile>();
    const values = Array.from(this.profiles.values());
    for (let index = 0; index < values.length; index += 1) {
      if (provider === undefined || values[index].provider === provider) {
        result.push(this.cloneProfile(values[index]));
      }
    }
    return result;
  }

  /**
   * 删除指定的语音配置。
   * @param profileId 要删除的配置标识。
   */
  deleteVoiceProfile(profileId: string): void {
    this.requireProfile(profileId);
    this.profiles.delete(profileId);
  }

  /**
   * 根据入参构建 OpenAI TTS 请求体，仅生成数据结构，不直接发送请求。
   * @param text 待合成的文本。
   * @param voice 音色标识。
   * @param model 模型名称。
   * @param speed 语速倍率。
   * @param format 音频格式。
   * @returns OpenAI TTS 请求体。
   */
  buildOpenAITTSRequest(
    text: string,
    voice: string,
    model: string,
    speed: number,
    format: MediaFormat,
  ): OpenAITTSRequest {
    return {
      model: model,
      input: text,
      voice: voice,
      speed: speed,
      response_format: format,
    };
  }

  /**
   * 根据入参构建 Edge TTS 请求体，仅生成数据结构，不直接发送请求。
   * @param text 待合成的文本。
   * @param voice 音色标识。
   * @param rate 语速调整值。
   * @param pitch 音高调整值。
   * @returns Edge TTS 请求体。
   */
  buildEdgeTTSRequest(text: string, voice: string, rate: number, pitch: number): EdgeTTSRequest {
    return {
      text: text,
      voice: voice,
      rate: rate,
      pitch: pitch,
    };
  }

  /**
   * 导出所有 TTS 数据，包含语音配置和任务记录。
   * @returns TTS 数据的导出结构。
   */
  exportData(): TTSExportData {
    return {
      profiles: this.listVoiceProfiles(),
      tasks: this.listTasks(),
    };
  }

  /**
   * 导入 TTS 数据，恢复语音配置和任务记录。
   * @param data TTS 数据的导出结构。
   */
  importData(data: TTSExportData): void {
    for (let index = 0; index < data.profiles.length; index += 1) {
      const profile = this.cloneProfile(data.profiles[index]);
      this.profiles.set(profile.profileId, profile);
      this.profileCounter = Math.max(this.profileCounter, this.parseProfileCounter(profile.profileId));
    }
    for (let index = 0; index < data.tasks.length; index += 1) {
      const task = this.cloneTask(data.tasks[index]);
      this.tasks.set(task.taskId, task);
      this.taskCounter = Math.max(this.taskCounter, this.parseTaskCounter(task.taskId));
    }
  }

  /**
   * 复制合成任务，避免外部修改内部状态。
   */
  private cloneTask(task: TTSTask): TTSTask {
    return {
      taskId: task.taskId,
      params: this.cloneParams(task.params),
      status: task.status,
      progress: task.progress,
      resultAttachmentId: task.resultAttachmentId,
      duration: task.duration,
      error: task.error,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }

  /**
   * 复制语音配置，避免外部修改内部状态。
   */
  private cloneProfile(profile: TTSVoiceProfile): TTSVoiceProfile {
    return {
      profileId: profile.profileId,
      name: profile.name,
      provider: profile.provider,
      voiceId: profile.voiceId,
      language: profile.language,
      speed: profile.speed,
      pitch: profile.pitch,
      format: profile.format,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    };
  }

  /**
   * 复制合成请求参数，避免外部修改内部状态。
   * @param params 合成请求参数。
   */
  private cloneParams(params: TTSSynthesisParams): TTSSynthesisParams {
    return {
      text: params.text,
      voiceProfileId: params.voiceProfileId,
      skipCodeBlocks: params.skipCodeBlocks,
      speed: params.speed,
      pitch: params.pitch,
      format: params.format,
    };
  }

  /**
   * 读取必须存在的合成任务，缺失时抛出错误。
   * @param taskId 目标任务标识。
   */
  private requireTask(taskId: string): TTSTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`TTS 任务未找到: ${taskId}`);
    }
    return task;
  }

  /**
   * 读取必须存在的语音配置，缺失时抛出错误。
   * @param profileId 语音配置标识。
   */
  private requireProfile(profileId: string): TTSVoiceProfile {
    const profile = this.profiles.get(profileId);
    if (profile === undefined) {
      throw new Error(`TTS 语音配置未找到: ${profileId}`);
    }
    return profile;
  }

  /**
   * 从任务标识中解析出计数器值，用于恢复导入时的任务计数器。
   * @param taskId 任务标识。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('tts-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(4));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 从配置标识中解析出计数器值，用于恢复导入时的配置计数器。
   * @param profileId 配置标识。
   */
  private parseProfileCounter(profileId: string): number {
    if (!profileId.startsWith('tts-profile-')) {
      return 0;
    }
    const parsed = Number(profileId.substring(12));
    return parsed > 0 ? parsed : 0;
  }
}
