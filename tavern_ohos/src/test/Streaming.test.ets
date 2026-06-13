import { describe, it, expect } from '@ohos/hypium';
import {
  ChatRuntime,
  EventBus,
  InMemoryFileStore,
  MessageRuntime,
  StreamingRuntime,
  type ChatCreateParams,
  type ChatMessageCreateParams,
  type RuntimeEvent,
  type StreamDeltaPayload,
  type StreamStartPayload,
  type StreamStartParams,
  type TavernFileStore,
} from '../../Index';

export default function streamingUnitTest() {
  describe('streaming runtime', () => {
    it('streams deltas, persists snapshots into a message, and completes', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const chatParams: ChatCreateParams = {
        title: 'Stream chat',
        characterId: 'char-1',
        personaId: 'persona-default',
      };
      const chat = await chats.createChat(chatParams);
      const messages = new MessageRuntime(files, bus, 'tavern-data', 'default', chat.id);
      const messageParams: ChatMessageCreateParams = {
        name: 'Alice',
        role: 'assistant',
        text: '',
      };
      const message = await messages.addMessage(messageParams);
      const streaming = new StreamingRuntime(bus);
      streaming.attachMessageRuntime(messages);
      const snapshots = new Array<string>();
      bus.subscribe<StreamDeltaPayload>('stream.delta', (event: RuntimeEvent<StreamDeltaPayload>) => {
        snapshots.push(event.payload.snapshot);
      });
      const startParams: StreamStartParams = {
        taskId: 'task-1',
        chatId: chat.id,
        messageId: message.id,
      };
      const session = streaming.startStream(startParams);
      await streaming.applyDelta(session.id, 'Hel', false);
      await streaming.applyDelta(session.id, 'lo', false);
      const completed = streaming.completeStream(session.id);
      const savedMessages = await messages.listMessages();

      expect(completed.snapshot).assertEqual('Hello');
      expect(completed.status).assertEqual('completed');
      expect(snapshots.length).assertEqual(2);
      expect(snapshots[0]).assertEqual('Hel');
      expect(snapshots[1]).assertEqual('Hello');
      expect(savedMessages[0].text).assertEqual('Hello');
    });

    it('aborts streams and ignores later deltas', 0, async () => {
      // 事件总线实例。
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
      const startParams: StreamStartParams = {
        taskId: 'task-2',
        chatId: 'chat-1',
        messageId: 'msg-1',
      };
      const session = streaming.startStream(startParams);
      await streaming.applyDelta(session.id, 'partial', false);
      const aborted = streaming.abortStream(session.id, 'user stopped');
      await streaming.applyDelta(session.id, ' ignored', false);
      const afterDelta = streaming.getSession(session.id);

      expect(aborted.status).assertEqual('aborted');
      expect(aborted.abortReason).assertEqual('user stopped');
      expect(afterDelta.snapshot).assertEqual('partial');
    });

    it('does not expose internal stream sessions', 0, async () => {
      // 事件总线实例。
      const bus = new EventBus();
      const streaming = new StreamingRuntime(bus);
      bus.subscribe<StreamStartPayload>('stream.started', (event: RuntimeEvent<StreamStartPayload>) => {
        event.payload.session.status = 'event-mutated';
      });
      const startParams: StreamStartParams = {
        taskId: 'task-copy',
        chatId: 'chat-1',
        messageId: 'msg-1',
      };
      const session = streaming.startStream(startParams);
      session.status = 'external-mutated';
      expect(streaming.getSession(session.id).status).assertEqual('running');
      const updated = await streaming.applyDelta(session.id, 'hello', false);
      updated.snapshot = 'external snapshot';
      expect(streaming.getSession(session.id).snapshot).assertEqual('hello');
    });
  });
}
