/**
 * 生命周期模块 - 提供应用生命周期管理和启动流程编排能力。
 * 负责应用的初始化、迁移、恢复和就绪状态管理，并通过事件总线发布生命周期状态变更信号。
 * 在 Tavern 启动时由主入口调用 runStartup，按 init -> migrate -> restore -> ready 顺序执行各阶段。
 */
export { LifecycleRuntime } from './LifecycleRuntime';
