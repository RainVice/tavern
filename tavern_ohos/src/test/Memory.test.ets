import { describe, it, expect } from '@ohos/hypium';
import { EventBus, MemoryRuntime, type MemoryExportData, type MemoryExtractedPayload } from '../../Index';

export default function memoryUnitTest() {
  describe('MemoryRuntime', () => {
    it('创建记忆条目并获取最新', 0, () => {
      const bus = new EventBus();
      const runtime = new MemoryRuntime(bus);
      let extracted = false;
      bus.subscribe<MemoryExtractedPayload>('memory.extracted', () => { extracted = true; });

      runtime.createEntry('chat-1', '摘要1', ['关键点A'], ['msg1', 'msg2'], 100);
      runtime.createEntry('chat-1', '摘要2', ['关键点B'], ['msg3'], 50);

      const latest = runtime.getLatestEntry('chat-1');
      expect(latest === undefined).assertFalse();
      if (latest !== undefined) {
        expect(latest.summary).assertEqual('摘要2');
        expect(latest.keyPoints[0]).assertEqual('关键点B');
      }
      expect(extracted).assertTrue();
    });

    it('构建 Prompt 注入', 0, () => {
      const bus = new EventBus();
      const runtime = new MemoryRuntime(bus);
      runtime.createEntry('chat-1', '用户喜欢猫', ['猫'], ['msg1'], 10);
      runtime.createEntry('chat-1', '用户住在北京', ['北京'], ['msg2'], 10);

      const injection = runtime.buildPromptInjection('chat-1', 2);
      expect(injection).assertContain('[记忆]');
      expect(injection).assertContain('北京');
    });

    it('按聊天过滤记忆', 0, () => {
      const bus = new EventBus();
      const runtime = new MemoryRuntime(bus);
      runtime.createEntry('chat-1', 'A', [], [], 10);
      runtime.createEntry('chat-2', 'B', [], [], 10);
      expect(runtime.listEntries('chat-1').length).assertEqual(1);
      expect(runtime.listEntries().length).assertEqual(2);
    });

    it('读取和导出不会暴露内部记忆条目', 0, () => {
      const runtime = new MemoryRuntime(new EventBus());
      const entry = runtime.createEntry('chat-1', '摘要', ['关键点A'], ['msg1'], 10);
      entry.summary = '外部修改';
      entry.keyPoints.push('外部关键点');

      const latest = runtime.getLatestEntry('chat-1');
      expect(latest === undefined).assertFalse();
      if (latest !== undefined) {
        expect(latest.summary).assertEqual('摘要');
        expect(latest.keyPoints.length).assertEqual(1);
      }

      const exported = runtime.exportData();
      exported.entries[0].summary = '导出修改';
      exported.entries[0].originalMessages.push('msg2');
      const saved = runtime.listEntries('chat-1')[0];
      expect(saved.summary).assertEqual('摘要');
      expect(saved.originalMessages.length).assertEqual(1);
    });

    it('导入后新建记忆不会复用已有 ID', 0, () => {
      const runtime = new MemoryRuntime(new EventBus());
      const data: MemoryExportData = {
        entries: [{
          entryId: 'memory-5',
          chatId: 'chat-1',
          summary: '导入摘要',
          keyPoints: ['A'],
          originalMessages: ['msg1'],
          tokenEstimate: 10,
          createdAt: 1,
          updatedAt: 1,
        }],
      };
      runtime.importData(data);
      const created = runtime.createEntry('chat-1', '新摘要', [], [], 5);
      expect(created.entryId).assertEqual('memory-6');
    });
  });
}
