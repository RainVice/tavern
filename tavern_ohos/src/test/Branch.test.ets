import { describe, it, expect } from '@ohos/hypium';
import {
  BranchRuntime,
  EventBus,
  type BranchActivatedPayload,
  type BranchCreateParams,
  type BranchEventPayload,
  type BranchExportData,
  type BranchRecord,
  type CheckpointCreateParams,
  type CheckpointEventPayload,
  type CheckpointRecord,
  type RuntimeEvent,
} from '../../Index';

export default function branchUnitTest() {
  describe('branch runtime', () => {
    it('creates branches from arbitrary messages and tracks lineage', 0, () => {
      // 运行时实例。
      const runtime = new BranchRuntime(new EventBus());
      const branch = runtime.createBranch(makeBranch('branch-1', 'chat-1', 'msg-3', 'chat-2'));
      const child = runtime.createBranch(makeBranch('branch-2', 'chat-2', 'msg-6', 'chat-3'));
      const lineage: Array<BranchRecord> = runtime.getLineage('chat-3');
      const branchesFromChat = runtime.listBranches('chat-1');

      expect(branch.parentChatId).assertEqual('chat-1');
      expect(child.childChatId).assertEqual('chat-3');
      expect(branchesFromChat.length).assertEqual(1);
      expect(lineage.length).assertEqual(2);
      expect(lineage[0].id).assertEqual('branch-1');
      expect(lineage[1].id).assertEqual('branch-2');
    });

    it('creates checkpoints, switches active branches, and emits branch.activated', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new BranchRuntime(bus);
      const activated = new Array<string>();
      bus.subscribe<BranchActivatedPayload>('branch.activated', (event: RuntimeEvent<BranchActivatedPayload>) => {
        activated.push(event.payload.branch.id);
      });
      const branch = runtime.createBranch(makeBranch('branch-3', 'chat-4', 'msg-2', 'chat-5'));
      const checkpoint: CheckpointRecord = runtime.createCheckpoint(makeCheckpoint('checkpoint-1', branch.id, 'msg-2'));
      const active = runtime.activateBranch(branch.id);

      expect(checkpoint.branchId).assertEqual('branch-3');
      expect(checkpoint.anchorMessageId).assertEqual('msg-2');
      expect(active.id).assertEqual('branch-3');
      expect(runtime.getActiveBranch('chat-4').id).assertEqual('branch-3');
      expect(activated.length).assertEqual(1);
      expect(activated[0]).assertEqual('branch-3');
    });

    it('exports and restores branches with checkpoints', 0, () => {
      // 运行时实例。
      const runtime = new BranchRuntime(new EventBus());
      const branch = runtime.createBranch(makeBranch('branch-4', 'chat-7', 'msg-4', 'chat-8'));
      runtime.createCheckpoint(makeCheckpoint('checkpoint-2', branch.id, 'msg-4'));
      const exported: BranchExportData = runtime.exportBranch(branch.id);
      const restored = runtime.restoreBranch(exported, 'branch-5', 'chat-9');
      const originalExported = runtime.exportBranch('branch-4');
      const restoredExported = runtime.exportBranch('branch-5');

      expect(exported.checkpoints.length).assertEqual(1);
      expect(restored.id).assertEqual('branch-5');
      expect(restored.childChatId).assertEqual('chat-9');
      expect(originalExported.checkpoints[0].id).assertEqual('checkpoint-2');
      expect(restoredExported.checkpoints[0].id).assertEqual('branch-5:checkpoint-2');
      expect(restoredExported.checkpoints[0].branchId).assertEqual('branch-5');
    });

    it('rejects duplicate branch and checkpoint ids', 0, () => {
      // 运行时实例。
      const runtime = new BranchRuntime(new EventBus());
      const branch = runtime.createBranch(makeBranch('branch-existing', 'chat-1', 'msg-1', 'chat-2'));
      runtime.createCheckpoint(makeCheckpoint('checkpoint-existing', branch.id, 'msg-1'));
      const exported: BranchExportData = runtime.exportBranch(branch.id);
      let branchThrown = false;
      try {
        runtime.createBranch(makeBranch('branch-existing', 'chat-3', 'msg-3', 'chat-4'));
      } catch (error) {
        branchThrown = true;
      }
      let checkpointThrown = false;
      try {
        runtime.createCheckpoint(makeCheckpoint('checkpoint-existing', branch.id, 'msg-1'));
      } catch (error) {
        checkpointThrown = true;
      }
      let restoreThrown = false;
      try {
        runtime.restoreBranch(exported, 'branch-existing', 'chat-restored');
      } catch (error) {
        restoreThrown = true;
      }

      expect(branchThrown).assertTrue();
      expect(checkpointThrown).assertTrue();
      expect(restoreThrown).assertTrue();
      expect(runtime.listBranches('').length).assertEqual(1);
      expect(runtime.exportBranch(branch.id).checkpoints.length).assertEqual(1);
    });

    it('does not expose internal branches or checkpoints through returns, events, or lists', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new BranchRuntime(bus);
      bus.subscribe<BranchEventPayload>('branch.created', (event: RuntimeEvent<BranchEventPayload>) => {
        event.payload.branch.title = 'event-mutated';
      });
      bus.subscribe<CheckpointEventPayload>('branch.checkpoint.created', (event: RuntimeEvent<CheckpointEventPayload>) => {
        event.payload.checkpoint.label = 'event-mutated';
      });
      bus.subscribe<BranchActivatedPayload>('branch.activated', (event: RuntimeEvent<BranchActivatedPayload>) => {
        event.payload.branch.title = 'activated-mutated';
      });
      const branch = runtime.createBranch(makeBranch('branch-copy', 'chat-copy', 'msg-copy', 'child-copy'));
      branch.title = 'return-mutated';
      const checkpoint = runtime.createCheckpoint(makeCheckpoint('checkpoint-copy', 'branch-copy', 'msg-copy'));
      checkpoint.label = 'return-mutated';
      const active = runtime.activateBranch('branch-copy');
      active.title = 'active-mutated';
      const listed = runtime.listBranches('chat-copy');
      listed[0].title = 'list-mutated';
      const lineage = runtime.getLineage('child-copy');
      lineage[0].title = 'lineage-mutated';

      expect(runtime.getActiveBranch('chat-copy').title).assertEqual('branch-copy');
      expect(runtime.exportBranch('branch-copy').checkpoints[0].label).assertEqual('checkpoint-copy');
    });
  });
}

/**
 * 封装单元测试中的 makeBranch 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param parentChatId parent Chat 标识。
 * @param anchorMessageId anchor Message 标识。
 * @param childChatId child Chat 标识。
 */
function makeBranch(id: string, parentChatId: string, anchorMessageId: string, childChatId: string): BranchCreateParams {
  return {
    id: id,
    parentChatId: parentChatId,
    anchorMessageId: anchorMessageId,
    childChatId: childChatId,
    title: id,
  };
}

/**
 * 封装单元测试中的 makeCheckpoint 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param branchId branch 标识。
 * @param anchorMessageId anchor Message 标识。
 */
function makeCheckpoint(id: string, branchId: string, anchorMessageId: string): CheckpointCreateParams {
  return {
    id: id,
    branchId: branchId,
    anchorMessageId: anchorMessageId,
    label: id,
    snapshotRef: `snapshot-${id}`,
  };
}
