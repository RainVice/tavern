import { describe, it, expect } from '@ohos/hypium';
import { EventBus, DataCleanupRuntime } from '../../Index';
export default function dataCleanupUnitTest() {
  describe('DataCleanupRuntime', () => {
    it('注册孤立文件并清理', 0, () => {
      const rt = new DataCleanupRuntime(new EventBus());
      rt.registerOrphanFile('/data/orphan.png');
      rt.registerCorruptIndex('/data/index.json');
      expect(rt.getStats().orphans).assertEqual(1);
      expect(rt.getStats().corrupt).assertEqual(1);
      const result = rt.runCleanup();
      expect(result.report.totalRemoved).assertEqual(2);
      expect(rt.getStats().orphans).assertEqual(0);
    });
  });
}
