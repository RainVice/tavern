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

/**
 * 提供图片描述相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ImageCaptionRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * tasks 列表，由当前实例内部维护。
   */
  private tasks: Map<string, CaptionTask> = new Map<string, CaptionTask>();
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
   * 启动Caption 值流程，并记录初始任务或会话状态。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  startCaption(params: CaptionParams): CaptionTask {
    this.taskCounter += 1;
    // task 标识。
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

  /**
   * 更新Progress 列表，同步内部状态并按需发布变更事件。
   * @param taskId 目标任务标识。

   * @returns 更新或读取后的记录副本。
   */
  updateProgress(taskId: string, progress: number): CaptionTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running'; task.updatedAt = Date.now();
    this.events.publish<CaptionProgressPayload>('caption.progress', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 标记Caption 值完成，并写入最终结果。
   * @param taskId 目标任务标识。
   * @param result 返回结果。
   */
  completeCaption(taskId: string, result: CaptionResult): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'completed'; task.progress = 100;
    task.resultText = result.text; task.resultAttachmentId = result.attachmentId;
    task.updatedAt = Date.now();
    this.events.publish<CaptionCompletedPayload>('caption.completed', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 标记Caption 值失败，并保存错误信息。
   * @param taskId 目标任务标识。
   * @param error 错误信息。
   */
  failCaption(taskId: string, error: string): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'failed'; task.error = error; task.updatedAt = Date.now();
    this.events.publish<CaptionFailedPayload>('caption.failed', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 取消Caption 值任务，并发布取消状态。
   * @param taskId 目标任务标识。
   */
  cancelCaption(taskId: string): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled'; task.error = '已取消'; task.updatedAt = Date.now();
    this.events.publish<CaptionCancelledPayload>('caption.cancelled', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 读取指定任务，不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 更新或读取后的记录副本。
   */
  getTask(taskId: string): CaptionTask { return this.copyTask(this.requireTask(taskId)); }

  /**
   * 读取Tasks列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param status 状态值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listTasks(status?: CaptionTaskStatus): Array<CaptionTask> {
    const result = new Array<CaptionTask>();
    const values = Array.from(this.tasks.values());
    for (let index = 0; index < values.length; index += 1) {
      if (status === undefined || values[index].status === status) { result.push(this.copyTask(values[index])); }
    }
    return result;
  }

  /**
   * 根据入参构建Vision Request 值，仅生成数据结构，不直接执行外部请求。
   * @param model 模型名称。


   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildVisionRequest(model: string, imageUrl: string, prompt: string): VisionRequest {
    const image: VisionImageUrl = { url: imageUrl };
    const imagePart: VisionContentPart = { type: 'image_url', text: '', image_url: image };
    const emptyImage: VisionImageUrl = { url: '' };
    const textPart: VisionContentPart = { type: 'text', text: prompt, image_url: emptyImage };
    const message: VisionMessage = { role: 'user', content: [imagePart, textPart] };
    return { model: model, messages: [message] };
  }

  /**
   * 导出数据，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 可持久化或可传输的导出内容。
   */
  exportData(): CaptionExportData { return { tasks: this.listTasks() }; }

  /**
   * 从外部数据导入Data 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  importData(data: CaptionExportData): void {
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
  private requireTask(taskId: string): CaptionTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) { throw new Error(`Caption 任务未找到: ${taskId}`); }
    return task;
  }

  /**
   * 复制Task 值，避免外部修改内部状态。
   */
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

  /**
   * 复制Params 列表，避免外部修改内部状态。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  private copyParams(params: CaptionParams): CaptionParams {
    return {
      imageAttachmentId: params.imageAttachmentId,
      provider: params.provider,
      prompt: params.prompt,
      model: params.model,
      autoCaption: params.autoCaption,
    };
  }

  /**
   * 解析TaskCounter，非法输入会返回失败标记或空结果。
   * @param taskId 目标任务标识。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('caption-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
