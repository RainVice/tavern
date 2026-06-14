/**
 * 应用运行时模块。
 * 导出 AppRuntime 类，提供应用生命周期管理（启动、状态恢复、状态持久化）、manifest 与运行状态的读写能力，
 * 适用于需要在启动流程中初始化运行时配置、在运行过程中保存阶段信息及在状态恢复时还原上下文的应用场景。
 */
export { AppRuntime } from './AppRuntime';
export type {
  LifecycleStartupOptions,
  LifecycleStartupResult,
  RuntimeManifest,
  RuntimeStateRecord,
} from './AppModels';
