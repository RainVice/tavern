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

export class ImageGenerationRuntime {
  private events: EventBus;
  private tasks: Map<string, ImageGenerationTask> = new Map<string, ImageGenerationTask>();
  private presets: Map<string, ImageGenerationPreset> = new Map<string, ImageGenerationPreset>();
  private taskCounter: number = 0;
  private presetCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

  // 发起图片生成
  generateImage(params: ImageGenerationParams): ImageGenerationTask {
    this.taskCounter += 1;
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

  // 更新任务进度
  updateProgress(taskId: string, progress: number): ImageGenerationTask {
    const task = this.requireTask(taskId);
    task.progress = Math.max(0, Math.min(100, progress));
    task.status = 'running';
    task.updatedAt = Date.now();
    const payload: ImageGenerationProgressPayload = { task: this.cloneTask(task) };
    this.events.publish<ImageGenerationProgressPayload>('image.generation.progress', payload);
    return this.cloneTask(task);
  }

  // 完成任务
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

  // 任务失败
  failGeneration(taskId: string, error: string): ImageGenerationTask {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    const payload: ImageGenerationFailedPayload = { task: this.cloneTask(task) };
    this.events.publish<ImageGenerationFailedPayload>('image.generation.failed', payload);
    return this.cloneTask(task);
  }

  // 取消生成
  cancelGeneration(taskId: string): ImageGenerationTask {
    const task = this.requireTask(taskId);
    task.status = 'cancelled';
    task.error = '已取消';
    task.updatedAt = Date.now();
    const payload: ImageGenerationCancelledPayload = { task: this.cloneTask(task) };
    this.events.publish<ImageGenerationCancelledPayload>('image.generation.cancelled', payload);
    return this.cloneTask(task);
  }

  // 获取单个任务
  getTask(taskId: string): ImageGenerationTask {
    return this.cloneTask(this.requireTask(taskId));
  }

  // 列出所有任务
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

  // 移除已完成/已失败/已取消的任务（清理）
  cleanupTask(taskId: string): void {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      return;
    }
    if (task.status === 'completed' || task.status === 'failed' || task.status === 'cancelled') {
      this.tasks.delete(taskId);
    }
  }

  // 保存预设
  savePreset(name: string, params: ImageGenerationParams): ImageGenerationPreset {
    this.presetCounter += 1;
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

  // 加载预设
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

  // 删除预设
  deletePreset(presetId: string): void {
    this.requirePreset(presetId);
    this.presets.delete(presetId);
  }

  // 构建 SD WebUI 请求体
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

  // 构建 ComfyUI 请求体
  buildComfyUIRequest(workflow: Object, clientId: string): ComfyUIRequest {
    return {
      workflow: workflow,
      client_id: clientId,
    };
  }

  // 构建 OpenAI 图片请求体
  buildOpenAIImageRequest(prompt: string, model: string, n: number, size: string): OpenAIImageRequest {
    return {
      model: model,
      prompt: prompt,
      n: n,
      size: size,
      response_format: 'b64_json',
    };
  }

  // 构建 Workers AI 请求体
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

  // 导入
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

  private requireTask(taskId: string): ImageGenerationTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`图片生成任务未找到: ${taskId}`);
    }
    return task;
  }

  private requirePreset(presetId: string): ImageGenerationPreset {
    const preset = this.presets.get(presetId);
    if (preset === undefined) {
      throw new Error(`图片生成预设未找到: ${presetId}`);
    }
    return preset;
  }

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

  private clonePreset(preset: ImageGenerationPreset): ImageGenerationPreset {
    return {
      presetId: preset.presetId,
      name: preset.name,
      params: this.cloneParams(preset.params),
      createdAt: preset.createdAt,
      updatedAt: preset.updatedAt,
    };
  }

  private cloneMetadata(metadata: ImageGenerationMetadata): ImageGenerationMetadata {
    const result: ImageGenerationMetadata = {};
    if (metadata.model !== undefined) result.model = metadata.model;
    if (metadata.seed !== undefined) result.seed = metadata.seed;
    if (metadata.backendTaskId !== undefined) result.backendTaskId = metadata.backendTaskId;
    if (metadata.requestId !== undefined) result.requestId = metadata.requestId;
    return result;
  }

  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('img-gen-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  private parsePresetCounter(presetId: string): number {
    if (!presetId.startsWith('img-preset-')) {
      return 0;
    }
    const parsed = Number(presetId.substring(11));
    return parsed > 0 ? parsed : 0;
  }
}
