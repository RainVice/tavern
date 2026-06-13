import { EventBus } from './EventBus';

/**
 * 描述运行时基础设施持久化或内存索引中的一条记录。
 */
export interface TaskRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * type 值，由当前实例内部维护。
   */
  type: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: string;
  /**
   * progress 列表，由当前实例内部维护。
   */
  progress: number;
  /**
   * 消息数据。
   */
  message: string;
  /**
   * 处理结果。
   */
  result: string;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述运行时基础设施事件发布时携带的数据结构。
 */
export interface TaskUpdatePayload {
  /**
   * task 值，由当前实例内部维护。
   */
  task: TaskRecord;
}

/**
 * 提供运行时基础设施相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class TaskRuntime {
  /**
   * 事件总线。
   */
  private eventBus: EventBus;
  /**
   * tasks 列表，由当前实例内部维护。
   */
  private tasks: Map<string, TaskRecord> = new Map<string, TaskRecord>();
  /**
   * next 标识。
   */
  private nextId: number = 1;

  /**
   * 初始化当前运行时实例。
   * @param eventBus 事件总线。
   */
  constructor(eventBus: EventBus) {
    this.eventBus = eventBus;
  }

  /**
   * 创建新的任务记录，写入存储并返回副本。

   * @param title 标题。
   * @returns 更新或读取后的记录副本。
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
   * 更新指定任务，写回存储并按需发布变更事件。
   * @param taskId 目标任务标识。
   * @param status 状态值。

   * @param message 消息记录。
   * @returns 更新或读取后的记录副本。
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
   * 标记Task 值完成，并写入最终结果。
   * @param taskId 目标任务标识。
   * @param result 返回结果。
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
   * 标记Task 值失败，并保存错误信息。
   * @param taskId 目标任务标识。
   * @param error 错误信息。
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
   * 读取指定任务，不存在时抛出错误。
   * @param taskId 目标任务标识。
   * @returns 更新或读取后的记录副本。
   */
  getTask(taskId: string): TaskRecord {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 读取Tasks列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 读取必须存在的Task 值，缺失时抛出错误。
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
   * 发布运行时基础设施事件，把状态变化通知给宿主或其他 Runtime。

   */
  private publishUpdate(task: TaskRecord): void {
    const payload: TaskUpdatePayload = {
      task: this.copyTask(task),
    };
    this.eventBus.publish<TaskUpdatePayload>('task.updated', payload);
  }

  /**
   * 复制Task 值，避免外部修改内部状态。
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
