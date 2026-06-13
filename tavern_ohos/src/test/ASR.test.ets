import { describe, it, expect } from '@ohos/hypium';
import {
  ASRRuntime,
  EventBus,
  type ASRExportData,
  type ASRTranscriptionCompletedPayload,
  type ASRTranscriptionProgressPayload,
  type ASRTranscriptionStartedPayload,
  type RuntimeEvent,
} from '../../Index';

export default function asrUnitTest() {
  describe('ASRRuntime', () => {
    it('发起转录并跟踪状态', 0, () => {
      const bus = new EventBus();
      const runtime = new ASRRuntime(bus);
      const statuses = new Array<string>();
      bus.subscribe<ASRTranscriptionStartedPayload>('asr.transcription.started', (e: RuntimeEvent<ASRTranscriptionStartedPayload>) => { statuses.push(e.payload.task.status); });
      bus.subscribe<ASRTranscriptionProgressPayload>('asr.transcription.progress', (e: RuntimeEvent<ASRTranscriptionProgressPayload>) => { statuses.push(e.payload.task.status); });
      bus.subscribe<ASRTranscriptionCompletedPayload>('asr.transcription.completed', (e: RuntimeEvent<ASRTranscriptionCompletedPayload>) => { statuses.push(e.payload.task.status); });

      const task = runtime.startTranscription({ source: 'audio.mp3', provider: 'openai_whisper', language: 'zh', model: 'whisper-1', autoSend: true, prompt: '' });
      runtime.updateProgress(task.taskId, 50);
      runtime.completeTranscription(task.taskId, { taskId: task.taskId, transcript: '你好世界', confidence: 0.95, duration: 3.5, language: 'zh' });

      const saved = runtime.getTask(task.taskId);
      expect(saved.status).assertEqual('completed');
      expect(saved.transcript).assertEqual('你好世界');
      expect(saved.confidence).assertEqual(0.95);
      expect(saved.duration).assertEqual(3.5);
      expect(saved.params.autoSend).assertTrue();
      expect(statuses[0]).assertEqual('pending');
      expect(statuses[1]).assertEqual('running');
      expect(statuses[2]).assertEqual('completed');
    });

    it('转录失败和取消', 0, () => {
      const bus = new EventBus();
      const runtime = new ASRRuntime(bus);

      const t1 = runtime.startTranscription({ source: 'a.mp3', provider: 'system', language: 'en', model: '', autoSend: false, prompt: '' });
      runtime.cancelTranscription(t1.taskId);
      expect(runtime.getTask(t1.taskId).status).assertEqual('cancelled');
      expect(runtime.getTask(t1.taskId).error).assertEqual('已取消');

      const t2 = runtime.startTranscription({ source: 'b.mp3', provider: 'openai_whisper', language: 'en', model: 'whisper-1', autoSend: false, prompt: '' });
      runtime.failTranscription(t2.taskId, '音频格式不支持');
      expect(runtime.getTask(t2.taskId).status).assertEqual('failed');
      expect(runtime.getTask(t2.taskId).error).assertEqual('音频格式不支持');
    });

    it('按状态过滤任务', 0, () => {
      const bus = new EventBus();
      const runtime = new ASRRuntime(bus);
      const t1 = runtime.startTranscription({ source: 'a.mp3', provider: 'openai_whisper', language: 'zh', model: 'whisper-1', autoSend: false, prompt: '' });
      const t2 = runtime.startTranscription({ source: 'b.mp3', provider: 'system', language: 'en', model: '', autoSend: false, prompt: '' });
      runtime.updateProgress(t2.taskId, 1);
      runtime.completeTranscription(t1.taskId, { taskId: t1.taskId, transcript: 'ok', confidence: 1, duration: 1, language: 'zh' });

      expect(runtime.listTasks('running').length).assertEqual(1);
      expect(runtime.listTasks('completed').length).assertEqual(1);
    });

    it('构建 Whisper 请求', 0, () => {
      const bus = new EventBus();
      const runtime = new ASRRuntime(bus);
      const req = runtime.buildWhisperRequest('audio.mp3', 'whisper-1', 'zh', '转录提示');
      expect(req.model).assertEqual('whisper-1');
      expect(req.language).assertEqual('zh');
      expect(req.prompt).assertEqual('转录提示');
    });

    it('导出和导入', 0, () => {
      const bus1 = new EventBus();
      const runtime1 = new ASRRuntime(bus1);
      runtime1.startTranscription({ source: 'x.mp3', provider: 'openai_whisper', language: 'zh', model: 'whisper-1', autoSend: false, prompt: '' });
      const data = runtime1.exportData();
      const bus2 = new EventBus();
      const runtime2 = new ASRRuntime(bus2);
      runtime2.importData(data);
      expect(runtime2.listTasks().length).assertEqual(1);
    });

    it('读取和导出不会暴露内部转录任务', 0, () => {
      const runtime = new ASRRuntime(new EventBus());
      const task = runtime.startTranscription({ source: 'x.mp3', provider: 'openai_whisper', language: 'zh', model: 'whisper-1', autoSend: false, prompt: '' });
      task.status = 'completed';
      task.params.language = 'en';

      const saved = runtime.getTask(task.taskId);
      expect(saved.status).assertEqual('pending');
      expect(saved.params.language).assertEqual('zh');

      const exported = runtime.exportData();
      exported.tasks[0].status = 'failed';
      exported.tasks[0].params.source = 'changed.mp3';
      expect(runtime.getTask(task.taskId).status).assertEqual('pending');
      expect(runtime.getTask(task.taskId).params.source).assertEqual('x.mp3');
    });

    it('导入后新建转录任务不会复用已有 ID', 0, () => {
      const runtime = new ASRRuntime(new EventBus());
      const data: ASRExportData = {
        tasks: [{
          taskId: 'asr-4',
          params: { source: 'old.mp3', provider: 'system', language: 'zh', model: '', autoSend: false, prompt: '' },
          status: 'pending',
          progress: 0,
          transcript: '',
          confidence: 0,
          duration: 0,
          error: '',
          createdAt: 1,
          updatedAt: 1,
        }],
      };
      runtime.importData(data);
      data.tasks[0].params.source = 'mutated.mp3';
      const created = runtime.startTranscription({ source: 'new.mp3', provider: 'system', language: 'zh', model: '', autoSend: false, prompt: '' });
      expect(created.taskId).assertEqual('asr-5');
      expect(runtime.getTask('asr-4').params.source).assertEqual('old.mp3');
    });
  });
}
