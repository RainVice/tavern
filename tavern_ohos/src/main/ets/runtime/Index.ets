/**
 * runtime 模块导出核心能力和类型。
 *
 * 提供运行时基础设施：事件总线（EventBus）、锁管理器（LockManager）、
 * 任务运行时（TaskRuntime）以及相关类型（EventSubscription、TaskRecord 等）。
 */
export { EventBus } from './EventBus';
export type { EventSubscription, RuntimeEvent, RuntimeEventHandler } from './EventBus';
export { LockManager } from './LockManager';
export type { LockLease, TryLockResult } from './LockManager';
export { TaskRuntime } from './TaskRuntime';
export type { TaskRecord, TaskUpdatePayload } from './TaskRuntime';
