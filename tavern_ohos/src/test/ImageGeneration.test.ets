import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  ImageGenerationRuntime,
  type ImageGenerationBackend,
  type ImageGenerationCancelledPayload,
  type ImageGenerationCompletedPayload,
  type ImageGenerationExportData,
  type ImageGenerationFailedPayload,
  type ImageGenerationMetadata,
  type ImageGenerationParams,
  type ImageGenerationProgressPayload,
  type ImageGenerationStartedPayload,
  type RuntimeEvent,
} from '../../Index';

/**
 * 构建默认图片生成参数。
 * @param backend 图片生成后端类型。
 * @returns 默认图片生成参数。
 */
function defaultParams(backend: ImageGenerationBackend): ImageGenerationParams {
  return {
    backend: backend,
    prompt: '测试提示词',
    negativePrompt: '测试负面提示词',
    width: 512,
    height: 512,
    steps: 20,
    cfg: 7,
    seed: 42,
    sampler: 'Euler a',
    batchSize: 1,
  };
}

export default function imageGenerationUnitTest() {
  describe('ImageGenerationRuntime', () => {
    it('发起生成任务并跟踪状态变化', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(bus);
      const statuses = new Array<string>();
      bus.subscribe<ImageGenerationStartedPayload>(
        'image.generation.started',
        (event: RuntimeEvent<ImageGenerationStartedPayload>) => {
          statuses.push(event.payload.task.status);
        },
      );
      bus.subscribe<ImageGenerationProgressPayload>(
        'image.generation.progress',
        (event: RuntimeEvent<ImageGenerationProgressPayload>) => {
          statuses.push(event.payload.task.status);
        },
      );
      bus.subscribe<ImageGenerationCompletedPayload>(
        'image.generation.completed',
        (event: RuntimeEvent<ImageGenerationCompletedPayload>) => {
          statuses.push(event.payload.task.status);
        },
      );
      const task = runtime.generateImage(defaultParams('sd_webui'));
      runtime.updateProgress(task.taskId, 50);
      const metadata: ImageGenerationMetadata = { model: 'sd-v1.5' };
      runtime.completeGeneration(task.taskId, ['att-1', 'att-2'], metadata);
      const saved = runtime.getTask(task.taskId);
      expect(saved.status).assertEqual('completed');
      expect(saved.progress).assertEqual(100);
      expect(saved.resultAttachmentIds.length).assertEqual(2);
      expect(saved.resultAttachmentIds[0]).assertEqual('att-1');
      expect(saved.metadata.model).assertEqual('sd-v1.5');
      expect(statuses[0]).assertEqual('pending');
      expect(statuses[1]).assertEqual('running');
      expect(statuses[2]).assertEqual('completed');
    });

    it('任务失败时记录错误并发布事件', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(bus);
      let failedPayload: ImageGenerationFailedPayload | undefined = undefined;
      bus.subscribe<ImageGenerationFailedPayload>(
        'image.generation.failed',
        (event: RuntimeEvent<ImageGenerationFailedPayload>) => {
          failedPayload = event.payload;
        },
      );
      const task = runtime.generateImage(defaultParams('comfyui'));
      runtime.failGeneration(task.taskId, '显存不足');
      const saved = runtime.getTask(task.taskId);
      expect(saved.status).assertEqual('failed');
      expect(saved.error).assertEqual('显存不足');
      expect(failedPayload === undefined).assertFalse();
    });

    it('取消生成任务并发布取消事件', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(bus);
      let cancelled = false;
      bus.subscribe<ImageGenerationCancelledPayload>(
        'image.generation.cancelled',
        (event: RuntimeEvent<ImageGenerationCancelledPayload>) => {
          cancelled = event.payload.task.status === 'cancelled';
        },
      );
      const task = runtime.generateImage(defaultParams('openai_image'));
      runtime.cancelGeneration(task.taskId);
      const saved = runtime.getTask(task.taskId);
      expect(saved.status).assertEqual('cancelled');
      expect(saved.error).assertEqual('已取消');
      expect(cancelled).assertTrue();
    });

    it('按状态过滤列出任务', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(bus);
      const t1 = runtime.generateImage(defaultParams('sd_webui'));
      const t2 = runtime.generateImage(defaultParams('comfyui'));
      runtime.updateProgress(t2.taskId, 1);
      runtime.completeGeneration(t1.taskId, [], {});
      const running = runtime.listTasks('running');
      const completed = runtime.listTasks('completed');

      expect(running.length).assertEqual(1);
      expect(running[0].taskId).assertEqual(t2.taskId);
      expect(completed.length).assertEqual(1);
      expect(completed[0].taskId).assertEqual(t1.taskId);
    });

    it('清理已完成任务, 保留进行中的任务', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(bus);
      const t1 = runtime.generateImage(defaultParams('sd_webui'));
      const t2 = runtime.generateImage(defaultParams('comfyui'));
      runtime.updateProgress(t2.taskId, 1);
      runtime.completeGeneration(t1.taskId, [], {});
      runtime.cleanupTask(t1.taskId);
      runtime.cleanupTask(t2.taskId);

      { let t=false; try { runtime.getTask(t1.taskId); } catch(e) { t=true; } expect(t).assertTrue(); };
      const saved = runtime.getTask(t2.taskId);
      expect(saved.status).assertEqual('running');
    });

    it('保存、加载和删除预设', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(bus);

      runtime.savePreset('高清预设', defaultParams('sd_webui'));
      const list = runtime.listPresets();
      expect(list.length).assertEqual(1);
      expect(list[0].name).assertEqual('高清预设');
      expect(list[0].params.width).assertEqual(512);
      const loaded = runtime.loadPreset(list[0].presetId);
      expect(loaded.prompt).assertEqual('测试提示词');

      runtime.deletePreset(list[0].presetId);
      expect(runtime.listPresets().length).assertEqual(0);
    });

    it('构建 SD WebUI 请求体', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(bus);

      // 调用参数。
      const params = defaultParams('sd_webui');
      const req = runtime.buildSdWebUIRequest(params);

      expect(req.prompt).assertEqual('测试提示词');
      expect(req.negative_prompt).assertEqual('测试负面提示词');
      expect(req.width).assertEqual(512);
      expect(req.height).assertEqual(512);
      expect(req.steps).assertEqual(20);
      expect(req.cfg_scale).assertEqual(7);
      expect(req.seed).assertEqual(42);
      expect(req.sampler_name).assertEqual('Euler a');
      expect(req.batch_size).assertEqual(1);
    });

    it('构建 OpenAI 图片请求体', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(bus);
      const req = runtime.buildOpenAIImageRequest('画一只猫', 'dall-e-3', 1, '1024x1024');

      expect(req.model).assertEqual('dall-e-3');
      expect(req.prompt).assertEqual('画一只猫');
      expect(req.n).assertEqual(1);
      expect(req.size).assertEqual('1024x1024');
      expect(req.response_format).assertEqual('b64_json');
    });

    it('构建 Workers AI 请求体', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(bus);

      // 调用参数。
      const params = defaultParams('workers_ai');
      const req = runtime.buildWorkersAIRequest(params);

      expect(req.prompt).assertEqual('测试提示词');
      expect(req.width).assertEqual(512);
      expect(req.num_steps).assertEqual(20);
      expect(req.guidance).assertEqual(7);
    });

    it('导出和导入数据', 0, () => {
      const bus1 = new EventBus();
      const runtime1 = new ImageGenerationRuntime(bus1);
      runtime1.savePreset('导出测试', defaultParams('sd_webui'));
      runtime1.generateImage(defaultParams('comfyui'));
      const data = runtime1.exportData();
      const bus2 = new EventBus();
      const runtime2 = new ImageGenerationRuntime(bus2);
      runtime2.importData(data);

      expect(runtime2.listPresets().length).assertEqual(1);
      expect(runtime2.listTasks().length).assertEqual(1);
    });

    it('读取和导出不会暴露内部图片生成任务与预设', 0, () => {
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(new EventBus());
      const preset = runtime.savePreset('原始预设', defaultParams('sd_webui'));
      preset.params.prompt = '外部预设';
      expect(runtime.loadPreset(preset.presetId).prompt).assertEqual('测试提示词');
      const task = runtime.generateImage(defaultParams('openai_image'));
      const metadata: ImageGenerationMetadata = { model: 'dall-e-3', seed: '42' };
      const completed = runtime.completeGeneration(task.taskId, ['att-1'], metadata);
      metadata.model = '外部模型';
      completed.resultAttachmentIds.push('外部附件');
      completed.metadata.seed = '0';
      const saved = runtime.getTask(task.taskId);
      expect(saved.resultAttachmentIds.length).assertEqual(1);
      expect(saved.metadata.model).assertEqual('dall-e-3');
      expect(saved.metadata.seed).assertEqual('42');
      const exported = runtime.exportData();
      exported.presets[0].params.prompt = '导出预设';
      exported.tasks[0].metadata.model = '导出模型';
      exported.tasks[0].resultAttachmentIds.push('导出附件');
      expect(runtime.loadPreset(preset.presetId).prompt).assertEqual('测试提示词');
      expect(runtime.getTask(task.taskId).metadata.model).assertEqual('dall-e-3');
      expect(runtime.getTask(task.taskId).resultAttachmentIds.length).assertEqual(1);
    });

    it('导入后新建图片生成任务与预设不会复用已有 ID', 0, () => {
      // 运行时实例。
      const runtime = new ImageGenerationRuntime(new EventBus());
      const data: ImageGenerationExportData = {
        presets: [{
          presetId: 'img-preset-4',
          name: '导入预设',
          params: defaultParams('sd_webui'),
          createdAt: 1,
          updatedAt: 1,
        }],
        tasks: [{
          taskId: 'img-gen-5',
          backend: 'workers_ai',
          params: defaultParams('workers_ai'),
          status: 'pending',
          progress: 0,
          resultAttachmentIds: [],
          error: '',
          metadata: { model: 'worker' },
          createdAt: 1,
          updatedAt: 1,
        }],
      };
      runtime.importData(data);
      data.presets[0].params.prompt = '外部预设';
      data.tasks[0].params.prompt = '外部任务';
      const preset = runtime.savePreset('新预设', defaultParams('sd_webui'));
      const task = runtime.generateImage(defaultParams('workers_ai'));
      expect(preset.presetId).assertEqual('img-preset-5');
      expect(task.taskId).assertEqual('img-gen-6');
      expect(runtime.loadPreset('img-preset-4').prompt).assertEqual('测试提示词');
      expect(runtime.getTask('img-gen-5').params.prompt).assertEqual('测试提示词');
    });
  });
}
