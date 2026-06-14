/**
 * 限定迁移计划模块可接受的字符串取值范围。
 */
export type MigrationStatus = 'pending' | 'running' | 'completed' | 'failed' | 'rolled_back';
/**
 * 描述迁移计划模块在运行时交换的数据结构。
 */
export interface MigrationStep {
  /**
   * step 标识。
   */
  stepId: string; fromVersion: number; toVersion: number; description: string;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: MigrationStatus; startedAt: number; completedAt: number; error: string;
}
/**
 * 描述调用迁移计划能力时需要传入的参数。
 */
export interface MigrationStepInput {
  /**
   * description 值，由当前实例内部维护。
   */
  description: string; fromVersion: number; toVersion: number;
}
/**
 * 描述迁移计划模块在运行时交换的数据结构。
 */
export interface MigrationPlan {
  /**
   * plan 标识。
   */
  planId: string; steps: Array<MigrationStep>; status: MigrationStatus; createdAt: number;
}
/**
 * 描述迁移计划事件发布时携带的数据结构。
 */
export interface MigrationStartedPayload {
  /**
   * plan 值，由当前实例内部维护。
   */
  plan: MigrationPlan;
}
/**
 * 描述迁移计划事件发布时携带的数据结构。
 */
export interface MigrationStepCompletedPayload {
  /**
   * step 值，由当前实例内部维护。
   */
  step: MigrationStep;
}
/**
 * 描述迁移计划事件发布时携带的数据结构。
 */
export interface MigrationCompletedPayload {
  /**
   * plan 值，由当前实例内部维护。
   */
  plan: MigrationPlan;
}
/**
 * 描述迁移计划模块在运行时交换的数据结构。
 */
export interface MigrationExportData {
  /**
   * plans 列表。
   */
  plans: Array<MigrationPlan>;
}
