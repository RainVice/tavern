import { EventBus } from '../runtime/EventBus';
import type {
  MigrationCompletedPayload, MigrationExportData, MigrationPlan, MigrationStartedPayload,
  MigrationStep, MigrationStepCompletedPayload, MigrationStepInput,
} from './MigrationModels';

export class MigrationRuntime {
  private events: EventBus; private plans: Map<string,MigrationPlan>=new Map(); private counter=0;
  constructor(events: EventBus) { this.events=events; }

  createPlan(steps: Array<MigrationStepInput>): MigrationPlan {
    this.counter+=1; const planId=`migrate-${this.counter}`; const now=Date.now();
    const migrationSteps=new Array<MigrationStep>();
    for (let i=0;i<steps.length;i++) {
      migrationSteps.push({ stepId:`${planId}-step-${i+1}`, fromVersion:steps[i].fromVersion, toVersion:steps[i].toVersion, description:steps[i].description, status:'pending', startedAt:0, completedAt:0, error:'' });
    }
    const plan: MigrationPlan = { planId, steps: migrationSteps, status:'pending', createdAt:now };
    this.plans.set(planId, this.copyPlan(plan));
    this.events.publish<MigrationStartedPayload>('migration.started', { plan: this.copyPlan(plan) });
    return this.copyPlan(plan);
  }

  // 执行单步迁移
  executeStep(planId: string, stepId: string): MigrationStep {
    const plan = this.requirePlan(planId);
    const step = this.findStep(plan, stepId);
    if (step.status!=='pending') throw new Error(`迁移步骤状态不可执行: ${step.status}`);
    step.status='running'; step.startedAt=Date.now();
    plan.status='running';
    try {
      step.status='completed'; step.completedAt=Date.now();
      this.events.publish<MigrationStepCompletedPayload>('migration.step.completed', { step: this.copyStep(step) });
    } catch (e) { step.status='failed'; step.error=String(e); }
    this.checkPlanComplete(plan);
    return this.copyStep(step);
  }

  // 回滚步骤
  rollbackStep(planId: string, stepId: string): MigrationStep {
    const plan = this.requirePlan(planId);
    const step = this.findStep(plan, stepId);
    step.status='rolled_back'; step.error='已回滚'; step.completedAt=Date.now();
    return this.copyStep(step);
  }

  getPlan(planId: string): MigrationPlan { return this.copyPlan(this.requirePlan(planId)); }
  listPlans(): Array<MigrationPlan> {
    const result = new Array<MigrationPlan>();
    const values = Array.from(this.plans.values());
    for (let i = 0; i < values.length; i += 1) {
      result.push(this.copyPlan(values[i]));
    }
    return result;
  }

  private findStep(plan: MigrationPlan, stepId: string): MigrationStep {
    for (let i=0;i<plan.steps.length;i++) { if (plan.steps[i].stepId===stepId) return plan.steps[i]; }
    throw new Error(`迁移步骤未找到: ${stepId}`);
  }

  private checkPlanComplete(plan: MigrationPlan): void {
    let allDone=true;
    for (let i=0;i<plan.steps.length;i++) {
      if (plan.steps[i].status!=='completed'&&plan.steps[i].status!=='failed'&&plan.steps[i].status!=='rolled_back') { allDone=false; break; }
    }
    if (allDone) { plan.status='completed';
      this.events.publish<MigrationCompletedPayload>('migration.completed', { plan: this.copyPlan(plan) }); }
  }

  private requirePlan(planId: string): MigrationPlan {
    const p=this.plans.get(planId); if (p===undefined) throw new Error(`迁移计划未找到: ${planId}`); return p;
  }

  exportData(): MigrationExportData { return { plans: this.listPlans() }; }
  importData(data: MigrationExportData): void {
    for (let i=0;i<data.plans.length;i++) {
      const plan = this.copyPlan(data.plans[i]);
      this.plans.set(plan.planId, plan);
      this.counter = Math.max(this.counter, this.parseCounter(plan.planId));
    }
  }

  private copyPlan(plan: MigrationPlan): MigrationPlan {
    const steps = new Array<MigrationStep>();
    for (let i = 0; i < plan.steps.length; i += 1) {
      steps.push(this.copyStep(plan.steps[i]));
    }
    return {
      planId: plan.planId,
      steps: steps,
      status: plan.status,
      createdAt: plan.createdAt,
    };
  }

  private copyStep(step: MigrationStep): MigrationStep {
    return {
      stepId: step.stepId,
      fromVersion: step.fromVersion,
      toVersion: step.toVersion,
      description: step.description,
      status: step.status,
      startedAt: step.startedAt,
      completedAt: step.completedAt,
      error: step.error,
    };
  }

  private parseCounter(planId: string): number {
    if (!planId.startsWith('migrate-')) {
      return 0;
    }
    const parsed = Number(planId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
