import { describe, it, expect } from '@ohos/hypium';
import {
  BookmarkRuntime,
  EventBus,
  type BookmarkCreatedPayload,
  type BookmarkNameInput,
  type BookmarkResult,
  type BranchResult,
  type ChatMessage,
  type RuntimeEvent,
} from '../../Index';

export default function bookmarkUnitTest() {
  describe('bookmark runtime', () => {
    it('creates checkpoint names, snapshots chat history, and marks the target message', 0, () => {
      const bus = new EventBus();
      const runtime = new BookmarkRuntime(bus);
      const created = new Array<string>();
      bus.subscribe<BookmarkCreatedPayload>('bookmark.created', (event: RuntimeEvent<BookmarkCreatedPayload>) => {
        created.push(event.payload.name);
      });
      const messages = [makeMessage('msg-1', 0, 'Hello'), makeMessage('msg-2', 1, 'Hi')];
      const input = makeNameInput('Alice chat', ['Alice chat - Checkpoint #1']);

      const result: BookmarkResult = runtime.createCheckpoint(messages, 1, input, 'Alice chat');

      expect(result.name).assertEqual('Alice chat - Checkpoint #2');
      expect(result.metadata.mainChat).assertEqual('Alice chat');
      expect(result.snapshot.length).assertEqual(2);
      expect(result.updatedMessages[1].extraJson).assertContain('bookmark_link');
      expect(result.updatedMessages[1].extraJson).assertContain('Alice chat - Checkpoint #2');
      expect(created.length).assertEqual(1);
      expect(created[0]).assertEqual('Alice chat - Checkpoint #2');
    });

    it('creates branch snapshots and records branch names on the source message', 0, () => {
      const bus = new EventBus();
      const runtime = new BookmarkRuntime(bus);
      const messages = [makeMessage('msg-1', 0, 'Hello'), makeMessage('msg-2', 1, 'First swipe')];
      messages[1].swipes = ['First swipe', 'Second swipe'];
      messages[1].activeSwipeIndex = 0;
      const input = makeNameInput('Alice chat', ['Alice chat - Branch #1']);

      const result: BranchResult = runtime.createBranch(messages, 1, input, 'Alice chat', 1);

      expect(result.name).assertEqual('Alice chat - Branch #2');
      expect(result.snapshot.length).assertEqual(2);
      expect(result.snapshot[1].text).assertEqual('Second swipe');
      expect(result.snapshot[1].activeSwipeIndex).assertEqual(1);
      expect(result.updatedMessages[1].extraJson).assertContain('branches');
      expect(result.updatedMessages[1].extraJson).assertContain('Alice chat - Branch #2');
    });

    it('does not let bookmark event subscribers mutate returned metadata', 0, () => {
      const bus = new EventBus();
      const runtime = new BookmarkRuntime(bus);
      bus.subscribe<BookmarkCreatedPayload>('bookmark.created', (event: RuntimeEvent<BookmarkCreatedPayload>) => {
        event.payload.metadata.mainChat = 'mutated';
      });
      const messages = [makeMessage('msg-1', 0, 'Hello')];

      const result = runtime.createCheckpoint(messages, 0, makeNameInput('Alice chat', new Array<string>()), 'Alice chat');

      expect(result.metadata.mainChat).assertEqual('Alice chat');
    });
  });
}

function makeNameInput(currentChatName: string, existingChatNames: Array<string>): BookmarkNameInput {
  return {
    currentChatName: currentChatName,
    existingChatNames: existingChatNames,
  };
}

function makeMessage(id: string, index: number, text: string): ChatMessage {
  return {
    schemaVersion: 1,
    id: id,
    index: index,
    name: index === 0 ? 'User' : 'Alice',
    role: index === 0 ? 'user' : 'assistant',
    isUser: index === 0,
    isSystem: false,
    sendDate: '',
    text: text,
    swipes: new Array<string>(),
    activeSwipeIndex: 0,
    extraJson: '',
  };
}
