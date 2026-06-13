import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus, ImageCaptionRuntime,
  type CaptionCompletedPayload, type CaptionExportData, type CaptionStartedPayload, type RuntimeEvent,
} from '../../Index';

export default function imageCaptionUnitTest() {
  describe('ImageCaptionRuntime', () => {
    it('发起 caption 并跟踪状态', 0, () => {
      const bus = new EventBus();
      const runtime = new ImageCaptionRuntime(bus);
      const statuses = new Array<string>();
      bus.subscribe<CaptionStartedPayload>('caption.started', (e: RuntimeEvent<CaptionStartedPayload>) => { statuses.push(e.payload.task.status); });
      bus.subscribe<CaptionCompletedPayload>('caption.completed', (e: RuntimeEvent<CaptionCompletedPayload>) => { statuses.push(e.payload.task.status); });

      const task = runtime.startCaption({ imageAttachmentId: 'img-1', provider: 'openai_vision', prompt: '描述这张图片', model: 'gpt-4o', autoCaption: true });
      runtime.updateProgress(task.taskId, 50);
      runtime.completeCaption(task.taskId, { taskId: task.taskId, text: '一只猫坐在窗台上', attachmentId: 'cap-1' });

      const saved = runtime.getTask(task.taskId);
      expect(saved.status).assertEqual('completed');
      expect(saved.resultText).assertEqual('一只猫坐在窗台上');
      expect(saved.resultAttachmentId).assertEqual('cap-1');
      expect(saved.params.autoCaption).assertTrue();
      expect(statuses[0]).assertEqual('pending');
      expect(statuses[1]).assertEqual('completed');
    });

    it('caption 失败和取消', 0, () => {
      const bus = new EventBus();
      const runtime = new ImageCaptionRuntime(bus);
      const t1 = runtime.startCaption({ imageAttachmentId: 'img-2', provider: 'openai_vision', prompt: '', model: 'gpt-4o', autoCaption: false });
      runtime.cancelCaption(t1.taskId);
      expect(runtime.getTask(t1.taskId).status).assertEqual('cancelled');

      const t2 = runtime.startCaption({ imageAttachmentId: 'img-3', provider: 'local', prompt: '', model: 'local', autoCaption: false });
      runtime.failCaption(t2.taskId, '模型不可用');
      expect(runtime.getTask(t2.taskId).error).assertEqual('模型不可用');
    });

    it('构建 Vision 请求', 0, () => {
      const bus = new EventBus();
      const runtime = new ImageCaptionRuntime(bus);
      const req = runtime.buildVisionRequest('gpt-4o', 'https://example.com/img.png', '这是什么');
      expect(req.model).assertEqual('gpt-4o');
    });

    it('按状态过滤任务', 0, () => {
      const bus = new EventBus();
      const runtime = new ImageCaptionRuntime(bus);
      const t1 = runtime.startCaption({ imageAttachmentId: 'a', provider: 'openai_vision', prompt: '', model: '', autoCaption: false });
      const t2 = runtime.startCaption({ imageAttachmentId: 'b', provider: 'openai_vision', prompt: '', model: '', autoCaption: false });
      runtime.updateProgress(t2.taskId, 1);
      runtime.completeCaption(t1.taskId, { taskId: t1.taskId, text: 'done', attachmentId: '' });
      expect(runtime.listTasks('completed').length).assertEqual(1);
      expect(runtime.listTasks('running').length).assertEqual(1);
    });

    it('导出和导入', 0, () => {
      const bus1 = new EventBus();
      const runtime1 = new ImageCaptionRuntime(bus1);
      runtime1.startCaption({ imageAttachmentId: 'x', provider: 'openai_vision', prompt: '', model: '', autoCaption: false });
      const data = runtime1.exportData();
      const bus2 = new EventBus();
      const runtime2 = new ImageCaptionRuntime(bus2);
      runtime2.importData(data);
      expect(runtime2.listTasks().length).assertEqual(1);
    });

    it('读取和导出不会暴露内部 caption 任务', 0, () => {
      const runtime = new ImageCaptionRuntime(new EventBus());
      const task = runtime.startCaption({ imageAttachmentId: 'img-1', provider: 'openai_vision', prompt: '描述', model: 'gpt-4o', autoCaption: true });
      task.status = 'completed';
      task.params.prompt = '外部修改';

      expect(runtime.getTask(task.taskId).status).assertEqual('pending');
      expect(runtime.getTask(task.taskId).params.prompt).assertEqual('描述');

      const exported = runtime.exportData();
      exported.tasks[0].resultText = '导出修改';
      exported.tasks[0].params.imageAttachmentId = 'changed';
      expect(runtime.getTask(task.taskId).resultText).assertEqual('');
      expect(runtime.getTask(task.taskId).params.imageAttachmentId).assertEqual('img-1');
    });

    it('导入后新建 caption 任务不会复用已有 ID', 0, () => {
      const runtime = new ImageCaptionRuntime(new EventBus());
      const data: CaptionExportData = {
        tasks: [{
          taskId: 'caption-6',
          params: { imageAttachmentId: 'old', provider: 'local', prompt: '', model: 'local', autoCaption: false },
          status: 'pending',
          progress: 0,
          resultText: '',
          resultAttachmentId: '',
          error: '',
          createdAt: 1,
          updatedAt: 1,
        }],
      };
      runtime.importData(data);
      data.tasks[0].params.imageAttachmentId = 'mutated';
      const created = runtime.startCaption({ imageAttachmentId: 'new', provider: 'local', prompt: '', model: 'local', autoCaption: false });
      expect(created.taskId).assertEqual('caption-7');
      expect(runtime.getTask('caption-6').params.imageAttachmentId).assertEqual('old');
    });
  });
}
