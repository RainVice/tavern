import { describe, it, expect } from '@ohos/hypium';
import {
  ChatRuntime,
  EventBus,
  InMemoryFileStore,
  MessageRuntime,
  type ChatCreateParams,
  type ChatEventPayload,
  type ChatMessageCreateParams,
  type ChatMessageUpdateParams,
  type MessageEventPayload,
  type RuntimeEvent,
  type TavernFileStore,
} from '../../Index';

export default function chatUnitTest() {
  describe('chat runtime', () => {
    it('creates chats, appends JSONL messages, edits, hides, and deletes messages', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const messageEvents = new Array<string>();
      bus.subscribe<MessageEventPayload>('message.added', (event: RuntimeEvent<MessageEventPayload>) => {
        messageEvents.push(event.payload.message.id);
      });
      const chatParams: ChatCreateParams = {
        title: 'Alice chat',
        characterId: 'char-1',
        personaId: 'persona-default',
      };

      const chat = await chats.createChat(chatParams);
      const messages = new MessageRuntime(files, bus, 'tavern-data', 'default', chat.id);
      const userMessageParams: ChatMessageCreateParams = {
        name: 'User',
        role: 'user',
        text: 'Hello',
      };
      const assistantMessageParams: ChatMessageCreateParams = {
        name: 'Alice',
        role: 'assistant',
        text: 'Hi there',
      };
      const first = await messages.addMessage(userMessageParams);
      const second = await messages.addMessage(assistantMessageParams);
      const updateParams: ChatMessageUpdateParams = {
        text: 'Hi there!',
        isSystem: true,
      };
      const updated = await messages.updateMessage(second.id, updateParams);
      await messages.deleteMessage(first.id);
      const remaining = await messages.listMessages();
      const index = await chats.listChats();
      const exported = await chats.exportChatJsonl(chat.id);

      expect(chat.id).assertEqual('chat-1');
      expect(index.length).assertEqual(1);
      expect(first.index).assertEqual(0);
      expect(second.index).assertEqual(1);
      expect(updated.text).assertEqual('Hi there!');
      expect(updated.isSystem).assertTrue();
      expect(remaining.length).assertEqual(1);
      expect(remaining[0].id).assertEqual('msg-2');
      expect(messageEvents.length).assertEqual(2);
      expect(exported).assertContain('"chat_metadata"');
      expect(exported).assertContain('"mes":"Hi there!"');
      expect(exported).assertContain('"is_system":true');
    });

    it('更新或删除不存在的消息时抛错', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const chat = await chats.createChat({ title: 'Strict chat', characterId: 'char-1', personaId: 'persona-default' });
      const messages = chats.messages(chat.id);
      const updateParams: ChatMessageUpdateParams = {
        text: 'missing',
        isSystem: false,
      };

      let updateFailed = false;
      try {
        await messages.updateMessage('missing-message', updateParams);
      } catch (error) {
        updateFailed = true;
      }
      let deleteFailed = false;
      try {
        await messages.deleteMessage('missing-message');
      } catch (error) {
        deleteFailed = true;
      }

      expect(updateFailed).assertTrue();
      expect(deleteFailed).assertTrue();
    });

    it('supports message lookup pagination movement batch delete and event isolation', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const chat = await chats.createChat({ title: 'Message tools', characterId: 'char-1', personaId: 'persona-default' });
      const messages = chats.messages(chat.id);
      bus.subscribe<MessageEventPayload>('message.updated', (event: RuntimeEvent<MessageEventPayload>) => {
        event.payload.message.text = 'event-mutated';
      });
      const first = await messages.addMessage({ name: 'User', role: 'user', text: 'One' });
      const second = await messages.addMessage({ name: 'Alice', role: 'assistant', text: 'Two' });
      const third = await messages.addMessage({ name: 'User', role: 'user', text: 'Three' });

      const page = await messages.listMessagesPage(1, 2);
      const loaded = await messages.getMessage(second.id);
      loaded.text = 'external-mutated';
      const moved = await messages.moveMessage(third.id, 0);
      const reordered = await messages.listMessages();
      const deletedIds = await messages.deleteMessages([first.id, second.id]);
      const remaining = await messages.listMessages();

      expect(page.length).assertEqual(2);
      expect(page[0].id).assertEqual(second.id);
      expect(page[1].id).assertEqual(third.id);
      expect((await messages.getMessage(second.id)).text).assertEqual('Two');
      expect(moved.text).assertEqual('Three');
      expect(reordered[0].id).assertEqual(third.id);
      expect(reordered[0].index).assertEqual(0);
      expect(reordered[1].id).assertEqual(first.id);
      expect(reordered[1].index).assertEqual(1);
      expect(deletedIds.length).assertEqual(2);
      expect(remaining.length).assertEqual(1);
      expect(remaining[0].id).assertEqual(third.id);
      expect(remaining[0].text).assertEqual('Three');
    });

    it('读取不存在的聊天或向其写消息时抛错', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const messages = new MessageRuntime(files, bus, 'tavern-data', 'default', 'missing-chat');

      let getFailed = false;
      try {
        await chats.getChat('missing-chat');
      } catch (error) {
        getFailed = true;
      }
      let addFailed = false;
      try {
        await messages.addMessage({ name: 'User', role: 'user', text: 'Hello' });
      } catch (error) {
        addFailed = true;
      }

      expect(getFailed).assertTrue();
      expect(addFailed).assertTrue();
    });

    it('导入导出 JSONL 时保留 swipes 和 extra 字段', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const jsonl = '{"chat_metadata":{"chat_id":"old","title":"Old","character_id":"char-1","persona_id":"persona-default"},"user_name":"User","character_name":"Alice"}\n{"name":"Alice","is_user":false,"is_system":false,"send_date":"2026-01-01T00:00:00.000Z","mes":"Hello","swipes":["Hello","Alt"],"extra":{"rating":4,"bookmarked":true,"bookmark_link":"bookmark-1","branches":["branch-1"]}}\n';

      const chat = await chats.importChatJsonl(jsonl, 'Imported chat', 'char-1', 'persona-default');
      const messages = await chats.messages(chat.id).listMessages();
      const exported = await chats.exportChatJsonl(chat.id);

      expect(messages.length).assertEqual(1);
      expect(messages[0].sendDate).assertEqual('2026-01-01T00:00:00.000Z');
      expect(messages[0].swipes.length).assertEqual(2);
      expect(messages[0].swipes[1]).assertEqual('Alt');
      expect(messages[0].extraJson).assertContain('"rating":4');
      expect(messages[0].extraJson).assertContain('"bookmarked":true');
      expect(exported).assertContain('"swipes":["Hello","Alt"]');
      expect(exported).assertContain('"rating":4');
      expect(exported).assertContain('"branches":["branch-1"]');
    });

    it('导入畸形 JSONL 不会留下半创建聊天', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      let failed = false;

      try {
        await chats.importChatJsonl('{"name":"User","mes":"ok"}\n{bad-json}\n', 'Broken', 'char-1', 'persona-default');
      } catch (error) {
        failed = true;
      }

      const listed = await chats.listChats();
      expect(failed).assertTrue();
      expect(listed.length).assertEqual(0);
    });

    it('renames and archives chat index entries', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const chatParams: ChatCreateParams = {
        title: 'Draft',
        characterId: 'char-1',
        personaId: 'persona-default',
      };

      const chat = await chats.createChat(chatParams);
      const renamed = await chats.renameChat(chat.id, 'Final');
      const archived = await chats.archiveChat(chat.id, true);
      const listed = await chats.listChats();

      expect(renamed.title).assertEqual('Final');
      expect(archived.archived).assertTrue();
      expect(listed[0].title).assertEqual('Final');
      expect(listed[0].archived).assertTrue();
    });

    it('不会暴露内部聊天记录给事件和返回值修改', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const observed = new Array<string>();
      bus.subscribe<ChatEventPayload>('chat.created', (event: RuntimeEvent<ChatEventPayload>) => {
        event.payload.chat.title = 'event-mutated';
      });
      bus.subscribe<ChatEventPayload>('chat.created', (event: RuntimeEvent<ChatEventPayload>) => {
        observed.push(event.payload.chat.title);
      });

      const created = await chats.createChat({ title: 'Original', characterId: 'char-1', personaId: 'persona-default' });
      created.title = 'return-mutated';
      const loaded = await chats.getChat(created.id);

      expect(observed[0]).assertEqual('Original');
      expect(loaded.title).assertEqual('Original');
    });

    it('searches freshly added message previews without requiring a prior list refresh', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const chat = await chats.createChat({ title: 'Search chat', characterId: 'char-1', personaId: 'persona-default' });
      await chats.messages(chat.id).addMessage({ name: 'User', role: 'user', text: 'fresh dragon clue' });

      const results = await chats.searchChats('dragon');

      expect(results.length).assertEqual(1);
      expect(results[0].id).assertEqual(chat.id);
      expect(results[0].previewMessage).assertEqual('fresh dragon clue');
    });

    it('duplicates and deletes chats with their message files', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      const events = new Array<string>();
      bus.subscribe<ChatEventPayload>('chat.duplicated', (event: RuntimeEvent<ChatEventPayload>) => {
        events.push(`duplicated:${event.payload.chat.id}`);
      });
      bus.subscribe<ChatEventPayload>('chat.deleted', (event: RuntimeEvent<ChatEventPayload>) => {
        events.push(`deleted:${event.payload.chat.id}`);
      });
      const chat = await chats.createChat({ title: 'Original', characterId: 'char-1', personaId: 'persona-default' });
      await chats.messages(chat.id).addMessage({ name: 'User', role: 'user', text: 'Hello copy' });

      const duplicate = await chats.duplicateChat(chat.id, 'Copy');
      const duplicateMessages = await chats.messages(duplicate.id).listMessages();
      await chats.deleteChat(chat.id);
      const listed = await chats.listChats();
      const originalChatExists = await files.exists('tavern-data/users/default/chats/chat-1/chat.json');
      const originalMessagesExist = await files.exists('tavern-data/users/default/chats/chat-1/messages.jsonl');

      expect(duplicate.id).assertEqual('chat-2');
      expect(duplicate.title).assertEqual('Copy');
      expect(duplicateMessages.length).assertEqual(1);
      expect(duplicateMessages[0].text).assertEqual('Hello copy');
      expect(listed.length).assertEqual(1);
      expect(listed[0].id).assertEqual('chat-2');
      expect(originalChatExists).assertFalse();
      expect(originalMessagesExist).assertFalse();
      expect(events[0]).assertEqual('duplicated:chat-2');
      expect(events[1]).assertEqual('deleted:chat-1');
    });

    it('拒绝通过路径穿越别名读取聊天或写入消息', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const chats = new ChatRuntime(files, bus, 'tavern-data', 'default');
      await chats.createChat({ title: 'Safe chat', characterId: 'char-1', personaId: 'persona-default' });

      let getFailed = false;
      try {
        await chats.getChat('../chats/chat-1');
      } catch (error) {
        getFailed = true;
      }
      const messages = new MessageRuntime(files, bus, 'tavern-data', 'default', '../chats/chat-1');
      let addFailed = false;
      try {
        await messages.addMessage({ name: 'User', role: 'user', text: 'Hello' });
      } catch (error) {
        addFailed = true;
      }

      expect(getFailed).assertTrue();
      expect(addFailed).assertTrue();
    });
  });
}
