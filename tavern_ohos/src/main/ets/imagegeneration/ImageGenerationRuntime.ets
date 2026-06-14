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
 * 管理图片生成任务从创建到完成的完整生命周期，支持 SD WebUI、ComfyUI、OpenAI Image、Workers AI 等多种后端。
 * 外部调用方（如生成面板 UI、预设管理、备份导入导出）通过此类完成图片生成操作。
 */
export class ImageGenerationRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 内存中的生成任务缓存，以任务 ID 为键。
   */
  private tasks: Map<string, ImageGenerationTask> = new Map<string, ImageGenerationTask>();
  /**
   * 内存中的生成预设缓存，以预设 ID 为键。
   */
  private presets: Map<string, ImageGenerationPreset> = new Map<string, ImageGenerationPreset>();
  /**
   * 自增任务计数器，用于生成唯一任务 ID。
   */
  private taskCounter: number = 0;
  /**
   * 自增预设计数器，用于生成唯一预设 ID。
   */
  private presetCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * 在应用启动时由更高层运行时容器调用，为图片生成功能注入事件基础设施。
   * @param events 事件总线，用于发布生成任务的启动/进度/完成/失败/取消事件，以及预设保存事件，驱动 UI 层展示任务状态和预设列表变化。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建并启动一个新的图片生成任务，记录初始 pending 状态并发布启动事件。
   * 由 UI 层（如生成面板的"生成"按钮）调用，根据传入的参数创建工作流追踪记录。
   * @param params 生成参数，包括后端类型、提示词、尺寸、步数、种子等，用于创建 ImageGenerationTask 和后续构建后端 API 请求。
   * @returns 创建后的生成任务对象副本，调用方可据此跟踪任务 ID 和初始状态。
   */
  generateImage(params: ImageGenerationParams): ImageGenerationTask {
    this.taskCounter += 1;
    // 生成唯一任务 ID，格式：img-gen-{自增序号}
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
   * 更新生成任务进度百分比，将状态切换为 running 并发布进度事件。
   * 由执行生成任务的异步流程（如轮询后端生成进度）调用，驱动 UI 层展示实时进度。
   * @param taskId 目标任务标识，用于在内存索引 tasks Map 中定位目标 ImageGenerationTask。
   * @param progress 当前进度值（0-100），会裁剪到合法范围再赋值。
   * @returns 更新后的生成任务对象副本。
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
   * 将指定任务标记为已完成，写入生成结果附件 ID 和元数据，并发布完成事件。
   * 由后端 API 调用方在成功获取生成结果后调用，通知 UI 层展示生成的图片。
   * @param taskId 目标任务标识，用于在内存索引中定位目标 ImageGenerationTask。
   * @param attachmentIds 生成结果图片的附件 ID 列表，来自后端响应解析后创建的附件记录。
   * @param metadata 生成结果的元数据，包含模型、种子等信息，来自后端 API 响应。
   * @returns 更新后的生成任务对象副本。
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
   * 将指定任务标记为失败，记录错误信息并发布失败事件。
   * 由后端 API 调用方在请求出错或响应异常后调用，通知 UI 层显示错误提示。
   * @param taskId 目标任务标识，用于在内存索引中定位目标 ImageGenerationTask。
   * @param error 失败原因描述，来自捕获的异常或 API 错误消息。
   * @returns 更新后的生成任务对象副本。
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
   * 取消指定生成任务，将状态设为 cancelled 并发布取消事件。
   * 由 UI 层（如用户点击"取消"按钮）调用，终止正在运行或未开始的生成任务，并通知外部订阅者。
   * @param taskId 目标任务标识，用于在内存索引中定位目标 ImageGenerationTask。
   * @returns 更新后的生成任务对象副本。
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
   * 根据任务 ID 获取生成任务副本，不存在时抛出异常。
   * 由 UI 层或外部模块在需要查询特定任务状态时调用，如生成面板的状态展示。
   * @param taskId 目标任务标识，用于在内存索引 tasks Map 中查找。
   * @returns 任务对象的深拷贝副本。
   */
  getTask(taskId: string): ImageGenerationTask {
    return this.cloneTask(this.requireTask(taskId));
  }

  /**
   * 按状态筛选列出生成任务，不传状态则返回全部任务。
   * 由需要展示任务列表的 UI（如生成历史面板）或备份导出流程调用。
   * @param status 可选的任务状态过滤条件，如 'completed'、'failed' 等，用于筛选特定生命周期的任务。
   * @returns 符合条件的任务对象深拷贝列表。
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
   * 移除已完成、已失败或已取消的生成任务，用于清理任务列表。
   * 由 UI 层（如用户点击"清除已完成"按钮）或自动清理逻辑调用，释放内存索引中的过期任务。
   * @param taskId 要清理的任务标识，仅在状态为 completed/failed/cancelled 时才会被删除。
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
   * 保存当前生成参数为预设，生成唯一预设 ID 并发布预设保存事件。
   * 由 UI 层（如用户点击"保存预设"按钮）调用，将当前生成配置保存以便后续复用。
   * @param name 预设显示名称，用于在预设列表中识别和选择。
   * @param params 要保存的生成参数，包含完整的生成配置。
   * @returns 创建后的预设对象副本。
   */
  savePreset(name: string, params: ImageGenerationParams): ImageGenerationPreset {
    this.presetCounter += 1;
    // 生成唯一预设 ID，格式：img-preset-{自增序号}
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
   * 根据预设 ID 加载预设中保存的生成参数。
   * 由 UI 层（如用户选择预设时）调用，将预设参数回填到生成面板的表单中。
   * @param presetId 目标预设标识，用于在内存索引 presets Map 中查找预设。
   * @returns 预设中保存的生成参数副本。
   */
  loadPreset(presetId: string): ImageGenerationParams {
    const preset = this.requirePreset(presetId);
    return this.cloneParams(preset.params);
  }

  // 列出所有预设，由 UI 层预设选择面板或备份导出流程调用
  listPresets(): Array<ImageGenerationPreset> {
    const result = new Array<ImageGenerationPreset>();
    const values = Array.from(this.presets.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.clonePreset(values[index]));
    }
    return result;
  }

  /**
   * 删除指定预设。
   * 由 UI 层（如用户点击"删除预设"按钮）调用，从内存索引中移除预设记录。
   * @param presetId 要删除的目标预设标识，用于在内存索引 presets Map 中定位和删除。
   */
  deletePreset(presetId: string): void {
    this.requirePreset(presetId);
    this.presets.delete(presetId);
  }

  /**
   * 将运行时参数转换为 SD WebUI API 请求格式。
   * 由执行生成任务的异步流程在选择 sd_webui 后端时调用，将 ImageGenerationParams 映射为 SD WebUI 的 API 请求体。
   * @param params 运行时生成参数，包含提示词、尺寸、采样参数等。
   * @returns 适用于 SD WebUI API 的请求体，可直接用于 HTTP POST 请求。
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
   * 将工作流和客户端 ID 打包为 ComfyUI API 请求格式。
   * 由执行生成任务的异步流程在选择 comfyui 后端时调用，组装 ComfyUI 的工作流请求体。
   * @param workflow ComfyUI 工作流 JSON 对象，定义了图片生成的节点图结构和参数。
   * @param clientId ComfyUI 客户端标识，用于服务端追踪和管理 WebSocket 连接。
   * @returns 适用于 ComfyUI API 的请求体，可直接用于 WebSocket 通信或 HTTP 请求。
   */
  buildComfyUIRequest(workflow: Object, clientId: string): ComfyUIRequest {
    return {
      workflow: workflow,
      client_id: clientId,
    };
  }

  /**
   * 将提示词和模型等参数转换为 OpenAI Image API 请求格式。
   * 由执行生成任务的异步流程在选择 openai_image 后端时调用，组装 OpenAI DALL-E 的 API 请求体。
   * @param prompt 正向提示词，用于描述期望生成的图片内容。
   * @param model 模型名称，如 dall-e-3。
   * @param n 生成图片数量。
   * @param size 图片尺寸，如 1024x1024，遵循 OpenAI Image API 的 size 参数格式。
   * @returns 适用于 OpenAI Image API 的请求体。
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
   * 将运行时生成参数转换为 Cloudflare Workers AI API 请求格式。
   * 由执行生成任务的异步流程在选择 workers_ai 后端时调用，映射为 Workers AI 的 API 请求体。
   * @param params 运行时生成参数，包含提示词、尺寸、采样参数等。
   * @returns 适用于 Workers AI API 的请求体。
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

  // 导出所有预设和任务数据，用于备份或迁移，由备份/恢复流程或数据迁移功能调用
  exportData(): ImageGenerationExportData {
    return {
      presets: this.listPresets(),
      tasks: this.listTasks(),
    };
  }

  /**
   * 从外部数据导入所有预设和任务记录，恢复运行时状态。
   * 由备份/恢复流程在应用启动时或导入操作时调用，将导出的预设和任务数据回填到内存索引中。
   * @param data 包含预设和任务列表的导入数据，用于恢复运行时状态。
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
   * 根据任务 ID 查找生成任务，不存在时抛出异常。
   * @param taskId 目标任务标识。
   * @returns 匹配的生成任务对象。
   */
  private requireTask(taskId: string): ImageGenerationTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`图片生成任务未找到: ${taskId}`);
    }
    return task;
  }

  /**
   * 根据预设 ID 查找预设，不存在时抛出异常。
   * @param presetId 目标预设标识。
   * @returns 匹配的预设对象。
   */
  private requirePreset(presetId: string): ImageGenerationPreset {
    const preset = this.presets.get(presetId);
    if (preset === undefined) {
      throw new Error(`图片生成预设未找到: ${presetId}`);
    }
    return preset;
  }

  /**
   * 深拷贝生成参数，防止外部修改影响内部状态。
   * @param params 原始生成参数。
   * @returns 字段值完全一致的独立副本。
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
   * 深拷贝生成任务，防止外部修改影响内部状态。
   * @param task 原始任务对象。
   * @returns 字段值完全一致的独立副本。
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
   * 深拷贝生成预设，防止外部修改影响内部状态。
   * @param preset 原始预设对象。
   * @returns 字段值完全一致的独立副本。
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
   * 深拷贝生成元数据，只拷贝已定义的字段。
   * @param metadata 原始元数据对象。
   * @returns 字段值完全一致的独立副本。
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
   * 从任务 ID 中解析出自增序号，用于恢复 taskCounter。
   * @param taskId 生成任务标识，格式为 img-gen-{数字}。
   * @returns 解析出的序号值，解析失败时返回 0。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('img-gen-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 从预设 ID 中解析出自增序号，用于恢复 presetCounter。
   * @param presetId 生成预设标识，格式为 img-preset-{数字}。
   * @returns 解析出的序号值，解析失败时返回 0。
   */
  private parsePresetCounter(presetId: string): number {
    if (!presetId.startsWith('img-preset-')) {
      return 0;
    }
    const parsed = Number(presetId.substring(11));
    return parsed > 0 ? parsed : 0;
  }
}
