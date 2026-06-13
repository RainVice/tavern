import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  ReasoningRuntime,
  StreamingRuntime,
  type ReasoningDeltaPayload,
  type ReasoningRecord,
  type RuntimeEvent,
  type StreamStartParams,
} from '../../Index';

export default function reasoningUnitTest() {
  describe('reasoning runtime', () => {
    it('accumulates reasoning stream deltas and emits display events', 0, async () => {
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
      const reasoning = new ReasoningRuntime(bus);
      reasoning.startStreamingAccumulator();
      const snapshots = new Array<string>();
      bus.subscribe<ReasoningDeltaPayload>('reasoning.delta', (event: RuntimeEvent<ReasoningDeltaPayload>) => {
        snapshots.push(event.payload.reasoning.snapshot);
      });
      const startParams: StreamStartParams = {
        taskId: 'task-reasoning-1',
        chatId: 'chat-1',
        messageId: 'msg-1',
      };

      const session = streaming.startStream(startParams);
      await streaming.applyDelta(session.id, 'Think ', true);
      await streaming.applyDelta(session.id, 'step', true);
      await streaming.applyDelta(session.id, 'visible text', false);
      const record: ReasoningRecord = reasoning.getReasoning('msg-1');

      expect(record.snapshot).assertEqual('Think step');
      expect(record.visible).assertTrue();
      expect(record.includeInPrompt).assertFalse();
      expect(snapshots.length).assertEqual(2);
      expect(snapshots[1]).assertEqual('Think step');
    });

    it('tracks metadata, signature, visibility, and prompt policy', 0, () => {
      const bus = new EventBus();
      const reasoning = new ReasoningRuntime(bus);

      reasoning.editReasoning('msg-2', 'private chain');
      reasoning.setMetadata('msg-2', '{"provider":"openai"}', 'sig-1');
      reasoning.setVisibility('msg-2', false);
      reasoning.setPromptPolicy('msg-2', true);
      const record: ReasoningRecord = reasoning.getReasoning('msg-2');

      expect(record.snapshot).assertEqual('private chain');
      expect(record.metadataJson).assertEqual('{"provider":"openai"}');
      expect(record.signature).assertEqual('sig-1');
      expect(record.visible).assertFalse();
      expect(record.includeInPrompt).assertTrue();
      expect(reasoning.copyReasoning('msg-2')).assertEqual('private chain');
      expect(reasoning.formatForPrompt('msg-2')).assertContain('private chain');

      reasoning.setPromptPolicy('msg-2', false);
      expect(reasoning.formatForPrompt('msg-2')).assertEqual('');
    });

    it('does not expose internal reasoning records', 0, () => {
      const bus = new EventBus();
      const reasoning = new ReasoningRuntime(bus);
      bus.subscribe<ReasoningDeltaPayload>('reasoning.delta', (event: RuntimeEvent<ReasoningDeltaPayload>) => {
        event.payload.reasoning.snapshot = '事件修改';
      });

      const record = reasoning.applyDelta('msg-copy', 'private');
      record.snapshot = '外部修改';
      expect(reasoning.getReasoning('msg-copy').snapshot).assertEqual('private');

      const listed = reasoning.listReasoning();
      listed[0].snapshot = '列表修改';
      expect(reasoning.getReasoning('msg-copy').snapshot).assertEqual('private');
    });

    it('does not reuse reasoning delta payload across event names', 0, () => {
      const bus = new EventBus();
      const reasoning = new ReasoningRuntime(bus);
      const snapshots = new Array<string>();
      bus.subscribe<ReasoningDeltaPayload>('reasoning.delta', (event: RuntimeEvent<ReasoningDeltaPayload>) => {
        event.payload.reasoning.snapshot = 'first-event-mutated';
      });
      bus.subscribe<ReasoningDeltaPayload>('message.reasoning.delta', (event: RuntimeEvent<ReasoningDeltaPayload>) => {
        snapshots.push(event.payload.reasoning.snapshot);
      });

      reasoning.applyDelta('msg-cross-event', 'clean');

      expect(snapshots.length).assertEqual(1);
      expect(snapshots[0]).assertEqual('clean');
    });
  });
}
