import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  EmbeddingRuntime,
  type EmbeddingExportData,
  type EmbeddingResult,
  type EmbeddingResultPayload,
  type RuntimeEvent,
} from '../../Index';

export default function embeddingUnitTest() {
  describe('EmbeddingRuntime', () => {
    it('注册和列出模型', 0, () => {
      const bus = new EventBus();
      const runtime = new EmbeddingRuntime(bus);
      runtime.registerModel('openai', 'text-embedding-3-small', 1536, 'OpenAI v3 small');
      runtime.registerModel('ollama', 'nomic-embed-text', 768, 'Nomic Embed');
      runtime.registerModel('cohere', 'embed-english-v3', 1024, 'Cohere v3');

      expect(runtime.listModels().length).assertEqual(3);
      expect(runtime.listModels('openai').length).assertEqual(1);
      expect(runtime.listModels('ollama').length).assertEqual(1);
    });

    it('检查维度匹配', 0, () => {
      const bus = new EventBus();
      const runtime = new EmbeddingRuntime(bus);
      runtime.registerModel('openai', 'ada', 1536, 'Ada');
      expect(runtime.checkDimension('openai:ada', 1536)).assertTrue();
      expect(runtime.checkDimension('openai:ada', 768)).assertFalse();
    });

    it('构建各提供商请求', 0, () => {
      const bus = new EventBus();
      const runtime = new EmbeddingRuntime(bus);
      const oai = runtime.buildOpenAIRequest('ada', ['hello']);
      expect(oai.model).assertEqual('ada');
      expect(oai.encoding_format).assertEqual('float');

      const ollama = runtime.buildOllamaRequest('nomic', 'hello');
      expect(ollama.model).assertEqual('nomic');

      const cohere = runtime.buildCohereRequest('embed-v3', ['hello']);
      expect(cohere.input_type).assertEqual('search_document');
    });

    it('导出和导入', 0, () => {
      const bus = new EventBus();
      const rt = new EmbeddingRuntime(bus);
      rt.registerModel('openai', 'ada', 1536, '');
      const data = rt.exportData();
      const rt2 = new EmbeddingRuntime(new EventBus());
      rt2.importData(data);
      expect(rt2.listModels().length).assertEqual(1);
    });

    it('读取、列表和导出不会暴露内部模型', 0, () => {
      const rt = new EmbeddingRuntime(new EventBus());
      const model = rt.registerModel('openai', 'safe', 1536, '原始描述');
      model.dimensions = 1;
      model.enabled = false;
      expect(rt.checkDimension('openai:safe', 1536)).assertTrue();

      const listed = rt.listModels();
      listed[0].description = '列表修改';
      expect(rt.getModel('openai:safe').description).assertEqual('原始描述');

      const exported = rt.exportData();
      exported.models[0].enabled = false;
      expect(rt.getModel('openai:safe').enabled).assertTrue();
    });

    it('导入数据不会保留外部模型引用', 0, () => {
      const rt = new EmbeddingRuntime(new EventBus());
      const data: EmbeddingExportData = {
        models: [{
          modelId: 'local_http:demo',
          provider: 'local_http',
          modelName: 'demo',
          dimensions: 8,
          description: '导入模型',
          enabled: true,
        }],
      };
      rt.importData(data);
      data.models[0].dimensions = 1;
      expect(rt.checkDimension('local_http:demo', 8)).assertTrue();
    });

    it('保存向量结果事件不会暴露调用方对象', 0, () => {
      const bus = new EventBus();
      const rt = new EmbeddingRuntime(bus);
      bus.subscribe<EmbeddingResultPayload>('embedding.result', (event: RuntimeEvent<EmbeddingResultPayload>) => {
        event.payload.result.vectors[0][0] = 99;
        event.payload.result.model = 'event-mutated';
      });
      const result: EmbeddingResult = {
        provider: 'openai',
        model: 'text-embedding-3-small',
        vectors: [[0.1, 0.2]],
        dimensions: 2,
        usageTokens: 3,
      };

      rt.saveResult(result);

      expect(result.model).assertEqual('text-embedding-3-small');
      expect(result.vectors[0][0]).assertEqual(0.1);
    });
  });
}
