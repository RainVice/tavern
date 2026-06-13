export type MigrationStatus = 'pending' | 'running' | 'completed' | 'failed' | 'rolled_back';
export interface MigrationStep {
  stepId: string; fromVersion: number; toVersion: number; description: string;
  status: MigrationStatus; startedAt: number; completedAt: number; error: string;
}
export interface MigrationStepInput {
  description: string; fromVersion: number; toVersion: number;
}
export interface MigrationPlan {
  planId: string; steps: Array<MigrationStep>; status: MigrationStatus; createdAt: number;
}
export interface MigrationStartedPayload { plan: MigrationPlan; }
export interface MigrationStepCompletedPayload { step: MigrationStep; }
export interface MigrationCompletedPayload { plan: MigrationPlan; }
export interface MigrationExportData { plans: Array<MigrationPlan>; }
