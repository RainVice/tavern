import { EventBus } from '../runtime/EventBus';
import type {
  MigrationCompletedPayload, MigrationExportData, MigrationPlan, MigrationStartedPayload,
  MigrationStep, MigrationStepCompletedPayload, MigrationStepInput,
} from './MigrationModels';

/**
 * 提供迁移计划相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 调用方用于管理数据迁移的全生命周期：创建计划、逐步执行、失败回滚、数据导出/导入。
 */
export class MigrationRuntime {
  /**
   * 事件总线，用于在迁移计划创建、步骤执行、计划完成等阶段发布事件，通知 UI 层或其他监听方。
   */
  private events: EventBus;
  /**
   * 内存中的迁移计划索引，以 planId 为键，用于在整个运行时生命周期内管理多个迁移任务。
   */
  private plans: Map<string, MigrationPlan> = new Map();
  /**
   * 自增计数器，用于在 createPlan 时生成唯一 planId，确保 planId 全局有序。
   */
  private counter = 0;
  /**
   * 初始化当前运行时实例，绑定事件总线用于后续事件发布。
   * 调用方传入的事件总线实例用于连接迁移流程与外部监听方。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 根据步骤列表创建新的迁移计划，存入内存并发布迁移开始事件。
   * 调用方在需要执行数据迁移时调用此方法生成计划，监听方通过 migration.started 事件获取通知。
   * @param steps 构成迁移计划的步骤输入参数列表，描述从哪个版本迁移到哪个版本的各个阶段。
   * @returns 新创建的迁移计划副本。
   */
  createPlan(steps: Array<MigrationStepInput>): MigrationPlan {
    this.counter += 1;
    const planId = `migrate-${this.counter}`;
    const now = Date.now();
    const migrationSteps = new Array<MigrationStep>();
    for (let i = 0; i < steps.length; i++) {
      migrationSteps.push({
        stepId: `${planId}-step-${i + 1}`,
        fromVersion: steps[i].fromVersion,
        toVersion: steps[i].toVersion,
        description: steps[i].description,
        status: 'pending',
        startedAt: 0,
        completedAt: 0,
        error: '',
      });
    }
    const plan: MigrationPlan = {
      planId,
      steps: migrationSteps,
      status: 'pending',
      createdAt: now,
    };
    this.plans.set(planId, this.copyPlan(plan));
    this.events.publish<MigrationStartedPayload>('migration.started', { plan: this.copyPlan(plan) });
    return this.copyPlan(plan);
  }

  /**
   * 执行指定迁移计划中的单个步骤，更新状态并发布步骤完成事件。
   * 调用方按步骤逐一调用此方法推动迁移流程，被错误捕获的步骤自动标记为 failed。
   * @param planId 目标迁移计划标识。
   * @param stepId 目标迁移步骤标识。
   * @returns 执行后的迁移步骤副本。
   */
  executeStep(planId: string, stepId: string): MigrationStep {
    const plan = this.requirePlan(planId);
    const step = this.findStep(plan, stepId);
    if (step.status !== 'pending') {
      throw new Error(`迁移步骤状态不可执行: ${step.status}`);
    }
    step.status = 'running';
    step.startedAt = Date.now();
    plan.status = 'running';
    try {
      step.status = 'completed';
      step.completedAt = Date.now();
      this.events.publish<MigrationStepCompletedPayload>('migration.step.completed', {
        step: this.copyStep(step),
      });
    } catch (e) {
      step.status = 'failed';
      step.error = String(e);
    }
    this.checkPlanComplete(plan);
    return this.copyStep(step);
  }

  /**
   * 回滚指定迁移计划中的单个步骤，将其状态标记为已回滚。
   * 调用方在迁移过程中某个步骤失败后可调用此方法回滚已完成的步骤以恢复原始状态。
   * @param planId 目标迁移计划标识。
   * @param stepId 目标迁移步骤标识。
   * @returns 回滚后的迁移步骤副本。
   */
  rollbackStep(planId: string, stepId: string): MigrationStep {
    const plan = this.requirePlan(planId);
    const step = this.findStep(plan, stepId);
    step.status = 'rolled_back';
    step.error = '已回滚';
    step.completedAt = Date.now();
    return this.copyStep(step);
  }

  /**
   * 根据 planId 读取指定的迁移计划，不存在时抛出异常。
   * 调用方在需要查看某个迁移计划详情或做后续操作时使用此方法。
   * @param planId 目标迁移计划标识。
   * @returns 匹配的迁移计划副本。
   */
  getPlan(planId: string): MigrationPlan {
    return this.copyPlan(this.requirePlan(planId));
  }

  /**
   * 返回当前内存中所有迁移计划的副本列表。
   * 调用方在需要展示迁移计划列表或批量处理时使用此方法。
   * @returns 全部迁移计划的副本数组。
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
   * 在指定迁移计划中按 stepId 查找迁移步骤，未找到时抛出异常。
   * 由 executeStep、rollbackStep 等内部方法调用，用于在迁移流程中定位目标步骤。
   * @param plan 待检索的迁移计划。
   * @param stepId 目标迁移步骤标识。
   * @returns 匹配的迁移步骤引用。
   */
  private findStep(plan: MigrationPlan, stepId: string): MigrationStep {
    for (let i = 0; i < plan.steps.length; i++) {
      if (plan.steps[i].stepId === stepId) {
        return plan.steps[i];
      }
    }
    throw new Error(`迁移步骤未找到: ${stepId}`);
  }

  /**
   * 检查迁移计划的所有步骤是否均已终态（completed/failed/rolled_back），若是则将计划标记为 completed 并发布完成事件。
   * 在 executeStep 每次执行步骤后自动调用，用于在迁移流程中驱动计划级完成判定。
   * @param plan 待检查的迁移计划。
   */
  private checkPlanComplete(plan: MigrationPlan): void {
    let allDone = true;
    for (let i = 0; i < plan.steps.length; i++) {
      if (
        plan.steps[i].status !== 'completed' &&
        plan.steps[i].status !== 'failed' &&
        plan.steps[i].status !== 'rolled_back'
      ) {
        allDone = false;
        break;
      }
    }
    if (allDone) {
      plan.status = 'completed';
      this.events.publish<MigrationCompletedPayload>('migration.completed', {
        plan: this.copyPlan(plan),
      });
    }
  }

  /**
   * 根据 planId 从内存映射中获取迁移计划，未找到时抛出异常。
   * 由 getPlan、executeStep、rollbackStep 等公开方法内部调用，用于确保目标计划存在。
   * @param planId 目标迁移计划标识。
   * @returns 匹配的迁移计划引用。
   */
  private requirePlan(planId: string): MigrationPlan {
    const p = this.plans.get(planId);
    if (p === undefined) {
      throw new Error(`迁移计划未找到: ${planId}`);
    }
    return p;
  }

  /**
   * 导出所有迁移计划，用于备份或与外部工具互通。
   * 调用方在需要持久化迁移计划记录或将计划迁移到其他环境时使用此方法。
   * @returns 包含所有迁移计划列表的导出数据。
   */
  exportData(): MigrationExportData {
    return { plans: this.listPlans() };
  }

  /**
   * 从导入的序列化数据中恢复迁移计划到内存索引。
   * 调用方在从备份恢复迁移计划时使用此方法，还原后的计划可继续执行或查阅。
   * @param data 导入或恢复使用的序列化数据。
   */
  importData(data: MigrationExportData): void {
    for (let i = 0; i < data.plans.length; i++) {
      const plan = this.copyPlan(data.plans[i]);
      this.plans.set(plan.planId, plan);
      this.counter = Math.max(this.counter, this.parseCounter(plan.planId));
    }
  }

  /**
   * 深拷贝 MigrationPlan，防止外部修改内部状态。
   * 调用方通过所有公开方法获取的副本均经过此方法处理，确保运行时内部状态不被污染。
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
   * 深拷贝 MigrationStep，防止外部修改内部状态。
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
   * 从 planId 中解析出自增计数值，用于恢复计数器状态。
   * 在 importData 中调用，确保导入后续创建的新计划不会与已有 planId 冲突。
   * @param planId 迁移计划标识。
   * @returns 解析出的数值，非法格式返回 0。
   */
  private parseCounter(planId: string): number {
    if (!planId.startsWith('migrate-')) {
      return 0;
    }
    const parsed = Number(planId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
