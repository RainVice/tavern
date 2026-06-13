import { describe, it, expect } from '@ohos/hypium';
import { EventBus, SamplerRuntime } from '../../Index';

export default function samplerUnitTest() {
  describe('SamplerRuntime', () => {
    it('保存和加载采样器预设', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SamplerRuntime(bus);
      // 调用参数。
      const params = runtime.defaultParams();
      params.temperature = 0.8;

      runtime.savePreset('创作模式', params, [{ token: '你好', bias: 2 }]);
      params.temperature = 1.5;
      const list = runtime.listPresets();
      list[0].params.temperature = 0.1;
      const saved = runtime.getPreset(list[0].presetId);
      expect(list.length).assertEqual(1);
      expect(list[0].name).assertEqual('创作模式');
      expect(list[0].logitBias.length).assertEqual(1);
      expect(saved.params.temperature).assertEqual(0.8);
    });

    it('构建 logit bias JSON', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SamplerRuntime(bus);
      // JSON 字符串。
      const json = runtime.buildLogitBiasJson([{ token: 'hello', bias: 1 }, { token: 'wo"rld', bias: -1 }]);
      expect(json).assertContain('"hello":1');
      expect(json).assertContain('"wo\\"rld":-1');
    });

    it('应用 CFG 缩放', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SamplerRuntime(bus);
      // 调用参数。
      const params = runtime.defaultParams();
      const scaled = runtime.applyCfgScale(params, 2.5);
      expect(scaled.cfg_scale).assertEqual(2.5);
    });

    it('导出和导入', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      const rt = new SamplerRuntime(bus);
      rt.savePreset('P', rt.defaultParams(), []);
      const data = rt.exportData();
      const rt2 = new SamplerRuntime(new EventBus());
      rt2.importData(data);
      expect(rt2.listPresets().length).assertEqual(1);
      const next = rt2.savePreset('P2', rt2.defaultParams(), []);
      expect(next.presetId).assertEqual('sampler-2');
    });
  });
}
