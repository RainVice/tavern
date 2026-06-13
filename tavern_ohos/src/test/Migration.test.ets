import { describe, it, expect } from '@ohos/hypium';
import { EventBus, MigrationRuntime, type MigrationCompletedPayload, type MigrationExportData } from '../../Index';

export default function migrationUnitTest() {
  describe('MigrationRuntime', () => {
    it('创建和执行迁移计划', 0, () => {
      const bus = new EventBus();
      const runtime = new MigrationRuntime(bus);
      let completed = false;
      bus.subscribe<MigrationCompletedPayload>('migration.completed', () => { completed = true; });

      const plan = runtime.createPlan([{ description: '更新 schema', fromVersion: 1, toVersion: 2 }, { description: '迁移数据', fromVersion: 2, toVersion: 3 }]);
      runtime.executeStep(plan.planId, plan.steps[0].stepId);
      runtime.executeStep(plan.planId, plan.steps[1].stepId);

      const saved = runtime.getPlan(plan.planId);
      expect(saved.status).assertEqual('completed');
      expect(saved.steps[0].status).assertEqual('completed');
      expect(saved.steps[1].status).assertEqual('completed');
      expect(completed).assertTrue();
    });

    it('回滚迁移步骤', 0, () => {
      const bus = new EventBus();
      const runtime = new MigrationRuntime(bus);
      const plan = runtime.createPlan([{ description: '危险操作', fromVersion: 1, toVersion: 2 }]);
      runtime.rollbackStep(plan.planId, plan.steps[0].stepId);
      const step = runtime.getPlan(plan.planId).steps[0];
      expect(step.status).assertEqual('rolled_back');
    });

    it('列出迁移计划', 0, () => {
      const bus = new EventBus();
      const runtime = new MigrationRuntime(bus);
      runtime.createPlan([{ description: 'A', fromVersion: 1, toVersion: 2 }]);
      runtime.createPlan([{ description: 'B', fromVersion: 2, toVersion: 3 }]);
      expect(runtime.listPlans().length).assertEqual(2);
    });

    it('读取和导出不会暴露内部迁移计划', 0, () => {
      const runtime = new MigrationRuntime(new EventBus());
      const plan = runtime.createPlan([{ description: 'A', fromVersion: 1, toVersion: 2 }]);
      plan.steps[0].status = 'completed';
      plan.steps.push({
        stepId: '外部步骤',
        fromVersion: 2,
        toVersion: 3,
        description: '不应写入内部',
        status: 'completed',
        startedAt: 0,
        completedAt: 0,
        error: '',
      });

      const saved = runtime.getPlan(plan.planId);
      expect(saved.steps.length).assertEqual(1);
      expect(saved.steps[0].status).assertEqual('pending');

      const exported = runtime.exportData();
      exported.plans[0].steps[0].status = 'failed';
      expect(runtime.getPlan(plan.planId).steps[0].status).assertEqual('pending');
    });

    it('导入后新建迁移计划不会复用已有 ID', 0, () => {
      const runtime = new MigrationRuntime(new EventBus());
      const data: MigrationExportData = {
        plans: [{
          planId: 'migrate-7',
          status: 'pending',
          createdAt: 1,
          steps: [{
            stepId: 'migrate-7-step-1',
            fromVersion: 1,
            toVersion: 2,
            description: '导入计划',
            status: 'pending',
            startedAt: 0,
            completedAt: 0,
            error: '',
          }],
        }],
      };
      runtime.importData(data);
      const created = runtime.createPlan([{ description: '新计划', fromVersion: 2, toVersion: 3 }]);
      expect(created.planId).assertEqual('migrate-8');
    });
  });
}
