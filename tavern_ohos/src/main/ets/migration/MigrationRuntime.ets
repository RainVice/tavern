import { EventBus } from '../runtime/EventBus';
import type {
  MigrationCompletedPayload, MigrationExportData, MigrationPlan, MigrationStartedPayload,
  MigrationStep, MigrationStepCompletedPayload, MigrationStepInput,
} from './MigrationModels';

/**
 * 提供迁移计划相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class MigrationRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private plans: Map<string,MigrationPlan>=new Map(); private counter=0;
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 创建新的迁移计划记录，写入存储并返回副本。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 执行 executeStep 的内部处理步骤，供当前模块复用。
   * @param planId 目标迁移计划标识。
   * @param stepId 目标迁移步骤标识。
   */
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

  /**
   * 执行 rollbackStep 的内部处理步骤，供当前模块复用。
   * @param planId 目标迁移计划标识。
   * @param stepId 目标迁移步骤标识。
   */
  rollbackStep(planId: string, stepId: string): MigrationStep {
    const plan = this.requirePlan(planId);
    const step = this.findStep(plan, stepId);
    step.status='rolled_back'; step.error='已回滚'; step.completedAt=Date.now();
    return this.copyStep(step);
  }

  /**
   * 读取指定Plan，不存在时抛出错误。
   * @param planId 目标迁移计划标识。
   * @returns 更新或读取后的记录副本。
   */
  getPlan(planId: string): MigrationPlan { return this.copyPlan(this.requirePlan(planId)); }
  /**
   * 读取Plans列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listPlans(): Array<MigrationPlan> {
    const result = new Array<MigrationPlan>();
    const values = Array.from(this.plans.values());
    for (let i = 0; i < values.length; i += 1) {
      result.push(this.copyPlan(values[i]));
    }
    return result;
  }

  /**
   * 在当前集合中查找Step 值，未命中时返回空值或默认位置。

   * @param stepId 目标迁移步骤标识。
   */
  private findStep(plan: MigrationPlan, stepId: string): MigrationStep {
    for (let i=0;i<plan.steps.length;i++) { if (plan.steps[i].stepId===stepId) return plan.steps[i]; }
    throw new Error(`迁移步骤未找到: ${stepId}`);
  }

  /**
   * 检查PlanComplete是否满足当前规则。

   */
  private checkPlanComplete(plan: MigrationPlan): void {
    let allDone=true;
    for (let i=0;i<plan.steps.length;i++) {
      if (plan.steps[i].status!=='completed'&&plan.steps[i].status!=='failed'&&plan.steps[i].status!=='rolled_back') { allDone=false; break; }
    }
    if (allDone) { plan.status='completed';
      this.events.publish<MigrationCompletedPayload>('migration.completed', { plan: this.copyPlan(plan) }); }
  }

  /**
   * 读取必须存在的Plan 值，缺失时抛出错误。
   * @param planId 目标迁移计划标识。
   */
  private requirePlan(planId: string): MigrationPlan {
    const p=this.plans.get(planId); if (p===undefined) throw new Error(`迁移计划未找到: ${planId}`); return p;
  }

  /**
   * 导出数据，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 可持久化或可传输的导出内容。
   */
  exportData(): MigrationExportData { return { plans: this.listPlans() }; }
  /**
   * 从外部数据导入Data 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  importData(data: MigrationExportData): void {
    for (let i=0;i<data.plans.length;i++) {
      const plan = this.copyPlan(data.plans[i]);
      this.plans.set(plan.planId, plan);
      this.counter = Math.max(this.counter, this.parseCounter(plan.planId));
    }
  }

  /**
   * 复制Plan 值，避免外部修改内部状态。
   */
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

  /**
   * 复制Step 值，避免外部修改内部状态。
   */
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

  /**
   * 解析Counter，非法输入会返回失败标记或空结果。
   * @param planId 目标迁移计划标识。
   */
  private parseCounter(planId: string): number {
    if (!planId.startsWith('migrate-')) {
      return 0;
    }
    const parsed = Number(planId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
