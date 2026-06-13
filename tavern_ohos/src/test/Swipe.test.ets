import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  SwipeRuntime,
  type RuntimeEvent,
  type SwipeChangedPayload,
  type SwipeCreateParams,
  type SwipeRecord,
  type SwipeStreamState,
} from '../../Index';

export default function swipeUnitTest() {
  describe('swipe runtime', () => {
    it('creates, switches, edits, and deletes candidate swipes', 0, () => {
      const runtime = new SwipeRuntime(new EventBus());
      const first = runtime.createSwipe(makeSwipe('chat-1', 'msg-1', 'Hello'));
      const second = runtime.createSwipe(makeSwipe('chat-1', 'msg-1', 'Alternative'));

      const active = runtime.switchSwipe('chat-1', 'msg-1', second.index);
      const edited = runtime.editSwipe('chat-1', 'msg-1', second.index, 'Edited');
      runtime.deleteSwipe('chat-1', 'msg-1', first.index);
      const remaining: Array<SwipeRecord> = runtime.listSwipes('chat-1', 'msg-1');

      expect(first.index).assertEqual(0);
      expect(second.index).assertEqual(1);
      expect(active.text).assertEqual('Alternative');
      expect(edited.text).assertEqual('Edited');
      expect(remaining.length).assertEqual(1);
      expect(remaining[0].index).assertEqual(0);
      expect(runtime.getActiveSwipe('chat-1', 'msg-1').text).assertEqual('Edited');
    });

    it('regenerates streaming, failed, and interrupted swipes with events', 0, () => {
      const bus = new EventBus();
      const runtime = new SwipeRuntime(bus);
      const changed = new Array<string>();
      bus.subscribe<SwipeChangedPayload>('message.swipe.changed', (event: RuntimeEvent<SwipeChangedPayload>) => {
        changed.push(`${event.payload.messageId}:${event.payload.swipeIndex}:${event.payload.swipe.state}`);
      });

      const streaming: SwipeRecord = runtime.regenerateSwipe('chat-2', 'msg-2');
      runtime.appendStreamDelta('chat-2', 'msg-2', streaming.index, 'part ');
      const completed: SwipeRecord = runtime.completeStream('chat-2', 'msg-2', streaming.index, 'done');
      const failed: SwipeRecord = runtime.markFailed('chat-2', 'msg-2', 'model error');
      const interrupted: SwipeRecord = runtime.markInterrupted('chat-2', 'msg-2', 'partial');
      const states: Array<SwipeStreamState> = runtime.listStates('chat-2', 'msg-2');

      expect(completed.text).assertEqual('part done');
      expect(completed.state).assertEqual('complete');
      expect(failed.state).assertEqual('failed');
      expect(failed.error).assertEqual('model error');
      expect(interrupted.state).assertEqual('interrupted');
      expect(states.length).assertEqual(3);
      expect(changed.length).assertEqual(5);
      expect(changed[0]).assertEqual('msg-2:0:streaming');
    });

    it('does not expose internal swipe records', 0, () => {
      const bus = new EventBus();
      const runtime = new SwipeRuntime(bus);
      bus.subscribe<SwipeChangedPayload>('message.swipe.changed', (event: RuntimeEvent<SwipeChangedPayload>) => {
        event.payload.swipe.text = 'event-mutated';
      });

      const swipe = runtime.createSwipe(makeSwipe('chat-copy', 'msg-copy', 'original'));
      swipe.text = 'external';
      expect(runtime.getActiveSwipe('chat-copy', 'msg-copy').text).assertEqual('original');

      const listed = runtime.listSwipes('chat-copy', 'msg-copy');
      listed[0].text = 'listed';
      expect(runtime.getActiveSwipe('chat-copy', 'msg-copy').text).assertEqual('original');

      const edited = runtime.editSwipe('chat-copy', 'msg-copy', 0, 'edited');
      edited.text = 'edited-external';
      expect(runtime.getActiveSwipe('chat-copy', 'msg-copy').text).assertEqual('edited');
    });
  });
}

function makeSwipe(chatId: string, messageId: string, text: string): SwipeCreateParams {
  return {
    chatId: chatId,
    messageId: messageId,
    text: text,
  };
}
