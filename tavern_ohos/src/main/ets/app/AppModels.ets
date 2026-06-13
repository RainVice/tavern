/**
 * 描述应用运行状态模块在运行时交换的数据结构。
 */
export interface RuntimeManifest {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 运行时实例，由当前实例内部维护。
   */
  runtime: string;
  /**
   * global Mode 值，由当前实例内部维护。
   */
  globalMode: boolean;
  /**
   * initialized At 值，由当前实例内部维护。
   */
  initializedAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述应用运行状态持久化或内存索引中的一条记录。
 */
export interface RuntimeStateRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * phase 值，由当前实例内部维护。
   */
  phase: string;
  /**
   * ready 值，由当前实例内部维护。
   */
  ready: boolean;
  /**
   * global Mode 值，由当前实例内部维护。
   */
  globalMode: boolean;
  /**
   * last Signal 值，由当前实例内部维护。
   */
  lastSignal: string;
  /**
   * migration Version 值，由当前实例内部维护。
   */
  migrationVersion: string;
  /**
   * restored 值，由当前实例内部维护。
   */
  restored: boolean;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述应用运行状态模块在运行时交换的数据结构。
 */
export interface LifecycleStartupOptions {
  /**
   * global Mode 值，由当前实例内部维护。
   */
  globalMode: boolean;
  /**
   * process Restored 值，由当前实例内部维护。
   */
  processRestored: boolean;
  /**
   * migration Version 值，由当前实例内部维护。
   */
  migrationVersion: string;
}

/**
 * 描述应用运行状态操作完成后返回给调用方的结果。
 */
export interface LifecycleStartupResult {
  /**
   * phases 列表，由当前实例内部维护。
   */
  phases: Array<string>;
  /**
   * state 值，由当前实例内部维护。
   */
  state: RuntimeStateRecord;
}
