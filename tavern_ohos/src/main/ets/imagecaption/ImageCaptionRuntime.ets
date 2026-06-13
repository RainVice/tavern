import { EventBus } from '../runtime/EventBus';
import type {
  CaptionCancelledPayload,
  CaptionCompletedPayload,
  CaptionExportData,
  CaptionFailedPayload,
  CaptionParams,
  CaptionProgressPayload,
  CaptionResult,
	  CaptionStartedPayload,
	  CaptionTask,
	  CaptionTaskStatus,
	  VisionContentPart,
	  VisionImageUrl,
	  VisionMessage,
	  VisionRequest,
} from './ImageCaptionModels';

export class ImageCaptionRuntime {
  private events: EventBus;
  private tasks: Map<string, CaptionTask> = new Map<string, CaptionTask>();
  private taskCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

  // 发起 caption
  startCaption(params: CaptionParams): CaptionTask {
    this.taskCounter += 1;
    const taskId = `caption-${this.taskCounter}`;
    const now = Date.now();
    const task: CaptionTask = {
      taskId: taskId, params: this.copyParams(params), status: 'pending', progress: 0,
      resultText: '', resultAttachmentId: '', error: '', createdAt: now, updatedAt: now,
    };
    this.tasks.set(taskId, this.copyTask(task));
    this.events.publish<CaptionStartedPayload>('caption.started', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  updateProgress(taskId: string, progress: number): CaptionTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running'; task.updatedAt = Date.now();
    this.events.publish<CaptionProgressPayload>('caption.progress', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  completeCaption(taskId: string, result: CaptionResult): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'completed'; task.progress = 100;
    task.resultText = result.text; task.resultAttachmentId = result.attachmentId;
    task.updatedAt = Date.now();
    this.events.publish<CaptionCompletedPayload>('caption.completed', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  failCaption(taskId: string, error: string): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'failed'; task.error = error; task.updatedAt = Date.now();
    this.events.publish<CaptionFailedPayload>('caption.failed', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  cancelCaption(taskId: string): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled'; task.error = '已取消'; task.updatedAt = Date.now();
    this.events.publish<CaptionCancelledPayload>('caption.cancelled', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  getTask(taskId: string): CaptionTask { return this.copyTask(this.requireTask(taskId)); }

  listTasks(status?: CaptionTaskStatus): Array<CaptionTask> {
    const result = new Array<CaptionTask>();
    const values = Array.from(this.tasks.values());
    for (let index = 0; index < values.length; index += 1) {
      if (status === undefined || values[index].status === status) { result.push(this.copyTask(values[index])); }
    }
    return result;
  }

  // 构建 Vision 请求
  buildVisionRequest(model: string, imageUrl: string, prompt: string): VisionRequest {
    const image: VisionImageUrl = { url: imageUrl };
    const imagePart: VisionContentPart = { type: 'image_url', text: '', image_url: image };
    const emptyImage: VisionImageUrl = { url: '' };
    const textPart: VisionContentPart = { type: 'text', text: prompt, image_url: emptyImage };
    const message: VisionMessage = { role: 'user', content: [imagePart, textPart] };
    return { model: model, messages: [message] };
  }

  exportData(): CaptionExportData { return { tasks: this.listTasks() }; }

  importData(data: CaptionExportData): void {
    for (let index = 0; index < data.tasks.length; index += 1) {
      const task = this.copyTask(data.tasks[index]);
      this.tasks.set(task.taskId, task);
      this.taskCounter = Math.max(this.taskCounter, this.parseTaskCounter(task.taskId));
    }
  }

  private requireTask(taskId: string): CaptionTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) { throw new Error(`Caption 任务未找到: ${taskId}`); }
    return task;
  }

  private copyTask(task: CaptionTask): CaptionTask {
    return {
      taskId: task.taskId,
      params: this.copyParams(task.params),
      status: task.status,
      progress: task.progress,
      resultText: task.resultText,
      resultAttachmentId: task.resultAttachmentId,
      error: task.error,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }

  private copyParams(params: CaptionParams): CaptionParams {
    return {
      imageAttachmentId: params.imageAttachmentId,
      provider: params.provider,
      prompt: params.prompt,
      model: params.model,
      autoCaption: params.autoCaption,
    };
  }

  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('caption-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
