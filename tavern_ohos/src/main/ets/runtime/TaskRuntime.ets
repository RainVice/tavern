import { EventBus } from './EventBus';

/**
 * 描述运行时基础设施持久化或内存索引中的一条记录。
 * 在任务管理流程中，用于追踪异步操作的进度和状态。
 */
export interface TaskRecord {
  /**
   * 任务唯一标识，由 createTask 自动生成（格式为 "task-{计数器}"）。
   */
  id: string;
  /**
   * 任务类型（如 "export" / "import" / "generation" 等），用于区分不同的任务类别。
   */
  type: string;
  /**
   * 任务标题，用于 UI 展示的任务名称。
   */
  title: string;
  /**
   * 任务状态（如 pending / running / completed / failed）。
   */
  status: string;
  /**
   * 进度百分比（0-100），由 updateTask 更新。
   */
  progress: number;
  /**
   * 消息内容，用于 UI 展示任务的当前状态描述。
   */
  message: string;
  /**
   * 任务结果，由 completeTask 在完成后写入。
   */
  result: string;
  /**
   * 错误信息，由 failTask 在失败时记录。
   */
  error: string;
  /**
   * 创建时间戳。
   */
  createdAt: number;
  /**
   * 最近更新时间戳。
   */
  updatedAt: number;
}

/**
 * 描述任务更新事件发布时携带的数据结构。
 * TaskRuntime 在任务状态变更时发布 task.updated 事件，通知宿主 UI 更新任务展示。
 */
export interface TaskUpdatePayload {
  /**
   * 已更新的任务记录。
   */
  task: TaskRecord;
}

/**
 * 提供任务管理相关的运行时能力，负责任务状态管理、进度跟踪和事件发布。
 * 在需要追踪长时间运行的后台操作（如数据导入/导出、批量处理等）时使用。
 */
export class TaskRuntime {
  /**
   * 事件总线实例，用于发布任务更新事件。
   */
  private eventBus: EventBus;
  /**
   * 按 ID 保存的任务映射表。
   */
  private tasks: Map<string, TaskRecord> = new Map<string, TaskRecord>();
  /**
   * 任务自增 ID 计数器。
   */
  private nextId: number = 1;

  /**
   * 初始化 TaskRuntime 实例。
   * @param eventBus 事件总线实例。
   */
  constructor(eventBus: EventBus) {
    this.eventBus = eventBus;
  }

  /**
   * 创建新任务。
   * 在后台操作开始时由调用方（如导入/导出流程）调用，用于初始化任务记录。
   * @param type 任务类型。
   * @param title 任务标题。
   * @returns 新建的任务记录。
   */
  createTask(type: string, title: string): TaskRecord {
    const now = Date.now();
    const task: TaskRecord = {
      id: `task-${this.nextId}`,
      type: type,
      title: title,
      status: 'pending',
      progress: 0,
      message: '',
      result: '',
      error: '',
      createdAt: now,
      updatedAt: now,
    };
    this.nextId += 1;
    this.tasks.set(task.id, this.copyTask(task));
    this.publishUpdate(task);
    return this.copyTask(task);
  }

  /**
   * 更新任务状态、进度和消息。
   * 在任务执行过程中由调用方定期调用，用于向宿主 UI 报告最新进度。
   * @param taskId 目标任务标识。
   * @param status 新状态。
   * @param progress 进度值（0-100）。
   * @param message 消息内容。
   * @returns 更新后的任务记录。
   */
  updateTask(taskId: string, status: string, progress: number, message: string): TaskRecord {
    const task = this.requireTask(taskId);
    task.status = status;
    task.progress = this.clampProgress(progress);
    task.message = message;
    task.updatedAt = Date.now();
    this.publishUpdate(task);
    return this.copyTask(task);
  }

  /**
   * 标记任务为完成并写入结果。
   * 在后台操作成功结束时由调用方调用。
   * @param taskId 目标任务标识。
   * @param result 任务结果。
   */
  completeTask(taskId: string, result: string): TaskRecord {
    const task = this.requireTask(taskId);
    task.status = 'completed';
    task.progress = 100;
    task.result = result;
    task.error = '';
    task.updatedAt = Date.now();
    this.publishUpdate(task);
    return this.copyTask(task);
  }

  /**
   * 标记任务为失败并记录错误信息。
   * 在后台操作失败时由调用方调用。
   * @param taskId 目标任务标识。
   * @param error 错误描述。
   */
  failTask(taskId: string, error: string): TaskRecord {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    this.publishUpdate(task);
    return this.copyTask(task);
  }

  /**
   * 获取指定任务记录。
   * @param taskId 目标任务标识。
   * @returns 任务记录副本。
   */
  getTask(taskId: string): TaskRecord {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 列出所有任务记录。
   * @returns 任务记录副本数组。
   */
  listTasks(): Array<TaskRecord> {
    const result = new Array<TaskRecord>();
    const values = Array.from(this.tasks.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyTask(values[index]));
    }
    return result;
  }

  /**
   * 确保指定任务存在，缺失时抛出错误。
   * @param taskId 目标任务标识。
   */
  private requireTask(taskId: string): TaskRecord {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`Task not found: ${taskId}`);
    }
    return task;
  }

  /**
   * 发布任务更新事件通知宿主或其他 Runtime。
   */
  private publishUpdate(task: TaskRecord): void {
    const payload: TaskUpdatePayload = {
      task: this.copyTask(task),
    };
    this.eventBus.publish<TaskUpdatePayload>('task.updated', payload);
  }

  /**
   * 深度复制 TaskRecord，防止外部代码修改内部状态。
   */
  private copyTask(task: TaskRecord): TaskRecord {
    return {
      id: task.id,
      type: task.type,
      title: task.title,
      status: task.status,
      progress: task.progress,
      message: task.message,
      result: task.result,
      error: task.error,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }
  private clampProgress(progress: number): number {
    if (progress < 0) {
      return 0;
    }
    if (progress > 100) {
      return 100;
    }
    return progress;
  }
}
