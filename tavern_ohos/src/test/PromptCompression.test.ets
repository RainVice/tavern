import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  PromptCompressionRuntime,
  type CompressionAppliedPayload,
  type CompressionConfig,
  type RuntimeEvent,
} from '../../Index';
export default function promptCompressionUnitTest() {
  describe('PromptCompressionRuntime', () => {
    it('未启用时不压缩', 0, () => {
      const rt = new PromptCompressionRuntime(new EventBus());
      const result = rt.applyCompression(5000, 5000);
      expect(result.isCompressed).assertFalse();
    });
    it('启用时压缩超限 token', 0, () => {
      const rt = new PromptCompressionRuntime(new EventBus());
      rt.setConfig({ enabled: true, strategy: 'trim', maxTokens: 4096, preserveSystemPrompt: true, preserveLastMessages: 5 });
      const result = rt.applyCompression(10000, 10000);
      expect(result.isCompressed).assertTrue();
      expect(result.compressedTokens).assertEqual(4096);
    });
    it('估算 token 数', 0, () => {
      const rt = new PromptCompressionRuntime(new EventBus());
      const tokens = rt.estimateTokens('hello world this is a test');
      expect(tokens > 0).assertTrue();
    });
    it('配置和事件结果不暴露内部对象', 0, () => {
      const bus = new EventBus();
      const rt = new PromptCompressionRuntime(bus);
      bus.subscribe<CompressionAppliedPayload>('prompt.compression.applied', (event: RuntimeEvent<CompressionAppliedPayload>) => {
        event.payload.result.compressedTokens = 1;
      });
      const config: CompressionConfig = { enabled: true, strategy: 'trim', maxTokens: 4096, preserveSystemPrompt: true, preserveLastMessages: 5 };
      rt.setConfig(config);
      config.maxTokens = 1;

      const saved = rt.getConfig();
      saved.maxTokens = 2;
      const result = rt.applyCompression(10000, 10000);

      expect(rt.getConfig().maxTokens).assertEqual(4096);
      expect(result.compressedTokens).assertEqual(4096);
    });
  });
}
