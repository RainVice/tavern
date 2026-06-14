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
 * 提供语音转文字（ASR）相关的无 UI 运行时能力。
 *
 * 职责范围：
 * - 管理 ASR 转录任务的创建、进度更新、完成、失败和取消等完整生命周期
 * - 通过事件总线发布各阶段事件，供 UI 层或其他模块监听
 * - 构建发送至 OpenAI Whisper API 的请求数据
 * - 支持 ASR 任务数据的导出与导入，用于状态恢复或数据迁移
 */
export class ASRRuntime {
  /**
   * 事件总线实例，用于发布 asr.transcription.{started,progress,completed,failed,cancelled} 事件。
   */
  private events: EventBus;
  /**
   * 全部 ASR 任务的有序映射，以 taskId 为键。
   * 任务在 startTranscription 时加入，可通过导入恢复。
   */
  private tasks: Map<string, ASRTask> = new Map<string, ASRTask>();
  /**
   * 自增计数器，用于生成唯一 taskId（格式 "asr-{counter}"）。
   */
  private taskCounter: number = 0;

  /**
   * 初始化当前 ASR 运行时实例。
   * 将事件总线引用保存在内部，后续所有事件发布通过此实例完成。
   * @param events 外部传入的事件总线实例，用于发布 ASR 各阶段事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 发起一次新的 ASR 转录任务。
   *
   * 创建任务记录并加入内部映射，状态初始化为 pending。
   * 随后立即发布 asr.transcription.started 事件以通知监听方。
   * 调用方获得任务副本，后续可通过 updateProgress、completeTranscription
   * 等方法推进任务状态。
   *
   * @param params 转录参数，包括音频来源、提供商、语言、模型等信息。
   * @returns 新建任务的不可变副本。
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
   * 更新指定任务的转录进度。
   *
   * 将进度值限制在 0-100 范围内，同时将任务状态改为 running。
   * 每次调用均会发布 asr.transcription.progress 事件，
   * 供 UI 进度条等组件实时刷新。
   *
   * @param taskId 目标任务标识。
   * @param progress 新进度值（0-100），超出范围的值会被自动截断。
   * @returns 更新后的任务副本。
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
   * 标记指定 ASR 任务为完成状态。
   *
   * 将进度设为 100，写入最终转录文本、置信度和音频时长。
   * 发布 asr.transcription.completed 事件，通知 UI 显示转写结果。
   *
   * @param taskId 目标任务标识。
   * @param result 转录完成结果，包含文本、置信度、时长等信息。
   * @returns 已完成状态的任务副本。
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
   * 标记指定 ASR 任务为失败状态。
   *
   * 保存错误描述信息，供后续排查或重试参考。
   * 发布 asr.transcription.failed 事件，通知 UI 显示错误状态。
   *
   * @param taskId 目标任务标识。
   * @param error 失败原因的描述文本。
   * @returns 失败状态的任务副本。
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
   * 取消指定的 ASR 转录任务。
   *
   * 将任务状态设为 cancelled，并记录 "已取消" 信息。
   * 发布 asr.transcription.cancelled 事件，通知 UI 同步取消状态。
   *
   * @param taskId 目标任务标识。
   * @returns 已取消状态的任务副本。
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
   * 获取指定任务的副本。
   *
   * 若任务不存在则抛出错误。返回的副本确保调用方对其修改不会影响内部状态。
   *
   * @param taskId 目标任务标识。
   * @returns 任务的不可变副本。
   */
  getTask(taskId: string): ASRTask {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 按状态筛选当前所有 ASR 任务。
   *
   * 若不传 status 参数则返回全部任务。
   * 返回的每条记录均为副本，调用方对其修改不会影响内部状态。
   *
   * @param status 可选的状态过滤条件。
   * @returns 符合条件的任务副本列表。
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
   * 构建一次 OpenAI Whisper 的请求数据。
   *
   * 将传入的音频文件路径、模型名称、语言和提示词组装为
   * WhisperRequest 结构体。该方法仅生成数据，不发起实际 HTTP 请求，
   * 上层调用方需自行处理网络调用。
   *
   * @param file 音频文件路径。
   * @param model Whisper 模型名称（如 whisper-1）。
   * @param language 音频语言代码（可选）。
   * @param prompt 提示词（可选）。
   * @returns 构建好的 Whisper 请求结构体。
   */
  buildWhisperRequest(file: string, model: string, language: string, prompt: string): WhisperRequest {
    return { file: file, model: model, language: language, prompt: prompt, response_format: 'text' };
  }

  /**
   * 导出当前所有 ASR 任务数据，用于持久化存储或状态恢复。
   *
   * @returns 包含全部任务列表的导出数据对象。
   */
  exportData(): ASRExportData {
    return { tasks: this.listTasks() };
  }

  /**
   * 导入历史 ASR 任务数据。
   *
   * 通常用于应用启动时从持久化存储恢复上一次会话的 ASR 任务记录。
   * 会自动更新 taskCounter 以防止新任务与导入任务产生 ID 冲突。
   *
   * @param data 待导入的任务数据对象。
   */
  importData(data: ASRExportData): void {
    for (let index = 0; index < data.tasks.length; index += 1) {
      const task = this.copyTask(data.tasks[index]);
      this.tasks.set(task.taskId, task);
      this.taskCounter = Math.max(this.taskCounter, this.parseTaskCounter(task.taskId));
    }
  }

  /**
   * 获取指定任务，若不存在则抛出 ASR 任务未找到错误。
   * 返回的是内部引用而非副本，仅供本类内部方法使用。
   *
   * @param taskId 目标任务标识。
   * @returns 任务内部引用，可直接修改其字段。
   */
  private requireTask(taskId: string): ASRTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`ASR 任务未找到: ${taskId}`);
    }
    return task;
  }

  /**
   * 深拷贝一个 ASRTask 对象，确保外部调用方无法通过返回值修改内部状态。
   * 参数对象中的 params 也会通过 copyParams 额外拷贝。
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
   * 深拷贝一个 ASRTranscriptionParams 对象，避免外部修改影响内部状态。
   *
   * @param params 源参数对象。
   * @returns 新创建的参数副本。
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
   * 从 taskId 中解析出自增计数器值。
   *
   * taskId 格式为 "asr-{数字}"，该方法提取数字部分并返回。
   * 若格式非法则返回 0，用于 importData 时恢复 taskCounter 到合理值。
   *
   * @param taskId 目标任务标识。
   * @returns 解析出的计数器值，非法格式返回 0。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('asr-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(4));
    return parsed > 0 ? parsed : 0;
  }
}
