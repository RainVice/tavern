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

/**
 * 提供语音转文字相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ASRRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * tasks 列表，由当前实例内部维护。
   */
  private tasks: Map<string, ASRTask> = new Map<string, ASRTask>();
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
   * 启动Transcription 值流程，并记录初始任务或会话状态。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  startTranscription(params: ASRTranscriptionParams): ASRTask {
    this.taskCounter += 1;
    // task 标识。
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

  /**
   * 更新Progress 列表，同步内部状态并按需发布变更事件。
   * @param taskId 目标任务标识。

   * @returns 更新或读取后的记录副本。
   */
  updateProgress(taskId: string, progress: number): ASRTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running';
    task.updatedAt = Date.now();
    this.events.publish<ASRTranscriptionProgressPayload>('asr.transcription.progress', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 标记Transcription 值完成，并写入最终结果。
   * @param taskId 目标任务标识。
   * @param result 返回结果。
   */
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

  /**
   * 标记Transcription 值失败，并保存错误信息。
   * @param taskId 目标任务标识。
   * @param error 错误信息。
   */
  failTranscription(taskId: string, error: string): ASRTask {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    this.events.publish<ASRTranscriptionFailedPayload>('asr.transcription.failed', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 取消Transcription 值任务，并发布取消状态。
   * @param taskId 目标任务标识。
   */
  cancelTranscription(taskId: string): ASRTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled';
    task.error = '已取消';
    task.updatedAt = Date.now();
    this.events.publish<ASRTranscriptionCancelledPayload>('asr.transcription.cancelled', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 读取指定任务，不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 更新或读取后的记录副本。
   */
  getTask(taskId: string): ASRTask {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 读取Tasks列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param status 状态值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 根据入参构建Whisper Request 值，仅生成数据结构，不直接执行外部请求。

   * @param model 模型名称。


   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildWhisperRequest(file: string, model: string, language: string, prompt: string): WhisperRequest {
    return { file: file, model: model, language: language, prompt: prompt, response_format: 'text' };
  }

  // 导出
  exportData(): ASRExportData {
    return { tasks: this.listTasks() };
  }

  /**
   * 导入。
   * @param data 数据内容。
   */
  importData(data: ASRExportData): void {
    for (let index = 0; index < data.tasks.length; index += 1) {
      const task = this.copyTask(data.tasks[index]);
      this.tasks.set(task.taskId, task);
      this.taskCounter = Math.max(this.taskCounter, this.parseTaskCounter(task.taskId));
    }
  }

  /**
   * 读取必须存在的Task 值，缺失时抛出错误。
   * @param taskId 目标任务标识。
   */
  private requireTask(taskId: string): ASRTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`ASR 任务未找到: ${taskId}`);
    }
    return task;
  }

  /**
   * 复制Task 值，避免外部修改内部状态。
   */
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

  /**
   * 复制Params 列表，避免外部修改内部状态。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
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

  /**
   * 解析TaskCounter，非法输入会返回失败标记或空结果。
   * @param taskId 目标任务标识。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('asr-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(4));
    return parsed > 0 ? parsed : 0;
  }
}
