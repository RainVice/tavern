/**
 * 模块内使用的数据结构，包含 AppRuntime 模块在运行时持久化交换的完整配置信息。
 */
export interface RuntimeManifest {
  /**
   * 数据 schema 版本号，用于向后兼容判断。初始化时首次写入，版本升级时递增。
   */
  schemaVersion: number;
  /**
   * 当前运行的运行时标识名，例如 "tavern_ohos"。在首次初始化时写入，后续保持不变。
   */
  runtime: string;
  /**
   * 全局模式开关，控制应用是否以全局/多用户模式运行。在 saveManifest 调用时由调用方指定。
   */
  globalMode: boolean;
  /**
   * 首次初始化完成时记录的时间戳（毫秒）。仅首次写入时赋值，后续复用该值。
   */
  initializedAt: number;
  /**
   * 最近一次更新操作记录的时间戳（毫秒）。每次写入 manifest 时刷新。
   */
  updatedAt: number;
}

/**
 * 运行时状态持久化记录，存储于本地存储中，用于跟踪应用的生命周期状态和迁移进度。
 */
export interface RuntimeStateRecord {
  /**
   * 状态记录的数据 schema 版本号，用于判断存储格式是否需要迁移。
   */
  schemaVersion: number;
  /**
   * 当前所处的生命周期阶段名称，例如 "created"、"initializing"、"ready" 等。在 saveRuntimeState 调用时由调用方指定。
   */
  phase: string;
  /**
   * 应用是否已完成初始化并可接受请求。对外提供健康检查依据。
   */
  ready: boolean;
  /**
   * 全局模式开关，与控制面保持一致的副本。在写入状态时由调用方同步传入。
   */
  globalMode: boolean;
  /**
   * 最近一次接收到的信号标识，用于追踪外部驱动的事件来源。在信号处理流程中更新。
   */
  lastSignal: string;
  /**
   * 当前生效的迁移版本号，用于记录数据迁移的进度。在迁移流程中由调用方更新。
   */
  migrationVersion: string;
  /**
   * 标记是否已完成从上次运行恢复状态的流程。在恢复逻辑完成后设置为 true。
   */
  restored: boolean;
  /**
   * 最近一次更新状态记录的时间戳（毫秒）。每次写入状态记录时刷新。
   */
  updatedAt: number;
}

/**
 * 应用启动时传入的初始化参数，用于配置启动流程的行为。
 */
export interface LifecycleStartupOptions {
  /**
   * 请求的全局模式，决定启动后是否启用多用户/全局功能。在触发启动流程时由外部传入。
   */
  globalMode: boolean;
  /**
   * 请求的恢复标记，通知启动流程是否需要执行上次运行状态的恢复操作。在启动前由外部判断后传入。
   */
  processRestored: boolean;
  /**
   * 请求的目标迁移版本号，用于指定启动时数据迁移的目标版本。在调用启动前由外部指定。
   */
  migrationVersion: string;
}

/**
 * 启动流程完成后的返回结果，包含已执行的生命周期阶段列表和最终运行时状态快照。
 */
export interface LifecycleStartupResult {
  /**
   * 启动过程中执行过的所有阶段名称列表，按执行顺序排列。用于调用方追踪启动进度。
   */
  phases: Array<string>;
  /**
   * 启动完成后的运行时状态快照，包含 phase/ready 等关键状态。调用方可据此判断是否启动成功。
   */
  state: RuntimeStateRecord;
}
