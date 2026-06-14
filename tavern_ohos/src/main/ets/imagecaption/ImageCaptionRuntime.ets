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
 * 提供图片描述相关的无 UI 运行时能力，负责 caption 任务生命周期管理、
 * 状态数据读写以及基于事件总线的状态变更广播。
 */
export class ImageCaptionRuntime {
  /**
   * 事件总线实例，用于发布 caption 状态变更事件。
   */
  private events: EventBus;
  /**
   * 全部 caption 任务的内部容器，以 taskId 为键。
   */
  private tasks: Map<string, CaptionTask> = new Map<string, CaptionTask>();
  /**
   * 自增任务计数器，用于生成唯一 taskId。
   */
  private taskCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 启动一条新的图片描述任务，创建初始记录并发布启动事件。
   * @param params 描述任务所需的参数。
   * @returns 创建后的任务记录副本。
   */
  startCaption(params: CaptionParams): CaptionTask {
    this.taskCounter += 1;
    // 生成唯一任务标识
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
   * 更新任务的进度百分比，同步状态为运行中并发布进度事件。
   * @param taskId 目标任务标识。
   * @param progress 进度百分比（0-100），超出范围的值会被钳制。
   * @returns 更新后的任务记录副本。
   */
  updateProgress(taskId: string, progress: number): CaptionTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running'; task.updatedAt = Date.now();
    this.events.publish<CaptionProgressPayload>('caption.progress', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 将任务标记为已完成，写入最终结果并发布完成事件。
   * @param taskId 目标任务标识。
   * @param result 描述结果。
   * @returns 更新后的任务记录副本。
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
   * 将任务标记为失败，保存错误信息并发布失败事件。
   * @param taskId 目标任务标识。
   * @param error 失败描述。
   * @returns 更新后的任务记录副本。
   */
  failCaption(taskId: string, error: string): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'failed'; task.error = error; task.updatedAt = Date.now();
    this.events.publish<CaptionFailedPayload>('caption.failed', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 取消指定 caption 任务，发布取消事件。
   * @param taskId 目标任务标识。
   * @returns 更新后的任务记录副本。
   */
  cancelCaption(taskId: string): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled'; task.error = '已取消'; task.updatedAt = Date.now();
    this.events.publish<CaptionCancelledPayload>('caption.cancelled', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 读取指定任务记录，任务不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 任务记录副本。
   */
  getTask(taskId: string): CaptionTask { return this.copyTask(this.requireTask(taskId)); }

  /**
   * 按状态筛选并返回任务列表，所有返回值均为副本。
   * @param status 可选的状态筛选条件；不传则返回全部任务。
   * @returns 符合条件的任务记录列表（副本）。
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
   * 根据入参构建发送给视觉模型的请求数据结构，不直接发起网络请求。
   * @param model 模型名称。
   * @param imageUrl 待描述的图片 URL。
   * @param prompt 描述引导文本。
   * @returns 构建完成的视觉请求数据。
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
   * 导出当前所有任务数据，用于备份或与 SillyTavern 数据互通。
   * @returns 可持久化的任务集合。
   */
  exportData(): CaptionExportData { return { tasks: this.listTasks() }; }

  /**
   * 从外部数据导入任务记录，并同步计数器防止任务标识冲突。
   * @param data 待导入的任务集合。
   */
  importData(data: CaptionExportData): void {
    for (let index = 0; index < data.tasks.length; index += 1) {
      const task = this.copyTask(data.tasks[index]);
      this.tasks.set(task.taskId, task);
      this.taskCounter = Math.max(this.taskCounter, this.parseTaskCounter(task.taskId));
    }
  }

  /**
   * 获取指定任务，不存在时抛出异常。
   * @param taskId 目标任务标识。
   */
  private requireTask(taskId: string): CaptionTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) { throw new Error(`Caption 任务未找到: ${taskId}`); }
    return task;
  }

  /**
   * 深拷贝任务记录，避免外部修改内部状态。
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
   * 深拷贝任务参数，避免外部修改内部状态。
   * @param params 待拷贝的参数。
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
   * 从任务标识中解析出自增序号，用于同步计数器。
   * @param taskId 目标任务标识。
   * @returns 解析出的序号，非法格式返回 0。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('caption-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
