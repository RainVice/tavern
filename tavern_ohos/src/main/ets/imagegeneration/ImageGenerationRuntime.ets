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
   * 事件总线。
   */
  private events: EventBus;
  /**
   * tasks 列表，由当前实例内部维护。
   */
  private tasks: Map<string, ImageGenerationTask> = new Map<string, ImageGenerationTask>();
  /**
   * presets 列表，由当前实例内部维护。
   */
  private presets: Map<string, ImageGenerationPreset> = new Map<string, ImageGenerationPreset>();
  /**
   * task Counter 值，由当前实例内部维护。
   */
  private taskCounter: number = 0;
  /**
   * preset Counter 值，由当前实例内部维护。
   */
  private presetCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 执行 generateImage 的内部处理步骤，供当前模块复用。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 更新Progress 列表，同步内部状态并按需发布变更事件。
   * @param taskId 目标任务标识。

   * @returns 更新或读取后的记录副本。
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
   * 标记Generation 值完成，并写入最终结果。
   * @param taskId 目标任务标识。
   * @param attachmentIds 目标附件标识列表。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 标记Generation 值失败，并保存错误信息。
   * @param taskId 目标任务标识。
   * @param error 错误信息。
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
   * 取消Generation 值任务，并发布取消状态。
   * @param taskId 目标任务标识。
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
   * 读取指定任务，不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 更新或读取后的记录副本。
   */
  getTask(taskId: string): ImageGenerationTask {
    return this.cloneTask(this.requireTask(taskId));
  }

  /**
   * 读取Tasks列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param status 状态值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 移除已完成/已失败/已取消的任务（清理）。
   * @param taskId 任务标识。
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
   * 创建或写入预设，完成持久化后返回可供调用方使用的结果。
   * @param name 显示名称或注册名称。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 读取或解析预设，调用方应处理不存在或不匹配的情况。
   * @param presetId 目标预设标识。
   */
  loadPreset(presetId: string): ImageGenerationParams {
    const preset = this.requirePreset(presetId);
    return this.cloneParams(preset.params);
  }

  // 列出所有预设
  listPresets(): Array<ImageGenerationPreset> {
    const result = new Array<ImageGenerationPreset>();
    const values = Array.from(this.presets.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.clonePreset(values[index]));
    }
    return result;
  }

  /**
   * 删除预设。
   * @param presetId 目标预设标识。
   */
  deletePreset(presetId: string): void {
    this.requirePreset(presetId);
    this.presets.delete(presetId);
  }

  /**
   * 根据入参构建Sd Web UIRequest 值，仅生成数据结构，不直接执行外部请求。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 构建好的请求、Prompt 或中间数据。
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
   * 根据入参构建Comfy UIRequest 值，仅生成数据结构，不直接执行外部请求。

   * @param clientId 目标客户端标识。
   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildComfyUIRequest(workflow: Object, clientId: string): ComfyUIRequest {
    return {
      workflow: workflow,
      client_id: clientId,
    };
  }

  /**
   * 根据入参构建Open AIImage Request 值，仅生成数据结构，不直接执行外部请求。

   * @param model 模型名称。


   * @returns 构建好的请求、Prompt 或中间数据。
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
   * 根据入参构建Workers AIRequest 值，仅生成数据结构，不直接执行外部请求。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 构建好的请求、Prompt 或中间数据。
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

  // 导出
  exportData(): ImageGenerationExportData {
    return {
      presets: this.listPresets(),
      tasks: this.listTasks(),
    };
  }

  /**
   * 导入。
   * @param data 数据内容。
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
   * 读取必须存在的Task 值，缺失时抛出错误。
   * @param taskId 目标任务标识。
   */
  private requireTask(taskId: string): ImageGenerationTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`图片生成任务未找到: ${taskId}`);
    }
    return task;
  }

  /**
   * 读取必须存在的Preset 值，缺失时抛出错误。
   * @param presetId 目标预设标识。
   */
  private requirePreset(presetId: string): ImageGenerationPreset {
    const preset = this.presets.get(presetId);
    if (preset === undefined) {
      throw new Error(`图片生成预设未找到: ${presetId}`);
    }
    return preset;
  }

  /**
   * 复制Params 列表，避免外部修改内部状态。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 复制Task 值，避免外部修改内部状态。
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
   * 复制Preset 值，避免外部修改内部状态。
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
   * 复制Metadata 值，避免外部修改内部状态。
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
   * 解析TaskCounter，非法输入会返回失败标记或空结果。
   * @param taskId 目标任务标识。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('img-gen-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 解析PresetCounter，非法输入会返回失败标记或空结果。
   * @param presetId 目标预设标识。
   */
  private parsePresetCounter(presetId: string): number {
    if (!presetId.startsWith('img-preset-')) {
      return 0;
    }
    const parsed = Number(presetId.substring(11));
    return parsed > 0 ? parsed : 0;
  }
}
