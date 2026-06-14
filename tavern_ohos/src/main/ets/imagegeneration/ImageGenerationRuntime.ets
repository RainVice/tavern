import { EventBus } from '../runtime/EventBus';
import type {
  ComfyUIRequest,
  ImageGenerationCancelledPayload,
  ImageGenerationCompletedPayload,
  ImageGenerationExportData,
  ImageGenerationFailedPayload,
  ImageGenerationMetadata,
  ImageGenerationParams,
  ImageGenerationPreset,
  ImageGenerationPresetSavedPayload,
  ImageGenerationProgressPayload,
  ImageGenerationStartedPayload,
  ImageGenerationStatus,
  ImageGenerationTask,
  OpenAIImageRequest,
  SdWebUIRequest,
  WorkersAIRequest,
} from './ImageGenerationModels';

/**
 * 提供图片生成相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ImageGenerationRuntime {
  /**
   * 事件总线，用于发布和订阅图片生成生命周期事件。
   */
  private events: EventBus;
  /**
   * 任务映射表，以 taskId 为键存储所有图片生成任务。
   */
  private tasks: Map<string, ImageGenerationTask> = new Map<string, ImageGenerationTask>();
  /**
   * 预设映射表，以 presetId 为键存储所有图片生成预设。
   */
  private presets: Map<string, ImageGenerationPreset> = new Map<string, ImageGenerationPreset>();
  /**
   * 自增任务计数器，用于生成唯一任务标识。
   */
  private taskCounter: number = 0;
  /**
   * 自增预设计数器，用于生成唯一预设标识。
   */
  private presetCounter: number = 0;

  /**
   * 初始化运行时实例，关联事件总线用于发布生命周期事件。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建图片生成任务，加入待处理队列并发布启动事件。
   * @param params 图片生成参数，包含后端类型、提示词、尺寸和采样参数等。
   * @returns 创建后的任务实例副本。
   */
  generateImage(params: ImageGenerationParams): ImageGenerationTask {
    this.taskCounter += 1;
    // task 标识。
    const taskId = `img-gen-${this.taskCounter}`;
    const now = Date.now();
    const task: ImageGenerationTask = {
      taskId: taskId,
      backend: params.backend,
      params: this.cloneParams(params),
      status: 'pending',
      progress: 0,
      resultAttachmentIds: new Array<string>(),
      error: '',
      metadata: {},
      createdAt: now,
      updatedAt: now,
    };
    this.tasks.set(taskId, this.cloneTask(task));
    const payload: ImageGenerationStartedPayload = { task: this.cloneTask(task) };
    this.events.publish<ImageGenerationStartedPayload>('image.generation.started', payload);
    return this.cloneTask(task);
  }

  /**
   * 更新指定任务的生成进度，同时将状态标记为运行中并发布进度事件。
   * @param taskId 目标任务标识。
   * @param progress 进度百分比值，超出 0–100 范围时会自动裁剪到有效区间。
   * @returns 更新后的任务实例副本。
   */
  updateProgress(taskId: string, progress: number): ImageGenerationTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running';
    task.updatedAt = Date.now();
    const payload: ImageGenerationProgressPayload = { task: this.cloneTask(task) };
    this.events.publish<ImageGenerationProgressPayload>('image.generation.progress', payload);
    return this.cloneTask(task);
  }

  /**
   * 将任务标记为已完成，写入最终结果附件和元数据，并发布完成事件。
   * @param taskId 目标任务标识。
   * @param attachmentIds 生成结果的附件标识列表。
   * @param metadata 生成结果的元数据。
   * @returns 更新后的任务实例副本。
   */
  completeGeneration(taskId: string, attachmentIds: Array<string>, metadata: ImageGenerationMetadata): ImageGenerationTask {
    const task = this.requireTask(taskId);
    task.status = 'completed';
    task.progress = 100;
    task.resultAttachmentIds = attachmentIds.slice();
    task.metadata = this.cloneMetadata(metadata);
    task.updatedAt = Date.now();
    const payload: ImageGenerationCompletedPayload = { task: this.cloneTask(task) };
    this.events.publish<ImageGenerationCompletedPayload>('image.generation.completed', payload);
    return this.cloneTask(task);
  }

  /**
   * 将任务标记为失败，记录错误原因并发布失败事件。
   * @param taskId 目标任务标识。
   * @param error 失败原因描述。
   * @returns 更新后的任务实例副本。
   */
  failGeneration(taskId: string, error: string): ImageGenerationTask {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    const payload: ImageGenerationFailedPayload = { task: this.cloneTask(task) };
    this.events.publish<ImageGenerationFailedPayload>('image.generation.failed', payload);
    return this.cloneTask(task);
  }

  /**
   * 取消指定生成任务，将状态置为已取消并发布取消事件。
   * @param taskId 目标任务标识。
   * @returns 更新后的任务实例副本。
   */
  cancelGeneration(taskId: string): ImageGenerationTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled';
    task.error = '已取消';
    task.updatedAt = Date.now();
    const payload: ImageGenerationCancelledPayload = { task: this.cloneTask(task) };
    this.events.publish<ImageGenerationCancelledPayload>('image.generation.cancelled', payload);
    return this.cloneTask(task);
  }

  /**
   * 查询指定任务，任务不存在时抛出异常。
   * @param taskId 目标任务标识。
   * @returns 任务实例副本，修改副本不影响内部状态。
   */
  getTask(taskId: string): ImageGenerationTask {
    return this.cloneTask(this.requireTask(taskId));
  }

  /**
   * 按状态筛选任务列表，不传状态则返回所有任务。
   * @param status 可选的目标状态筛选条件。
   * @returns 符合条件的任务列表，每个元素均为副本。
   */
  listTasks(status?: ImageGenerationStatus): Array<ImageGenerationTask> {
    const result = new Array<ImageGenerationTask>();
    const values = Array.from(this.tasks.values());
    for (let index = 0; index < values.length; index += 1) {
      if (status === undefined || values[index].status === status) {
        result.push(this.cloneTask(values[index]));
      }
    }
    return result;
  }

  /**
   * 移除已完成、失败或已取消的任务，释放内存占用。
   * @param taskId 待清理的任务标识。
   */
  cleanupTask(taskId: string): void {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      return;
    }
    if (task.status === 'completed' || task.status === 'failed' || task.status === 'cancelled') {
      this.tasks.delete(taskId);
    }
  }

  /**
   * 保存一组生成参数为预设，发布预设保存事件后返回预设副本。
   * @param name 预设显示名称。
   * @param params 要保存的生成参数。
   * @returns 创建的预设对象副本。
   */
  savePreset(name: string, params: ImageGenerationParams): ImageGenerationPreset {
    this.presetCounter += 1;
    // preset 标识。
    const presetId = `img-preset-${this.presetCounter}`;
    const now = Date.now();
    const preset: ImageGenerationPreset = {
      presetId: presetId,
      name: name,
      params: this.cloneParams(params),
      createdAt: now,
      updatedAt: now,
    };
    this.presets.set(presetId, this.clonePreset(preset));
    const payload: ImageGenerationPresetSavedPayload = { preset: this.clonePreset(preset) };
    this.events.publish<ImageGenerationPresetSavedPayload>('image.generation.preset.saved', payload);
    return this.clonePreset(preset);
  }

  /**
   * 加载指定预设中的生成参数。
   * @param presetId 目标预设标识。
   * @returns 预设中保存的生成参数副本。
   */
  loadPreset(presetId: string): ImageGenerationParams {
    const preset = this.requirePreset(presetId);
    return this.cloneParams(preset.params);
  }

  /**
   * 列出所有已保存的预设。
   * @returns 预设列表，每个元素均为副本。
   */
  listPresets(): Array<ImageGenerationPreset> {
    const result = new Array<ImageGenerationPreset>();
    const values = Array.from(this.presets.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.clonePreset(values[index]));
    }
    return result;
  }

  /**
   * 删除指定预设，若预设不存在则抛出异常。
   * @param presetId 目标预设标识。
   */
  deletePreset(presetId: string): void {
    this.requirePreset(presetId);
    this.presets.delete(presetId);
  }

  /**
   * 将通用图片生成参数转换为 SD WebUI API 请求格式。
   * @param params 通用图片生成参数。
   * @returns SD WebUI 兼容的请求体。
   */
  buildSdWebUIRequest(params: ImageGenerationParams): SdWebUIRequest {
    return {
      prompt: params.prompt,
      negative_prompt: params.negativePrompt,
      width: params.width,
      height: params.height,
      steps: params.steps,
      cfg_scale: params.cfg,
      seed: params.seed,
      sampler_name: params.sampler,
      batch_size: params.batchSize,
    };
  }

  /**
   * 将工作流和客户端标识组装为 ComfyUI API 请求格式。
   * @param workflow ComfyUI 工作流 JSON 对象。
   * @param clientId 客户端标识。
   * @returns ComfyUI 兼容的请求体。
   */
  buildComfyUIRequest(workflow: Object, clientId: string): ComfyUIRequest {
    return {
      workflow: workflow,
      client_id: clientId,
    };
  }

  /**
   * 将提示词和参数组装为 OpenAI 图像 API 请求格式。
   * @param prompt 图片描述提示词。
   * @param model 模型名称。
   * @param n 生成数量。
   * @param size 图片尺寸。
   * @returns OpenAI 兼容的请求体。
   */
  buildOpenAIImageRequest(prompt: string, model: string, n: number, size: string): OpenAIImageRequest {
    return {
      model: model,
      prompt: prompt,
      n: n,
      size: size,
      response_format: 'b64_json',
    };
  }

  /**
   * 将通用图片生成参数转换为 Workers AI API 请求格式。
   * @param params 通用图片生成参数。
   * @returns Workers AI 兼容的请求体。
   */
  buildWorkersAIRequest(params: ImageGenerationParams): WorkersAIRequest {
    return {
      prompt: params.prompt,
      negative_prompt: params.negativePrompt,
      width: params.width,
      height: params.height,
      num_steps: params.steps,
      guidance: params.cfg,
      seed: params.seed,
    };
  }

  /**
   * 导出当前所有任务和预设数据。
   * @returns 包含所有预设和任务的导出数据对象。
   */
  exportData(): ImageGenerationExportData {
    return {
      presets: this.listPresets(),
      tasks: this.listTasks(),
    };
  }

  /**
   * 导入外部数据，合并预设和任务到当前实例中。
   * @param data 包含预设和任务列表的待导入数据。
   */
  importData(data: ImageGenerationExportData): void {
    for (let index = 0; index < data.presets.length; index += 1) {
      const preset = this.clonePreset(data.presets[index]);
      this.presets.set(preset.presetId, preset);
      this.presetCounter = Math.max(this.presetCounter, this.parsePresetCounter(preset.presetId));
    }
    for (let index = 0; index < data.tasks.length; index += 1) {
      const task = this.cloneTask(data.tasks[index]);
      this.tasks.set(task.taskId, task);
      this.taskCounter = Math.max(this.taskCounter, this.parseTaskCounter(task.taskId));
    }
  }

  /**
   * 根据 taskId 查找任务，不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 内部存储的任务实例（直接引用，非副本）。
   */
  private requireTask(taskId: string): ImageGenerationTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`图片生成任务未找到: ${taskId}`);
    }
    return task;
  }

  /**
   * 根据 presetId 查找预设，不存在时抛出错误。
   * @param presetId 目标预设标识。
   * @returns 内部存储的预设实例（直接引用，非副本）。
   */
  private requirePreset(presetId: string): ImageGenerationPreset {
    const preset = this.presets.get(presetId);
    if (preset === undefined) {
      throw new Error(`图片生成预设未找到: ${presetId}`);
    }
    return preset;
  }

  /**
   * 深拷贝图片生成参数对象，防止外部修改内部状态。
   * @param params 待拷贝的参数对象。
   * @returns 参数对象的浅拷贝副本。
   */
  private cloneParams(params: ImageGenerationParams): ImageGenerationParams {
    return {
      backend: params.backend,
      prompt: params.prompt,
      negativePrompt: params.negativePrompt,
      width: params.width,
      height: params.height,
      steps: params.steps,
      cfg: params.cfg,
      seed: params.seed,
      sampler: params.sampler,
      batchSize: params.batchSize,
    };
  }

  /**
   * 深拷贝任务对象，防止外部修改内部状态。
   * @param task 待拷贝的任务对象。
   * @returns 任务对象的深拷贝副本。
   */
  private cloneTask(task: ImageGenerationTask): ImageGenerationTask {
    return {
      taskId: task.taskId,
      backend: task.backend,
      params: this.cloneParams(task.params),
      status: task.status,
      progress: task.progress,
      resultAttachmentIds: task.resultAttachmentIds.slice(),
      error: task.error,
      metadata: this.cloneMetadata(task.metadata),
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }

  /**
   * 深拷贝预设对象，防止外部修改内部状态。
   * @param preset 待拷贝的预设对象。
   * @returns 预设对象的深拷贝副本。
   */
  private clonePreset(preset: ImageGenerationPreset): ImageGenerationPreset {
    return {
      presetId: preset.presetId,
      name: preset.name,
      params: this.cloneParams(preset.params),
      createdAt: preset.createdAt,
      updatedAt: preset.updatedAt,
    };
  }

  /**
   * 深拷贝元数据对象，仅复制已定义的字段。
   * @param metadata 待拷贝的元数据对象。
   * @returns 元数据对象的浅拷贝副本。
   */
  private cloneMetadata(metadata: ImageGenerationMetadata): ImageGenerationMetadata {
    const result: ImageGenerationMetadata = {};
    if (metadata.model !== undefined) result.model = metadata.model;
    if (metadata.seed !== undefined) result.seed = metadata.seed;
    if (metadata.backendTaskId !== undefined) result.backendTaskId = metadata.backendTaskId;
    if (metadata.requestId !== undefined) result.requestId = metadata.requestId;
    return result;
  }

  /**
   * 从任务标识中解析数值计数器，非法格式返回 0。
   * @param taskId 格式如 "img-gen-{数字}" 的任务标识。
   * @returns 解析出的数值，非法输入返回 0。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('img-gen-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 从预设标识中解析数值计数器，非法格式返回 0。
   * @param presetId 格式如 "img-preset-{数字}" 的预设标识。
   * @returns 解析出的数值，非法输入返回 0。
   */
  private parsePresetCounter(presetId: string): number {
    if (!presetId.startsWith('img-preset-')) {
      return 0;
    }
    const parsed = Number(presetId.substring(11));
    return parsed > 0 ? parsed : 0;
  }
}
