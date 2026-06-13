import { EventBus } from './EventBus';

export interface TaskRecord {
  id: string;
  type: string;
  title: string;
  status: string;
  progress: number;
  message: string;
  result: string;
  error: string;
  createdAt: number;
  updatedAt: number;
}

export interface TaskUpdatePayload {
  task: TaskRecord;
}

export class TaskRuntime {
  private eventBus: EventBus;
  private tasks: Map<string, TaskRecord> = new Map<string, TaskRecord>();
  private nextId: number = 1;

  constructor(eventBus: EventBus) {
    this.eventBus = eventBus;
  }

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

  updateTask(taskId: string, status: string, progress: number, message: string): TaskRecord {
    const task = this.requireTask(taskId);
    task.status = status;
    task.progress = this.clampProgress(progress);
    task.message = message;
    task.updatedAt = Date.now();
    this.publishUpdate(task);
    return this.copyTask(task);
  }

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

  failTask(taskId: string, error: string): TaskRecord {
    const task = this.requireTask(taskId);
    task.status = 'failed';
    task.error = error;
    task.updatedAt = Date.now();
    this.publishUpdate(task);
    return this.copyTask(task);
  }

  getTask(taskId: string): TaskRecord {
    return this.copyTask(this.requireTask(taskId));
  }

  listTasks(): Array<TaskRecord> {
    const result = new Array<TaskRecord>();
    const values = Array.from(this.tasks.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyTask(values[index]));
    }
    return result;
  }

  private requireTask(taskId: string): TaskRecord {
    const task = this.tasks.get(taskId);
    if (task === undefined) {
      throw new Error(`Task not found: ${taskId}`);
    }
    return task;
  }

  private publishUpdate(task: TaskRecord): void {
    const payload: TaskUpdatePayload = {
      task: this.copyTask(task),
    };
    this.eventBus.publish<TaskUpdatePayload>('task.updated', payload);
  }

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
