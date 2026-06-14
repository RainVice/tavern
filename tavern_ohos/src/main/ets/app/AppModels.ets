/**
 * 描述应用运行状态模块在运行时交换的数据结构，用于在应用启动、状态恢复和初始化等流程中传递运行时配置信息。
 */
export interface RuntimeManifest {
  /**
   * 清单文件的 schema 版本号，用于在应用启动时判断持久化数据是否需要执行迁移升级。
   */
  schemaVersion: number;
  /**
   * 当前运行的运行时环境标识（如 tavern_ohos），用于在多环境切换时区分不同运行时的数据来源。
   */
  runtime: string;
  /**
   * 是否启用全局模式，用于在对话上下文管理中决定是否跨角色共享同一上下文，影响 Prompt 组装策略。
   */
  globalMode: boolean;
  /**
   * 首次完成初始化的时间戳（毫秒），用于在应用启动流程中判断是否需要执行首次初始化逻辑；值为 0 表示尚未初始化。
   */
  initializedAt: number;
  /**
   * 最近一次更新 manifest 的时间戳（毫秒），用于追踪运行状态变更时机，辅助数据恢复流程完成后的状态校验。
   */
  updatedAt: number;
}

/**
 * 描述应用运行状态持久化或内存索引中的一条记录，用于在状态恢复、生命周期追踪和外部查询时反映运行时阶段信息。
 */
export interface RuntimeStateRecord {
  /**
   * 清单文件的 schema 版本号，用于在状态恢复时判断旧版本数据是否需要执行升级操作。
   */
  schemaVersion: number;
  /**
   * 当前生命周期阶段（如 created、initializing、running），用于在状态恢复和外部查询时反映运行时所处阶段。
   */
  phase: string;
  /**
   * 运行时是否已就绪，用于在外部模块调用前检查运行时是否已完成初始化并准备好接受操作。
   */
  ready: boolean;
  /**
   * 是否启用全局模式，用于在状态恢复后确定上下文隔离策略是否需要调整。
   */
  globalMode: boolean;
  /**
   * 最近一次收到的信号标识，用于在跨模块通信中追踪运行时收到的最后一条指令，便于调试和状态恢复。
   */
  lastSignal: string;
  /**
   * 数据迁移版本号，用于在启动流程中将旧版本数据结构升级到最新格式。
   */
  migrationVersion: string;
  /**
   * 是否从持久化存储中成功恢复状态，用于在应用恢复流程结束后判断数据一致性。
   */
  restored: boolean;
  /**
   * 最近一次更新状态记录的时间戳（毫秒），用于追踪状态变更时机，辅助异步流程中的数据一致性校验。
   */
  updatedAt: number;
}

/**
 * 描述应用运行状态模块在运行时交换的数据结构，用于在应用启动或状态恢复时传递初始化参数。
 */
export interface LifecycleStartupOptions {
  /**
   * 是否启用全局模式，用于在启动流程中初始化运行时上下文隔离策略。
   */
  globalMode: boolean;
  /**
   * 是否是从持久化存储中恢复的应用状态，用于在启动流程中决定是否需要执行完整的初始化逻辑或跳过初始步骤。
   */
  processRestored: boolean;
  /**
   * 数据迁移版本号，用于在初始化时执行对应版本的数据升级操作，确保持久化数据与当前代码结构兼容。
   */
  migrationVersion: string;
}

/**
 * 描述应用运行状态操作完成后返回给调用方的结果，用于启动流程结束后外部模块获取执行结果和最终状态。
 */
export interface LifecycleStartupResult {
  /**
   * 启动过程中经过的各个阶段名称列表，用于调用方追踪启动流程的执行链路，便于调试和日志记录。
   */
  phases: Array<string>;
  /**
   * 启动完成后的运行时状态，用于调用方判断运行时是否已正常就绪并可接受后续操作。
   */
  state: RuntimeStateRecord;
}
