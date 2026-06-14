/**
 * 迁移计划模块导出。
 * MigrationRuntime：提供创建、执行、回滚迁移计划及导出/导入的运行时能力。
 * 调用方通过此模块管理数据版本迁移的全生命周期，支持逐步执行和失败回滚。
 * MigrationModels：定义迁移计划、步骤、状态及其事件载荷的类型。
 * 类型用于在迁移流程中描述迁移任务结构和事件通知格式。
 */
export { MigrationRuntime } from './MigrationRuntime';
export type { MigrationCompletedPayload, MigrationExportData, MigrationPlan, MigrationStartedPayload, MigrationStatus, MigrationStep, MigrationStepCompletedPayload } from './MigrationModels';
