import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  TTSRuntime,
  type TTSExportData,
  type TTSSynthesisCancelledPayload,
  type TTSSynthesisCompletedPayload,
  type TTSSynthesisProgressPayload,
  type TTSSynthesisStartedPayload,
  type RuntimeEvent,
} from '../../Index';

export default function ttsUnitTest() {
  describe('TTSRuntime', () => {
    it('发起语音合成并跟踪状态', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TTSRuntime(bus);
      const statuses = new Array<string>();
      bus.subscribe<TTSSynthesisStartedPayload>(
        'tts.synthesis.started',
        (event: RuntimeEvent<TTSSynthesisStartedPayload>) => {
          statuses.push(event.payload.task.status);
        },
      );
      bus.subscribe<TTSSynthesisProgressPayload>(
        'tts.synthesis.progress',
        (event: RuntimeEvent<TTSSynthesisProgressPayload>) => {
          statuses.push(event.payload.task.status);
        },
      );
      bus.subscribe<TTSSynthesisCompletedPayload>(
        'tts.synthesis.completed',
        (event: RuntimeEvent<TTSSynthesisCompletedPayload>) => {
          statuses.push(event.payload.task.status);
        },
      );
      const task = runtime.synthesize({
        text: '你好世界',
        voiceProfileId: 'profile-1',
        skipCodeBlocks: true,
        speed: 1.0,
        pitch: 1.0,
        format: 'mp3',
      });
      runtime.updateProgress(task.taskId, 50);
      runtime.completeSynthesis(task.taskId, { taskId: task.taskId, attachmentId: 'audio-1', duration: 3.5, format: 'mp3' });
      const saved = runtime.getTask(task.taskId);
      expect(saved.status).assertEqual('completed');
      expect(saved.progress).assertEqual(100);
      expect(saved.resultAttachmentId).assertEqual('audio-1');
      expect(saved.duration).assertEqual(3.5);
      expect(saved.params.text).assertEqual('你好世界');
      expect(saved.params.skipCodeBlocks).assertTrue();
      expect(statuses.length).assertEqual(3);
    });

    it('合成失败和取消', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TTSRuntime(bus);
      // cancelled 标识。
      let cancelledId = '';
      bus.subscribe<TTSSynthesisCancelledPayload>(
        'tts.synthesis.cancelled',
        (event: RuntimeEvent<TTSSynthesisCancelledPayload>) => {
          cancelledId = event.payload.task.taskId;
        },
      );
      const t1 = runtime.synthesize({
        text: 'test', voiceProfileId: 'p1', skipCodeBlocks: false, speed: 1.0, pitch: 1.0, format: 'wav',
      });
      runtime.cancelSynthesis(t1.taskId);
      expect(runtime.getTask(t1.taskId).status).assertEqual('cancelled');
      expect(runtime.getTask(t1.taskId).error).assertEqual('已取消');
      expect(cancelledId).assertEqual(t1.taskId);
      const t2 = runtime.synthesize({
        text: 'test', voiceProfileId: 'p1', skipCodeBlocks: false, speed: 1.0, pitch: 1.0, format: 'wav',
      });
      runtime.failSynthesis(t2.taskId, '网络错误');
      expect(runtime.getTask(t2.taskId).status).assertEqual('failed');
      expect(runtime.getTask(t2.taskId).error).assertEqual('网络错误');
    });

    it('按状态过滤列出任务', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TTSRuntime(bus);
      const t1 = runtime.synthesize({
        text: 'a', voiceProfileId: 'p1', skipCodeBlocks: false, speed: 1.0, pitch: 1.0, format: 'mp3',
      });
      const t2 = runtime.synthesize({
        text: 'b', voiceProfileId: 'p1', skipCodeBlocks: false, speed: 1.0, pitch: 1.0, format: 'mp3',
      });
      runtime.updateProgress(t2.taskId, 1);
      runtime.completeSynthesis(t1.taskId, { taskId: t1.taskId, attachmentId: 'a', duration: 1, format: 'mp3' });
      const running = runtime.listTasks('running');
      const completed = runtime.listTasks('completed');

      expect(running.length).assertEqual(1);
      expect(running[0].taskId).assertEqual(t2.taskId);
      expect(completed.length).assertEqual(1);
      expect(completed[0].taskId).assertEqual(t1.taskId);
    });

    it('保存、列出、删除语音配置', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TTSRuntime(bus);

      runtime.saveVoiceProfile('温柔女声', 'openai', 'nova', 'zh', 1.0, 1.0, 'mp3');
      runtime.saveVoiceProfile('磁性男声', 'openai', 'onyx', 'zh', 1.2, 0.9, 'mp3');
      runtime.saveVoiceProfile('Edge 女声', 'edge', 'zh-CN-XiaoxiaoNeural', 'zh', 1.0, 1.0, 'wav');
      const all = runtime.listVoiceProfiles();
      expect(all.length).assertEqual(3);
      const openaiVoices = runtime.listVoiceProfiles('openai');
      expect(openaiVoices.length).assertEqual(2);
      const edgeVoices = runtime.listVoiceProfiles('edge');
      expect(edgeVoices.length).assertEqual(1);
      expect(edgeVoices[0].voiceId).assertEqual('zh-CN-XiaoxiaoNeural');

      runtime.deleteVoiceProfile(all[0].profileId);
      expect(runtime.listVoiceProfiles().length).assertEqual(2);
    });

    it('构建 OpenAI TTS 请求体', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TTSRuntime(bus);
      const req = runtime.buildOpenAITTSRequest('你好', 'nova', 'tts-1', 1.0, 'mp3');

      expect(req.model).assertEqual('tts-1');
      expect(req.input).assertEqual('你好');
      expect(req.voice).assertEqual('nova');
      expect(req.speed).assertEqual(1.0);
      expect(req.response_format).assertEqual('mp3');
    });

    it('构建 Edge TTS 请求体', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TTSRuntime(bus);
      const req = runtime.buildEdgeTTSRequest('测试', 'zh-CN-XiaoxiaoNeural', 10, 0);

      expect(req.text).assertEqual('测试');
      expect(req.voice).assertEqual('zh-CN-XiaoxiaoNeural');
      expect(req.rate).assertEqual(10);
      expect(req.pitch).assertEqual(0);
    });

    it('导出和导入数据', 0, () => {
      const bus1 = new EventBus();
      const runtime1 = new TTSRuntime(bus1);
      runtime1.saveVoiceProfile('测试', 'openai', 'nova', 'zh', 1.0, 1.0, 'mp3');
      runtime1.synthesize({
        text: 'hello', voiceProfileId: 'p1', skipCodeBlocks: false, speed: 1.0, pitch: 1.0, format: 'mp3',
      });
      const data = runtime1.exportData();
      const bus2 = new EventBus();
      const runtime2 = new TTSRuntime(bus2);
      runtime2.importData(data);

      expect(runtime2.listVoiceProfiles().length).assertEqual(1);
      expect(runtime2.listTasks().length).assertEqual(1);
    });

    it('读取和导出不会暴露内部 TTS 任务与语音配置', 0, () => {
      // 运行时实例。
      const runtime = new TTSRuntime(new EventBus());
      const profile = runtime.saveVoiceProfile('测试', 'openai', 'nova', 'zh', 1.0, 1.0, 'mp3');
      profile.name = '外部配置';
      expect(runtime.getVoiceProfile(profile.profileId).name).assertEqual('测试');
      const task = runtime.synthesize({
        text: 'hello', voiceProfileId: profile.profileId, skipCodeBlocks: false, speed: 1.0, pitch: 1.0, format: 'mp3',
      });
      task.status = 'completed';
      task.params.text = '外部任务';
      expect(runtime.getTask(task.taskId).status).assertEqual('pending');
      expect(runtime.getTask(task.taskId).params.text).assertEqual('hello');
      const exported = runtime.exportData();
      exported.profiles[0].name = '导出配置';
      exported.tasks[0].params.text = '导出任务';
      expect(runtime.getVoiceProfile(profile.profileId).name).assertEqual('测试');
      expect(runtime.getTask(task.taskId).params.text).assertEqual('hello');
    });

    it('导入后新建 TTS 任务和语音配置不会复用已有 ID', 0, () => {
      // 运行时实例。
      const runtime = new TTSRuntime(new EventBus());
      const data: TTSExportData = {
        profiles: [{
          profileId: 'tts-profile-2',
          name: '导入配置',
          provider: 'edge',
          voiceId: 'voice',
          language: 'zh',
          speed: 1,
          pitch: 1,
          format: 'mp3',
          createdAt: 1,
          updatedAt: 1,
        }],
        tasks: [{
          taskId: 'tts-3',
          params: { text: 'old', voiceProfileId: 'tts-profile-2', skipCodeBlocks: false, speed: 1, pitch: 1, format: 'mp3' },
          status: 'pending',
          progress: 0,
          resultAttachmentId: '',
          duration: 0,
          error: '',
          createdAt: 1,
          updatedAt: 1,
        }],
      };
      runtime.importData(data);
      data.profiles[0].name = '外部修改';
      data.tasks[0].params.text = '外部修改';
      const profile = runtime.saveVoiceProfile('新配置', 'openai', 'nova', 'zh', 1, 1, 'mp3');
      const task = runtime.synthesize({
        text: 'new', voiceProfileId: profile.profileId, skipCodeBlocks: false, speed: 1, pitch: 1, format: 'mp3',
      });
      expect(profile.profileId).assertEqual('tts-profile-3');
      expect(task.taskId).assertEqual('tts-4');
      expect(runtime.getVoiceProfile('tts-profile-2').name).assertEqual('导入配置');
      expect(runtime.getTask('tts-3').params.text).assertEqual('old');
    });
  });
}
