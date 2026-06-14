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
 * 管理图片描述任务从创建到完成的完整生命周期，通过事件驱动 UI 层和外部模块同步任务进度和结果。
 * 外部调用方（如图片详情页、自动描述钩子、备份导入导出）通过此类完成图片描述操作。
 */
export class ImageCaptionRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 内存中的描述任务缓存，以任务 ID 为键。
   */
  private tasks: Map<string, CaptionTask> = new Map<string, CaptionTask>();
  /**
   * 自增任务计数器，用于生成唯一任务 ID。
   */
  private taskCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * 在应用启动时由更高层运行时容器调用，为图片描述功能注入事件基础设施。
   * @param events 事件总线，用于发布描述任务的启动('caption.started')/进度('caption.progress')/完成('caption.completed')/失败('caption.failed')/取消('caption.cancelled')事件，驱动 UI 层展示任务状态。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建并启动一个新的图片描述任务，记录初始 pending 状态并发布启动事件。
   * 由 UI 层（如图片详情页的"描述图片"按钮）或自动描述钩子（autoCaption 为 true 时）调用。
   * @param params 描述任务参数，包括目标图片附件 ID、提供商、提示词和模型名称，用于创建 CaptionTask 和后续构建视觉 API 请求。
   * @returns 创建后的描述任务对象副本，调用方可据此跟踪任务 ID 和初始状态。
   */
  startCaption(params: CaptionParams): CaptionTask {
    this.taskCounter += 1;
    // 生成唯一任务 ID，格式：caption-{自增序号}
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
   * 更新描述任务进度百分比，将状态切换为 running 并发布进度事件。
   * 由执行描述任务的异步流程（如轮询视觉 API 响应进度）调用，驱动 UI 层展示实时进度。
   * @param taskId 目标任务标识，用于在内存索引 tasks Map 中定位目标 CaptionTask。
   * @param progress 当前进度值（0-100），会裁剪到合法范围再赋值。
   * @returns 更新后的描述任务对象副本。
   */
  updateProgress(taskId: string, progress: number): CaptionTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running'; task.updatedAt = Date.now();
    this.events.publish<CaptionProgressPayload>('caption.progress', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 将指定任务标记为已完成，写入描述结果文本和附件 ID，并发布完成事件。
   * 由视觉 API 调用方在成功获取描述结果后调用，通知 UI 层显示最终描述内容。
   * @param taskId 目标任务标识，用于在内存索引中定位目标 CaptionTask。
   * @param result 包含描述文本和附件 ID 的结果对象，来自 API 响应解析后的结果。
   * @returns 更新后的描述任务对象副本。
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
   * 将指定任务标记为失败，记录错误信息并发布失败事件。
   * 由视觉 API 调用方在请求出错或响应异常后调用，通知 UI 层显示错误提示。
   * @param taskId 目标任务标识，用于在内存索引中定位目标 CaptionTask。
   * @param error 失败原因描述，来自捕获的异常或 API 错误消息。
   * @returns 更新后的描述任务对象副本。
   */
  failCaption(taskId: string, error: string): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'failed'; task.error = error; task.updatedAt = Date.now();
    this.events.publish<CaptionFailedPayload>('caption.failed', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 取消指定描述任务，将状态设为 cancelled 并发布取消事件。
   * 由 UI 层（如用户点击"取消"按钮）调用，终止正在运行或未开始的描述任务，并通知外部订阅者。
   * @param taskId 目标任务标识，用于在内存索引中定位目标 CaptionTask。
   * @returns 更新后的任务对象副本。
   */
  cancelCaption(taskId: string): CaptionTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled'; task.error = '已取消'; task.updatedAt = Date.now();
    this.events.publish<CaptionCancelledPayload>('caption.cancelled', { task: this.copyTask(task) });
    return this.copyTask(task);
  }

  /**
   * 根据任务 ID 获取描述任务副本，不存在时抛出异常。
   * 由 UI 层或外部模块在需要查询特定任务状态时调用。
   * @param taskId 目标任务标识，用于在内存索引 tasks Map 中查找。
   * @returns 任务对象的深拷贝副本。
   */
  getTask(taskId: string): CaptionTask { return this.copyTask(this.requireTask(taskId)); }

  /**
   * 按状态筛选列出描述任务，不传状态则返回全部任务。
   * 由需要展示任务列表的 UI（如任务历史面板）或备份导出流程调用。
   * @param status 可选的任务状态过滤条件，如 'completed'、'failed' 等，用于筛选特定生命周期的任务。
   * @returns 符合条件的任务对象深拷贝列表。
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
   * 构建发送给视觉 API 的请求结构，包含模型名称、图片 URL 和提示词。
   * 由执行描述任务的异步流程在向视觉 API 发送请求前调用，组装符合 API 格式的请求负载。
   * @param model 模型名称，用于填充 VisionRequest.model 字段。
   * @param imageUrl 图片的 URL 地址，用于构造 VisionContentPart 中的 image_url 引用。
   * @param prompt 描述提示词文本，用于构造 VisionContentPart 中的 text 内容。
   * @returns 构建完成的 VisionRequest 数据结构，可直接传递给视觉 API 调用。
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
   * 导出所有描述任务数据，用于备份或与外部系统互通。
   * 由备份/恢复流程或数据迁移功能调用，序列化当前内存中的所有任务记录。
   * @returns 包含全部描述任务的可序列化导出对象。
   */
  exportData(): CaptionExportData { return { tasks: this.listTasks() }; }

  /**
   * 从外部数据导入描述任务记录，恢复运行时状态。
   * 由备份/恢复流程在应用启动时或导入操作时调用，将导出的任务数据回填到内存索引中。
   * @param data 导入的描述任务导出数据，包含待恢复的全部任务记录列表。
   */
  importData(data: CaptionExportData): void {
    for (let index = 0; index < data.tasks.length; index += 1) {
      const task = this.copyTask(data.tasks[index]);
      this.tasks.set(task.taskId, task);
      this.taskCounter = Math.max(this.taskCounter, this.parseTaskCounter(task.taskId));
    }
  }

  /**
   * 根据任务 ID 查找任务，不存在时抛出异常。
   * @param taskId 目标任务标识。
   * @returns 匹配的描述任务对象。
   */
  private requireTask(taskId: string): CaptionTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) { throw new Error(`Caption 任务未找到: ${taskId}`); }
    return task;
  }

  /**
   * 深拷贝描述任务，防止外部修改影响内部状态。
   * @param task 原始任务对象。
   * @returns 字段值完全一致的独立副本。
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
   * 深拷贝描述参数，防止外部修改影响内部状态。
   * @param params 原始描述参数。
   * @returns 字段值完全一致的独立副本。
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
   * 从任务 ID 中解析出自增序号，用于恢复 taskCounter。
   * @param taskId 描述任务标识，格式为 caption-{数字}。
   * @returns 解析出的序号值，解析失败时返回 0。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('caption-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
