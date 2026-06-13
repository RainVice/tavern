import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  RecoveryRuntime,
  type RecoveryAttemptedPayload,
  type RecoveryMetadata,
  type RuntimeEvent,
} from '../../Index';
export default function recoveryUnitTest() {
  describe('RecoveryRuntime', () => {
    it('创建快照并恢复', 0, () => {
      const rt = new RecoveryRuntime(new EventBus());
      const metadata: RecoveryMetadata = { source: 'crash', chatId: 'chat-1' };
      rt.createSnapshot('session_restore', metadata);
      const snap = rt.getLatestSnapshot('session_restore');
      expect(snap === undefined).assertFalse();
      const result = rt.attemptRecovery('session_restore');
      expect(result.success).assertTrue();
      expect(result.message).assertContain('快照');
    });
    it('无快照恢复失败', 0, () => {
      const rt = new RecoveryRuntime(new EventBus());
      const result = rt.attemptRecovery('data_corruption');
      expect(result.success).assertFalse();
      expect(result.message).assertContain('无可恢复');
    });
    it('快照返回值不暴露内部 metadata', 0, () => {
      const rt = new RecoveryRuntime(new EventBus());
      const metadata: RecoveryMetadata = { source: 'crash', chatId: 'chat-copy' };
      const created = rt.createSnapshot('session_restore', metadata);
      metadata.source = 'external';
      created.metadata.source = 'mutated';
      const latest = rt.getLatestSnapshot('session_restore');
      expect(latest === undefined).assertFalse();
      if (latest !== undefined) {
        latest.metadata.source = 'latest-mutated';
      }
      const listed = rt.listSnapshots();
      listed[0].metadata.source = 'listed-mutated';
      const stable = rt.getLatestSnapshot('session_restore');
      expect(stable === undefined).assertFalse();
      if (stable !== undefined) {
        expect(stable.metadata.source).assertEqual('crash');
      }
    });
    it('恢复事件不会篡改返回结果', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      const rt = new RecoveryRuntime(bus);
      bus.subscribe<RecoveryAttemptedPayload>('recovery.attempted', (event: RuntimeEvent<RecoveryAttemptedPayload>) => {
        event.payload.result.success = false;
        event.payload.result.message = '事件修改';
      });
      rt.createSnapshot('session_restore', { source: 'crash' });
      const result = rt.attemptRecovery('session_restore');

      expect(result.success).assertTrue();
      expect(result.message).assertContain('crash');
    });
  });
}
