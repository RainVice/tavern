import { EventBus } from '../runtime/EventBus';
import type {
  ASRExportData,
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

export class ASRRuntime {
  private events: EventBus;
  private tasks: Map<string, ASRTask> = new Map<string, ASRTask>();
  private taskCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

  // 发起转录
  startTranscription(params: ASRTranscriptionParams): ASRTask {
    this.taskCounter += 1;
    const taskId = `asr-${this.taskCounter}`;
    const now = Date.now();
    const task: ASRTask = {
      taskId: taskId,
      params: this.copyParams(params),
      status: 'pending',
      progress: 0,
      transcript: '',
      confidence: 0,
      duration: 0,
      error: '',
      createdAt: now,
      updatedAt: now,
    };
    this.tasks.set(taskId, this.copyTask(task));
    this.events.publish<ASRTranscriptionStartedPayload>('asr.transcription.started', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  // 更新进度
  updateProgress(taskId: string, progress: number): ASRTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running';
    task.updatedAt = Date.now();
    this.events.publish<ASRTranscriptionProgressPayload>('asr.transcription.progress', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  // 完成转录
  completeTranscription(taskId: string, result: ASRTranscriptionResult): ASRTask {
    const task = this.requireTask(taskId);
    task.status = 'completed';
    task.progress = 100;
    task.transcript = result.transcript;
    task.confidence = result.confidence;
    task.duration = result.duration;
    task.updatedAt = Date.now();
    this.events.publish<ASRTranscriptionCompletedPayload>('asr.transcription.completed', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  // 失败
  failTranscription(taskId: string, error: string): ASRTask {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    this.events.publish<ASRTranscriptionFailedPayload>('asr.transcription.failed', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  // 取消
  cancelTranscription(taskId: string): ASRTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled';
    task.error = '已取消';
    task.updatedAt = Date.now();
    this.events.publish<ASRTranscriptionCancelledPayload>('asr.transcription.cancelled', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  // 获取任务
  getTask(taskId: string): ASRTask {
    return this.copyTask(this.requireTask(taskId));
  }

  // 列出任务
  listTasks(status?: ASRTaskStatus): Array<ASRTask> {
    const result = new Array<ASRTask>();
    const values = Array.from(this.tasks.values());
    for (let index = 0; index < values.length; index += 1) {
      if (status === undefined || values[index].status === status) {
        result.push(this.copyTask(values[index]));
      }
    }
    return result;
  }

  // 构建 Whisper 请求
  buildWhisperRequest(file: string, model: string, language: string, prompt: string): WhisperRequest {
    return { file: file, model: model, language: language, prompt: prompt, response_format: 'text' };
  }

  // 导出
  exportData(): ASRExportData {
    return { tasks: this.listTasks() };
  }

  // 导入
  importData(data: ASRExportData): void {
    for (let index = 0; index < data.tasks.length; index += 1) {
      const task = this.copyTask(data.tasks[index]);
      this.tasks.set(task.taskId, task);
      this.taskCounter = Math.max(this.taskCounter, this.parseTaskCounter(task.taskId));
    }
  }

  private requireTask(taskId: string): ASRTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`ASR 任务未找到: ${taskId}`);
    }
    return task;
  }

  private copyTask(task: ASRTask): ASRTask {
    return {
      taskId: task.taskId,
      params: this.copyParams(task.params),
      status: task.status,
      progress: task.progress,
      transcript: task.transcript,
      confidence: task.confidence,
      duration: task.duration,
      error: task.error,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }

  private copyParams(params: ASRTranscriptionParams): ASRTranscriptionParams {
    return {
      source: params.source,
      provider: params.provider,
      language: params.language,
      model: params.model,
      autoSend: params.autoSend,
      prompt: params.prompt,
    };
  }

  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('asr-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(4));
    return parsed > 0 ? parsed : 0;
  }
}
