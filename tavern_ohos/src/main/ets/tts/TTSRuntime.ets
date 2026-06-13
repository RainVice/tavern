import { EventBus } from '../runtime/EventBus';
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

export class TTSRuntime {
  private events: EventBus;
  private profiles: Map<string, TTSVoiceProfile> = new Map<string, TTSVoiceProfile>();
  private tasks: Map<string, TTSTask> = new Map<string, TTSTask>();
  private profileCounter: number = 0;
  private taskCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

  // 发起语音合成
  synthesize(params: TTSSynthesisParams): TTSTask {
    this.taskCounter += 1;
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

  // 更新合成进度
  updateProgress(taskId: string, progress: number): TTSTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running';
    task.updatedAt = Date.now();
    const payload: TTSSynthesisProgressPayload = { task: this.cloneTask(task) };
    this.events.publish<TTSSynthesisProgressPayload>('tts.synthesis.progress', payload);
    return this.cloneTask(task);
  }

  // 完成语音合成
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

  // 合成失败
  failSynthesis(taskId: string, error: string): TTSTask {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    const payload: TTSSynthesisFailedPayload = { task: this.cloneTask(task) };
    this.events.publish<TTSSynthesisFailedPayload>('tts.synthesis.failed', payload);
    return this.cloneTask(task);
  }

  // 取消合成
  cancelSynthesis(taskId: string): TTSTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled';
    task.error = '已取消';
    task.updatedAt = Date.now();
    const payload: TTSSynthesisCancelledPayload = { task: this.cloneTask(task) };
    this.events.publish<TTSSynthesisCancelledPayload>('tts.synthesis.cancelled', payload);
    return this.cloneTask(task);
  }

  // 获取任务
  getTask(taskId: string): TTSTask {
    return this.cloneTask(this.requireTask(taskId));
  }

  // 列出任务
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

  // 保存语音配置
  saveVoiceProfile(
    name: string,
    provider: TTSProvider,
    voiceId: string,
    language: string,
    speed: number,
    pitch: number,
    format: string,
  ): TTSVoiceProfile {
    this.profileCounter += 1;
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

  // 获取语音配置
  getVoiceProfile(profileId: string): TTSVoiceProfile {
    return this.cloneProfile(this.requireProfile(profileId));
  }

  // 列出所有语音配置
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

  // 删除语音配置
  deleteVoiceProfile(profileId: string): void {
    this.requireProfile(profileId);
    this.profiles.delete(profileId);
  }

  // 构建 OpenAI TTS 请求体
  buildOpenAITTSRequest(text: string, voice: string, model: string, speed: number, format: string): OpenAITTSRequest {
    return {
      model: model,
      input: text,
      voice: voice,
      speed: speed,
      response_format: format,
    };
  }

  // 构建 Edge TTS 请求体
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

  // 导入
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

  private requireTask(taskId: string): TTSTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`TTS 任务未找到: ${taskId}`);
    }
    return task;
  }

  private requireProfile(profileId: string): TTSVoiceProfile {
    const profile = this.profiles.get(profileId);
    if (profile === undefined) {
      throw new Error(`TTS 语音配置未找到: ${profileId}`);
    }
    return profile;
  }

  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('tts-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(4));
    return parsed > 0 ? parsed : 0;
  }

  private parseProfileCounter(profileId: string): number {
    if (!profileId.startsWith('tts-profile-')) {
      return 0;
    }
    const parsed = Number(profileId.substring(12));
    return parsed > 0 ? parsed : 0;
  }
}
