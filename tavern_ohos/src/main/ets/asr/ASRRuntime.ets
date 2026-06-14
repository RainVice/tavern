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
 * 提供语音转文字相关的无 UI 运行时能力，负责管理转录任务生命周期（启动、进度更新、完成、失败、取消）、
 * 通过事件总线向外部模块发布状态变化、以及支持任务数据的导入导出，
 * 用于在语音输入或音频文件处理流程中驱动语音识别服务。
 */
export class ASRRuntime {
  /**
   * 事件总线实例，用于在转录任务各生命周期阶段发布状态事件，供 UI、日志或其他 Runtime 模块监听响应。
   */
  private events: EventBus;
  /**
   * 内存中的 ASR 任务映射表，以 taskId 为键，用于在转录流程中快速存取和管理所有活跃任务记录。
   */
  private tasks: Map<string, ASRTask> = new Map<string, ASRTask>();
  /**
   * 自增计数器，用于在创建新转录任务时生成全局唯一的任务标识（asr-1、asr-2...）。
   */
  private taskCounter: number = 0;

  /**
   * 初始化当前运行时实例，在模块加载时调用，建立与事件总线的连接。
   * @param events 事件总线实例，用于在转录生命周期各阶段发布事件通知外部模块。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 启动一个新的转录任务，生成任务记录、存入内存映射表并发布开始事件，
   * 用于在用户触发语音识别时初始化任务并通知 UI 或下游模块开始处理。
   * @param params 转录参数，包含音频来源、提供商、语言等配置，用于在任务创建时确定转录方式和策略。
   * @returns 新创建的 ASRTask 记录副本。
   */
  startTranscription(params: ASRTranscriptionParams): ASRTask {
    this.taskCounter += 1;
    // 生成唯一任务标识
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
   * 更新转录进度百分比，将任务状态置为 running 并发布进度事件，
   * 用于在音频处理过程中由外部调用方向运行时报告当前处理进度。
   * @param taskId 目标任务唯一标识，用于在任务映射表中定位目标转录记录。
   * @param progress 新的进度值（0-100），会自动限制在有效区间内，由外部转录引擎调用方传入。
   * @returns 更新后的 ASRTask 记录副本。
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
   * 标记转录任务为完成状态，填入转录结果并发布完成事件，
   * 用于在转录引擎处理完毕后向运行时报告最终结果，触发自动发送或 UI 更新。
   * @param taskId 目标任务唯一标识，用于定位要完成的转录记录。
   * @param result 转录结果，包含文本、置信度和音频时长，由转录引擎返回后传入。
   * @returns 更新后的 ASRTask 记录副本。
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
   * 标记转录任务为失败状态，记录错误信息并发布失败事件，
   * 用于在转录引擎出错或被网络中断时通知运行时和外部模块。
   * @param taskId 目标任务唯一标识，用于定位失败的转录记录。
   * @param error 失败原因描述，由调用方或异常捕获逻辑传入，供诊断使用。
   * @returns 更新后的 ASRTask 记录副本。
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
   * 取消转录任务，设置状态为 cancelled 并发布取消事件，
   * 用于在用户主动中止语音输入或超时处理时中断任务并通知监听方。
   * @param taskId 目标任务唯一标识，用于定位要取消的转录记录。
   * @returns 更新后的 ASRTask 记录副本。
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
   * 根据 taskId 获取指定转录任务的副本，
   * 用于在外部模块或 UI 查询某个转录任务的当前状态和结果。
   * @param taskId 目标任务唯一标识，用于在任务映射表中检索。
   * @returns 任务的深拷贝副本。
   */
  getTask(taskId: string): ASRTask {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 根据任务状态筛选并返回转录任务列表（深拷贝副本），
   * 用于在 UI 或模块查询中按状态过滤正在运行、已完成或失败的任务。
   * @param status 可选的状态过滤条件，不传则返回所有任务，由调用方决定是否过滤。
   * @returns 符合条件的 ASRTask 深拷贝列表。
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
   * 根据入参构建 Whisper API 请求体，仅组装数据结构不发起网络请求，
   * 用于在转录流程中准备好发送给 OpenAI Whisper 服务的请求参数。
   * @param file 要转录的音频文件路径或数据，由调用方传入，用于 API 请求的音频字段。
   * @param model Whisper 模型名称，用于指定 API 请求使用的模型版本。
   * @param language 音频语言（可空），用于辅助 Whisper API 的语言检测。
   * @param prompt 辅助提示词，用于优化 Whisper API 的转录准确度。
   * @returns 构建好的 WhisperRequest 对象。
   */
  buildWhisperRequest(file: string, model: string, language: string, prompt: string): WhisperRequest {
    return { file: file, model: model, language: language, prompt: prompt, response_format: 'text' };
  }

  /**
   * 导出全部 ASR 任务数据，用于备份或数据迁移，
   * 在用户执行导出操作或 SillyTavern 数据互通时调用。
   * @returns 包含所有任务的导出数据结构。
   */
  exportData(): ASRExportData {
    return { tasks: this.listTasks() };
  }

  /**
   * 从外部数据导入 ASR 任务记录，用于数据恢复，
   * 在应用启动还原备份或从外部数据源同步 ASR 记录时调用。
   * @param data 包含转录任务列表的导出数据，由外部备份文件解析后传入。
   */
  importData(data: ASRExportData): void {
    for (let index = 0; index < data.tasks.length; index += 1) {
      const task = this.copyTask(data.tasks[index]);
      this.tasks.set(task.taskId, task);
      this.taskCounter = Math.max(this.taskCounter, this.parseTaskCounter(task.taskId));
    }
  }

  /**
   * 获取指定任务记录，任务不存在时抛出异常。
   * @param taskId 目标任务唯一标识。
   * @returns 任务记录（内部引用，非副本）。
   */
  private requireTask(taskId: string): ASRTask {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`ASR 任务未找到: ${taskId}`);
    }
    return task;
  }

  /**
   * 深拷贝 ASRTask 对象，防止外部代码直接修改内部状态。
   * @param task 要复制的任务对象。
   * @returns 深拷贝后的任务对象。
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
   * 深拷贝 ASRTranscriptionParams 对象，防止外部代码修改内部状态。
   * @param params 要复制的转录参数。
   * @returns 深拷贝后的参数对象。
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
   * 从任务标识中解析出自增计数器编号，用于导入时恢复计数器状态。
   * @param taskId 任务标识（格式为 asr-{数字}）。
   * @returns 解析出的计数器数值；解析失败返回 0。
   */
  private parseTaskCounter(taskId: string): number {
    if (!taskId.startsWith('asr-')) {
      return 0;
    }
    const parsed = Number(taskId.substring(4));
    return parsed > 0 ? parsed : 0;
  }
}
