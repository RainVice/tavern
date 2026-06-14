/**
 * 限定迁移计划模块可接受的字符串取值范围。
 */
export type MigrationStatus = 'pending' | 'running' | 'completed' | 'failed' | 'rolled_back';
/**
 * 迁移计划中的单个步骤，包含步骤标识、版本区间、执行状态和错误信息。
 */
export interface MigrationStep {
  /**
   * 步骤唯一标识。
   */
  stepId: string; fromVersion: number; toVersion: number; description: string;
  /**
   * 执行状态。
   */
  status: MigrationStatus; startedAt: number; completedAt: number; error: string;
}
/**
 * 创建迁移步骤时所需提供的参数：版本区间和步骤说明。
 */
export interface MigrationStepInput {
  /**
   * 步骤说明。
   */
  description: string; fromVersion: number; toVersion: number;
}
/**
 * 完整的迁移计划，包含计划标识、步骤列表、整体状态和创建时间。
 */
export interface MigrationPlan {
  /**
   * 计划唯一标识。
   */
  planId: string; steps: Array<MigrationStep>; status: MigrationStatus; createdAt: number;
}
/**
 * 迁移计划开始事件携带的载荷。
 */
export interface MigrationStartedPayload {
  /**
   * 关联的迁移计划。
   */
  plan: MigrationPlan;
}
/**
 * 迁移步骤完成事件携带的载荷。
 */
export interface MigrationStepCompletedPayload {
  /**
   * 已完成的迁移步骤。
   */
  step: MigrationStep;
}
/**
 * 迁移计划完成事件携带的载荷。
 */
export interface MigrationCompletedPayload {
  /**
   * 已完成的迁移计划。
   */
  plan: MigrationPlan;
}
/**
 * 迁移导出数据结构，包含全部迁移计划，用于备份或跨平台数据互通。
 */
export interface MigrationExportData {
  /**
   * plans 列表。
   */
  plans: Array<MigrationPlan>;
}
