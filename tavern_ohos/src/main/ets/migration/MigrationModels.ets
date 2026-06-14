/**
 * 迁移计划的运行状态：待执行、执行中、已完成、失败、已回滚。
 * 用于在整个迁移流程中追踪每个步骤和整体计划的当前阶段。
 */
export type MigrationStatus = 'pending' | 'running' | 'completed' | 'failed' | 'rolled_back';

/**
 * 迁移步骤的详细信息，包含来源/目标版本、步骤描述及当前执行状态。
 * 用于记录数据迁移过程中单个步骤的完整状态，支持步骤粒度的执行和回滚。
 */
export interface MigrationStep {
  /**
   * 步骤的唯一标识，格式为 {planId}-step-{序号}，用于在迁移流程中定位单个步骤。
   */
  stepId: string;
  /**
   * 迁移步骤的来源版本号，用于标识该步骤从哪个版本开始迁移。
   */
  fromVersion: number;
  /**
   * 迁移步骤的目标版本号，用于标识该步骤迁移到的版本。
   */
  toVersion: number;
  /**
   * 迁移步骤的描述信息，用于在用户界面显示该步骤的用途说明。
   */
  description: string;
  /**
   * 步骤的当前执行状态，由 createPlan 初始化为 pending，executeStep/rollbackStep 修改。
   * 用于在迁移流程中驱动步骤执行的进度控制。
   */
  status: MigrationStatus;
  /**
   * 步骤开始执行的时间戳，由 executeStep 在状态变为 running 时设置，用于记录执行耗时。
   */
  startedAt: number;
  /**
   * 步骤完成或回滚的时间戳，由 executeStep/rollbackStep 在终态时设置，用于记录完成时间。
   */
  completedAt: number;
  /**
   * 步骤执行失败时的错误信息，由 executeStep 在 catch 块中记录，用于故障排查。
   */
  error: string;
}

/**
 * 创建迁移步骤时所需的输入参数，包含描述、来源版本号和目标版本号。
 * 用于调用方准备迁移计划时提供步骤元信息，由 createPlan 转换为完整的 MigrationStep。
 */
export interface MigrationStepInput {
  /**
   * 迁移步骤的描述信息，用于在用户界面显示该步骤的用途说明。
   */
  description: string;
  /**
   * 来源版本号，用于标识该步骤从哪个版本开始迁移。
   */
  fromVersion: number;
  /**
   * 目标版本号，用于标识该步骤迁移到的版本。
   */
  toVersion: number;
}

/**
 * 迁移计划的完整记录，包含 planId、步骤列表和整体状态。
 * 用于组织多个迁移步骤构成完整的迁移工作流，支持创建、执行、回滚全生命周期。
 */
export interface MigrationPlan {
  /**
   * 迁移计划的唯一标识，格式为 migrate-{自增序号}，用于在运行时索引和定位迁移任务。
   */
  planId: string;
  /**
   * 迁移计划包含的步骤列表，按顺序执行，用于驱动逐步的数据迁移流程。
   */
  steps: Array<MigrationStep>;
  /**
   * 迁移计划的整体状态，由 createPlan 初始化为 pending，步骤执行/完成后自动更新。
   * 用于在迁移流程中反映计划的整体进度。
   */
  status: MigrationStatus;
  /**
   * 迁移计划创建时的时间戳，用于记录计划发起时刻，便于审计和排查。
   */
  createdAt: number;
}

/**
 * 迁移计划开始执行时通过事件总线发布的数据载荷。
 * 用于通知监听方（如 UI 层）迁移已启动，以便更新进度显示。
 */
export interface MigrationStartedPayload {
  /**
   * 已开始的迁移计划对象，包含步骤列表和状态信息，供监听方处理迁移进度。
   */
  plan: MigrationPlan;
}

/**
 * 迁移计划中单个步骤完成时通过事件总线发布的数据载荷。
 * 用于通知监听方（如 UI 层）单个步骤执行完毕，以便更新步骤级进度。
 */
export interface MigrationStepCompletedPayload {
  /**
   * 已完成的迁移步骤对象，包含执行状态和时间戳，供监听方更新步骤状态显示。
   */
  step: MigrationStep;
}

/**
 * 迁移计划全部完成后通过事件总线发布的数据载荷。
 * 用于通知监听方（如 UI 层）整个迁移流程结束，以便显示完成提示。
 */
export interface MigrationCompletedPayload {
  /**
   * 已完成的迁移计划对象，供监听方确认迁移已结束并处理后续逻辑。
   */
  plan: MigrationPlan;
}

/**
 * 迁移计划的导出/导入格式，包含所有迁移计划记录。
 * 用于序列化迁移数据以便备份恢复或在不同运行环境间迁移。
 */
export interface MigrationExportData {
  /**
   * 要导出或导入的迁移计划列表，用于备份迁移记录或从外部恢复迁移状态。
   */
  plans: Array<MigrationPlan>;
}
