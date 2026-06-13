import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  StatsRuntime,
  type RuntimeEvent,
  type StatsGenerationSample,
  type StatsProviderErrorPayload,
  type StatsSnapshot,
  type StatsUpdatedPayload,
} from '../../Index';
import {
  type StatsCharacterRecord,
  type StatsTotals,
} from '../main/ets/stats/Index';

export default function statsUnitTest() {
  describe('stats runtime', () => {
    it('records token usage, chat length, and message counts', 0, () => {
      const bus = new EventBus();
      const runtime = new StatsRuntime(bus);
      const snapshots = new Array<StatsSnapshot>();
      bus.subscribe<StatsUpdatedPayload>('stats.updated', (event: RuntimeEvent<StatsUpdatedPayload>) => {
        snapshots.push(event.payload.snapshot);
      });

      runtime.recordTokenUsage('chat-a', 'openai', 12, 5);
      runtime.recordMessage('chat-a', 'user', 7, 24);
      runtime.recordMessage('chat-a', 'assistant', 9, 31);
      const snapshot: StatsSnapshot = runtime.getSnapshot();

      expect(snapshot.totalPromptTokens).assertEqual(12);
      expect(snapshot.totalCompletionTokens).assertEqual(5);
      expect(snapshot.totalTokens).assertEqual(17);
      expect(snapshot.totalMessages).assertEqual(2);
      expect(snapshot.userMessages).assertEqual(1);
      expect(snapshot.assistantMessages).assertEqual(1);
      expect(snapshot.totalChatBytes).assertEqual(55);
      expect(snapshot.chatStats.length).assertEqual(1);
      expect(snapshot.chatStats[0].chatId).assertEqual('chat-a');
      expect(snapshots.length).assertEqual(3);
    });

    it('tracks generation duration and provider error rate', 0, () => {
      const bus = new EventBus();
      const runtime = new StatsRuntime(bus);
      const providerErrors = new Array<string>();
      bus.subscribe<StatsProviderErrorPayload>('stats.provider.error', (event: RuntimeEvent<StatsProviderErrorPayload>) => {
        providerErrors.push(event.payload.providerId);
      });

      const sample: StatsGenerationSample = runtime.recordGeneration('openai', 1000, 1600, 20, 8);
      runtime.recordProviderRequest('openai', false);
      runtime.recordProviderRequest('openai', true);
      runtime.recordProviderRequest('openai', true);
      const snapshot = runtime.getSnapshot();

      expect(sample.durationMs).assertEqual(600);
      expect(snapshot.totalGenerations).assertEqual(1);
      expect(snapshot.totalGenerationTimeMs).assertEqual(600);
      expect(snapshot.providerStats.length).assertEqual(1);
      expect(snapshot.providerStats[0].providerId).assertEqual('openai');
      expect(snapshot.providerStats[0].requestCount).assertEqual(3);
      expect(snapshot.providerStats[0].errorCount).assertEqual(2);
      expect(snapshot.providerStats[0].errorRate).assertEqual(0.666667);
      expect(providerErrors.length).assertEqual(2);
    });

    it('tracks RAG hits and plugin errors', 0, () => {
      const runtime = new StatsRuntime(new EventBus());

      runtime.recordRagQuery('worldbook', true);
      runtime.recordRagQuery('worldbook', false);
      runtime.recordPluginError('plugin-a', 'hook failed');
      runtime.recordPluginError('plugin-a', 'tool failed');
      const snapshot = runtime.getSnapshot();

      expect(snapshot.ragStats.length).assertEqual(1);
      expect(snapshot.ragStats[0].queryCount).assertEqual(2);
      expect(snapshot.ragStats[0].hitCount).assertEqual(1);
      expect(snapshot.ragStats[0].hitRate).assertEqual(0.5);
      expect(snapshot.pluginStats.length).assertEqual(1);
      expect(snapshot.pluginStats[0].pluginId).assertEqual('plugin-a');
      expect(snapshot.pluginStats[0].errorCount).assertEqual(2);
      expect(snapshot.pluginStats[0].lastError).assertEqual('tool failed');
    });

    it('processes character message stats for frontend stats reports', 0, () => {
      const runtime = new StatsRuntime(new EventBus());

      runtime.processCharacterMessage({
        characterKey: 'char-a.png',
        message: 'hello brave world',
        isUser: false,
        processType: 'message',
        genStartedAt: 1000,
        genFinishedAt: 1600,
        now: 2000,
      });
      runtime.processCharacterMessage({
        characterKey: 'char-a.png',
        message: 'hello edited brave world',
        isUser: false,
        processType: 'continue',
        oldMessage: 'hello brave world',
        genStartedAt: 2000,
        genFinishedAt: 2300,
        now: 3000,
      });
      runtime.processCharacterMessage({
        characterKey: 'char-a.png',
        message: 'retry answer',
        isUser: false,
        processType: 'swipe',
        genStartedAt: 3000,
        genFinishedAt: 3300,
        now: 4000,
      });
      runtime.processCharacterMessage({
        characterKey: 'char-a.png',
        message: 'my prompt words',
        isUser: true,
        processType: 'message',
        now: 5000,
      });

      const character: StatsCharacterRecord = runtime.getCharacterStats('char-a.png');
      const totals: StatsTotals = runtime.getUserStatsTotals();

      expect(character.totalGenTime).assertEqual(1200);
      expect(character.nonUserMsgCount).assertEqual(2);
      expect(character.nonUserWordCount).assertEqual(6);
      expect(character.userMsgCount).assertEqual(1);
      expect(character.userWordCount).assertEqual(3);
      expect(character.totalSwipeCount).assertEqual(1);
      expect(character.dateFirstChat).assertEqual(2000);
      expect(character.dateLastChat).assertEqual(5000);
      expect(totals.nonUserMsgCount).assertEqual(2);
      expect(totals.totalSwipeCount).assertEqual(1);
    });
  });
}
