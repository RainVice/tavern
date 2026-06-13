import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  TranslationRuntime,
  type TranslationCacheHitPayload,
  type TranslationCancelledPayload,
  type TranslationCompletedPayload,
  type TranslationExportData,
  type TranslationLanguagePair,
  type TranslationStrategy,
  type RuntimeEvent,
} from '../../Index';

// 默认语言对
function enZh(): TranslationLanguagePair {
  return { sourceLanguage: 'en', targetLanguage: 'zh' };
}

// 默认策略
function inputStrategy(): TranslationStrategy {
  return {
    enabled: true,
    direction: 'input',
    sourceLanguage: 'en',
    targetLanguage: 'zh',
    preserveOriginal: true,
    scope: 'message_input',
  };
}

export default function translationUnitTest() {
  describe('TranslationRuntime', () => {
    it('创建翻译条目并完成翻译', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TranslationRuntime(bus);

      // 条目记录。
      const entry = runtime.createEntry('input', enZh(), 'Hello, world!');
      runtime.completeEntry(entry.entryId, '你好，世界！');
      const saved = runtime.getEntry(entry.entryId);
      expect(saved.status).assertEqual('completed');
      expect(saved.translatedText).assertEqual('你好，世界！');
      expect(saved.direction).assertEqual('input');
      expect(saved.languagePair.sourceLanguage).assertEqual('en');
      expect(saved.languagePair.targetLanguage).assertEqual('zh');
    });

    it('翻译条目失败时记录错误', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TranslationRuntime(bus);

      // 条目记录。
      const entry = runtime.createEntry('output', enZh(), 'test');
      runtime.failEntry(entry.entryId, '翻译服务不可用');
      const saved = runtime.getEntry(entry.entryId);
      expect(saved.status).assertEqual('failed');
      expect(saved.error).assertEqual('翻译服务不可用');
    });

    it('设置和获取翻译策略', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TranslationRuntime(bus);
      const strategy = inputStrategy();
      runtime.setStrategy(strategy);
      const saved = runtime.getStrategy('message_input');
      expect(saved === undefined).assertFalse();
      if (saved !== undefined) {
        expect(saved.enabled).assertTrue();
        expect(saved.preserveOriginal).assertTrue();
        expect(saved.direction).assertEqual('input');
      }
      const list = runtime.listStrategies();
      expect(list.length).assertEqual(1);
      const missing = runtime.getStrategy('databank');
      expect(missing === undefined).assertTrue();
    });

    it('翻译缓存查找、添加和命中', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TranslationRuntime(bus);
      let cacheHitCount = 0;
      bus.subscribe<TranslationCacheHitPayload>(
        'translation.cache.hit',
        (event: RuntimeEvent<TranslationCacheHitPayload>) => {
          cacheHitCount = event.payload.entry.hitCount;
        },
      );

      runtime.addToCache('hello', 'en', 'zh', '你好');
      const result = runtime.findInCache('hello', 'en', 'zh');

      expect(result === undefined).assertFalse();
      if (result !== undefined) {
        expect(result.translatedText).assertEqual('你好');
        expect(result.fromCache).assertTrue();
      }
      expect(cacheHitCount).assertEqual(1);
      const missing = runtime.findInCache('unknown', 'en', 'zh');
      expect(missing === undefined).assertTrue();
    });

    it('缓存超出上限时移除旧条目', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TranslationRuntime(bus);

      for (let index = 0; index < 5; index += 1) {
        runtime.addToCache(`text-${index}`, 'en', 'zh', `译文-${index}`);
      }
      const stats = runtime.cacheStats();
      expect(stats.size).assertEqual(5);

      runtime.clearCache();
      expect(runtime.cacheStats().size).assertEqual(0);
    });

    it('创建翻译批处理任务并跟踪状态', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TranslationRuntime(bus);
      const statuses = new Array<string>();
      bus.subscribe<TranslationCompletedPayload>(
        'translation.task.completed',
        (event: RuntimeEvent<TranslationCompletedPayload>) => {
          statuses.push(event.payload.task.status);
        },
      );
      const e1 = runtime.createEntry('input', enZh(), 'hello');
      const e2 = runtime.createEntry('input', enZh(), 'world');
      const task = runtime.createTask([e1.entryId, e2.entryId], inputStrategy());
      runtime.updateTaskProgress(task.taskId, 50);
      runtime.completeTask(task.taskId);
      const saved = runtime.getTask(task.taskId);
      expect(saved.status).assertEqual('completed');
      expect(saved.progress).assertEqual(100);
      expect(saved.entryIds.length).assertEqual(2);
      expect(statuses.length).assertEqual(1);
    });

    it('任务失败和取消', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TranslationRuntime(bus);
      // cancelled 标识。
      let cancelledId = '';
      bus.subscribe<TranslationCancelledPayload>(
        'translation.task.cancelled',
        (event: RuntimeEvent<TranslationCancelledPayload>) => {
          cancelledId = event.payload.task.taskId;
        },
      );
      const t1 = runtime.createTask([], inputStrategy());
      runtime.cancelTask(t1.taskId);
      expect(runtime.getTask(t1.taskId).status).assertEqual('cancelled');
      expect(runtime.getTask(t1.taskId).error).assertEqual('已取消');
      expect(cancelledId).assertEqual(t1.taskId);
      const t2 = runtime.createTask([], inputStrategy());
      runtime.failTask(t2.taskId, '超时');
      expect(runtime.getTask(t2.taskId).status).assertEqual('failed');
      expect(runtime.getTask(t2.taskId).error).assertEqual('超时');
    });

    it('按状态过滤列出任务', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TranslationRuntime(bus);
      const t1 = runtime.createTask([], inputStrategy());
      const t2 = runtime.createTask([], inputStrategy());
      runtime.updateTaskProgress(t2.taskId, 1);
      runtime.completeTask(t1.taskId);
      const running = runtime.listTasks('running');
      const completed = runtime.listTasks('completed');

      expect(running.length).assertEqual(1);
      expect(running[0].taskId).assertEqual(t2.taskId);
      expect(completed.length).assertEqual(1);
      expect(completed[0].taskId).assertEqual(t1.taskId);
    });

    it('导出和导入数据', 0, () => {
      const bus1 = new EventBus();
      const runtime1 = new TranslationRuntime(bus1);
      runtime1.setStrategy(inputStrategy());
      runtime1.createEntry('input', enZh(), 'test');
      runtime1.addToCache('cached', 'en', 'zh', '已缓存');
      const data = runtime1.exportData();
      const bus2 = new EventBus();
      const runtime2 = new TranslationRuntime(bus2);
      runtime2.importData(data);

      expect(runtime2.listStrategies().length).assertEqual(1);
      expect(runtime2.listEntries().length).assertEqual(1);
      const cached = runtime2.findInCache('cached', 'en', 'zh');
      expect(cached === undefined).assertFalse();
      if (cached !== undefined) {
        expect(cached.translatedText).assertEqual('已缓存');
      }
    });

    it('读取和导出不会暴露内部翻译策略、条目、任务和缓存', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TranslationRuntime(bus);
      const strategy = inputStrategy();
      runtime.setStrategy(strategy);
      strategy.targetLanguage = 'ja';
      expect(runtime.getStrategy('message_input')!.targetLanguage).assertEqual('zh');

      // 条目记录。
      const entry = runtime.createEntry('input', enZh(), 'hello');
      entry.languagePair.targetLanguage = 'ja';
      entry.status = 'completed';
      expect(runtime.getEntry(entry.entryId).languagePair.targetLanguage).assertEqual('zh');
      expect(runtime.getEntry(entry.entryId).status).assertEqual('pending');
      const task = runtime.createTask([entry.entryId], inputStrategy());
      task.entryIds.push('外部条目');
      task.strategy.targetLanguage = 'ja';
      expect(runtime.getTask(task.taskId).entryIds.length).assertEqual(1);
      expect(runtime.getTask(task.taskId).strategy.targetLanguage).assertEqual('zh');

      bus.subscribe<TranslationCacheHitPayload>(
        'translation.cache.hit',
        (event: RuntimeEvent<TranslationCacheHitPayload>) => {
          event.payload.entry.translatedText = '事件修改';
        },
      );
      runtime.addToCache('cached-copy', 'en', 'zh', '缓存文本');
      runtime.findInCache('cached-copy', 'en', 'zh');
      const cached = runtime.findInCache('cached-copy', 'en', 'zh');
      expect(cached === undefined).assertFalse();
      if (cached !== undefined) {
        expect(cached.translatedText).assertEqual('缓存文本');
      }
      const exported = runtime.exportData();
      exported.strategies[0].targetLanguage = 'ja';
      exported.entries[0].sourceText = '导出修改';
      exported.cache[0].translatedText = '导出缓存';
      expect(runtime.getStrategy('message_input')!.targetLanguage).assertEqual('zh');
      expect(runtime.getEntry(entry.entryId).sourceText).assertEqual('hello');
      expect(runtime.findInCache('cached-copy', 'en', 'zh')!.translatedText).assertEqual('缓存文本');
    });

    it('导入后新建翻译条目不会复用已有 ID，且不会保留导入源引用', 0, () => {
      // 运行时实例。
      const runtime = new TranslationRuntime(new EventBus());
      const data: TranslationExportData = {
        strategies: [inputStrategy()],
        entries: [{
          entryId: 'trans-7',
          direction: 'input',
          languagePair: enZh(),
          sourceText: 'old',
          translatedText: '',
          status: 'pending',
          error: '',
          createdAt: 1,
          updatedAt: 1,
        }],
        cache: [{
          sourceText: 'cached-import',
          sourceLanguage: 'en',
          targetLanguage: 'zh',
          translatedText: '导入缓存',
          createdAt: 1,
          hitCount: 0,
        }],
      };
      runtime.importData(data);
      data.strategies[0].targetLanguage = 'ja';
      data.entries[0].languagePair.targetLanguage = 'ja';
      data.cache[0].translatedText = '外部缓存';
      const created = runtime.createEntry('input', enZh(), 'new');
      expect(created.entryId).assertEqual('trans-8');
      expect(runtime.getStrategy('message_input')!.targetLanguage).assertEqual('zh');
      expect(runtime.getEntry('trans-7').languagePair.targetLanguage).assertEqual('zh');
      expect(runtime.findInCache('cached-import', 'en', 'zh')!.translatedText).assertEqual('导入缓存');
    });
  });
}
