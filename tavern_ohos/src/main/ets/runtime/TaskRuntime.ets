import { EventBus } from './EventBus';
import type {
  RuntimeTaskStatus,
  RuntimeTaskType,
} from '../contracts/PublicContracts';

/**
 * 运行时任务记录。描述一个异步任务在内存中的完整状态，包括进度、消息、结果和错误信息。
 */
export interface TaskRecord {
  /**
   * 任务唯一标识。
   */
  id: string;
  /**
   * 任务类型，由创建方指定。描述该任务所属的功能类别。
   */
  type: RuntimeTaskType;
  /**
   * 任务标题，用于在 UI 上显示说明文字。
   */
  title: string;
  /**
   * 任务当前状态。生命周期：pending -> running -> completed/failed/cancelled/aborted。
   */
  status: RuntimeTaskStatus;
  /**
   * 任务进度百分比，0-100 之间的整数。
   */
  progress: number;
  /**
   * 任务消息，用于在 UI 上展示处理过程中的文字描述。
   */
  message: string;
  /**
   * 任务最终处理结果。仅 completed 状态时有意义。
   */
  result: string;
  /**
   * 错误信息。仅 failed 状态时有意义。
   */
  error: string;
  /**
   * 任务创建时间戳，单位为毫秒。
   */
  createdAt: number;
  /**
   * 任务最近一次更新时间戳，单位为毫秒。
   */
  updatedAt: number;
}

/**
 * 任务更新事件发布时携带的数据结构。
 */
export interface TaskUpdatePayload {
  /**
   * 变更后的任务记录快照。
   */
  task: TaskRecord;
}

/**
 * TaskRuntime 是运行时无 UI 的任务管理器，负责异步任务的创建、状态更新、完成与失败标记，
 * 并通过 EventBus 发布变更事件通知宿主或其它 Runtime 模块。
 */
export class TaskRuntime {
  /**
   * 事件总线，用于发布任务变更通知。
   */
  private eventBus: EventBus;
  /**
   * 内存中所有任务记录的索引，键为任务 ID，值为 TaskRecord。
   */
  private tasks: Map<string, TaskRecord> = new Map<string, TaskRecord>();
  /**
   * 自增序号，用于生成下一个任务 ID。
   */
  private nextId: number = 1;

  /**
   * @param eventBus 事件总线，用于发布任务变更事件。
   */
  constructor(eventBus: EventBus) {
    this.eventBus = eventBus;
  }

  /**
   * 创建一条新的任务记录，写入内存索引并通过 EventBus 发布 task.updated 事件。
   * @param title 任务标题，用于在 UI 上展示任务说明。
   * @returns 新创建的任务记录副本。
   */
  createTask(type: RuntimeTaskType, title: string): TaskRecord {
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
   * 更新指定任务的状态、进度和消息，并发布 task.updated 事件。
   * @param taskId 目标任务 ID。
   * @param status 任务新状态。
   * @param message 任务消息，用于在 UI 上展示处理过程中的文字说明。
   * @returns 更新后的任务记录副本。
   */
  updateTask(taskId: string, status: RuntimeTaskStatus, progress: number, message: string): TaskRecord {
    const task = this.requireTask(taskId);
    task.status = status;
    task.progress = this.clampProgress(progress);
    task.message = message;
    task.updatedAt = Date.now();
    this.publishUpdate(task);
    return this.copyTask(task);
  }

  /**
   * 将任务标记为 completed，写入最终结果并发布更新事件。
   * @param taskId 目标任务 ID。
   * @param result 任务最终处理结果。
   * @returns 更新后的任务记录副本。
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
   * 将任务标记为 failed，保存错误信息并发布更新事件。
   * @param taskId 目标任务 ID。
   * @param error 错误描述。
   * @returns 更新后的任务记录副本。
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
   * 按 ID 读取指定任务的副本。
   * @param taskId 目标任务 ID。
   * @returns 任务记录的深度副本。调用方修改返回值不会影响内部状态。
   */
  getTask(taskId: string): TaskRecord {
    return this.copyTask(this.requireTask(taskId));
  }

  /**
   * 返回所有任务记录的副本列表。调用方修改返回值不会影响内部状态。
   * @returns 所有任务记录的副本数组。
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
   * 按 ID 查找任务，不存在时抛出 Error。
   * @param taskId 目标任务 ID。
   * @returns 任务记录（内部引用，调用方不应直接修改）。
   */
  private requireTask(taskId: string): TaskRecord {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`Task not found: ${taskId}`);
    }
    return task;
  }

  /**
   * 发布 task.updated 事件，将任务变更通知给 EventBus 的订阅者。
   * 发送的是任务的副本，订阅者修改不会影响内部状态。
   */
  private publishUpdate(task: TaskRecord): void {
    const payload: TaskUpdatePayload = {
      task: this.copyTask(task),
    };
    this.eventBus.publish<TaskUpdatePayload>('task.updated', payload);
  }

  /**
   * 浅拷贝 TaskRecord，防止外部代码直接修改内部状态。
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

  /**
   * 将进度百分比限制在 0-100 范围内。
   */
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
