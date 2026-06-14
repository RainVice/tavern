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
   * profiles 列表，由当前实例内部维护。
   */
  private profiles: Map<string, TTSVoiceProfile> = new Map<string, TTSVoiceProfile>();
  /**
   * tasks 列表，由当前实例内部维护。
   */
  private tasks: Map<string, TTSTask> = new Map<string, TTSTask>();
  /**
   * profile Counter 值，由当前实例内部维护。
   */
  private profileCounter: number = 0;
  /**
   * task Counter 值，由当前实例内部维护。
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
   * 执行 synthesize 的内部处理步骤，供当前模块复用。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 更新Progress 列表，同步内部状态并按需发布变更事件。
   * @param taskId 目标任务标识。

   * @returns 更新或读取后的记录副本。
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
   * 标记Synthesis 列表完成，并写入最终结果。
   * @param taskId 目标任务标识。
   * @param result 返回结果。
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
   * 标记Synthesis 列表失败，并保存错误信息。
   * @param taskId 目标任务标识。
   * @param error 错误信息。
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
   * 取消Synthesis 列表任务，并发布取消状态。
   * @param taskId 目标任务标识。
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
   * 读取指定任务，不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 更新或读取后的记录副本。
   */
  getTask(taskId: string): TTSTask {
    return this.cloneTask(this.requireTask(taskId));
  }

  /**
   * 读取Tasks列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param status 状态值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 创建或写入连接配置，完成持久化后返回可供调用方使用的结果。
   * @param name 显示名称或注册名称。

   * @param voiceId 目标音色标识。
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
   * 读取指定连接配置，不存在时抛出错误。
   * @param profileId 目标连接或预设配置标识。
   * @returns 更新或读取后的记录副本。
   */
  getVoiceProfile(profileId: string): TTSVoiceProfile {
    return this.cloneProfile(this.requireProfile(profileId));
  }

  /**
   * 读取VoiceProfiles列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 删除语音配置。
   * @param profileId 配置标识。
   */
  deleteVoiceProfile(profileId: string): void {
    this.requireProfile(profileId);
    this.profiles.delete(profileId);
  }

  /**
   * 根据入参构建Open AITTSRequest 值，仅生成数据结构，不直接执行外部请求。
   * @param text 文本内容。

   * @param model 模型名称。


   * @returns 构建好的请求、Prompt 或中间数据。
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
   * 根据入参构建Edge TTSRequest 值，仅生成数据结构，不直接执行外部请求。
   * @param text 文本内容。



   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildEdgeTTSRequest(text: string, voice: string, rate: number, pitch: number): EdgeTTSRequest {
    return {
      text: text,
      voice: voice,
      rate: rate,
      pitch: pitch,
    };
  }

  // 导出
  exportData(): TTSExportData {
    return {
      profiles: this.listVoiceProfiles(),
      tasks: this.listTasks(),
    };
  }

  /**
   * 导入。
   * @param data 数据内容。
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
   * 复制Task 值，避免外部修改内部状态。
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
   * 复制Profile 值，避免外部修改内部状态。
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
   * 复制Params 列表，避免外部修改内部状态。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 读取必须存在的Task 值，缺失时抛出错误。
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
   * 读取必须存在的Profile 值，缺失时抛出错误。
   * @param profileId 目标连接或预设配置标识。
   */
  private requireProfile(profileId: string): TTSVoiceProfile {
    const profile = this.profiles.get(profileId);
    if (profile === undefined) {
      throw new Error(`TTS 语音配置未找到: ${profileId}`);
    }
    return profile;
  }

  /**
   * 解析TaskCounter，非法输入会返回失败标记或空结果。
   * @param taskId 目标任务标识。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('tts-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(4));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 解析ProfileCounter，非法输入会返回失败标记或空结果。
   * @param profileId 目标连接或预设配置标识。
   */
  private parseProfileCounter(profileId: string): number {
    if (!profileId.startsWith('tts-profile-')) {
      return 0;
    }
    const parsed = Number(profileId.substring(12));
    return parsed > 0 ? parsed : 0;
  }
}
