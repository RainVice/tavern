import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import { JsonlStore } from '../storage/JsonlStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  ChatMessage,
  ChatMessageCreateParams,
  ChatMessageUpdateParams,
  ChatRecord,
  MessageExtraData,
  MessageEventPayload,
} from './ChatModels';

export class MessageRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private rootPath: string;
  private userId: string;
  private chatId: string;

  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string, chatId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
    this.chatId = chatId;
  }

  async addMessage(params: ChatMessageCreateParams): Promise<ChatMessage> {
    const chat = await this.readChat();
    const messages = await this.listMessages();
    const message: ChatMessage = {
      schemaVersion: 1,
      id: `msg-${chat.nextMessageId}`,
      index: messages.length,
      name: params.name,
      role: params.role,
      isUser: params.role === 'user',
      isSystem: params.role === 'system',
      sendDate: new Date(Date.now()).toISOString(),
      text: params.text,
      swipes: new Array<string>(),
      activeSwipeIndex: 0,
      extraJson: '',
    };

    chat.nextMessageId += 1;
    chat.updatedAt = Date.now();
    await this.writeChat(chat);
    const store = this.messageStore();
    await store.append(this.copyMessage(message));
    this.publishMessageEvent('message.added', message);
    return this.copyMessage(message);
  }

  async listMessages(): Promise<Array<ChatMessage>> {
    const store = this.messageStore();
    return this.copyMessages(await store.readAll());
  }

  async getMessage(messageId: string): Promise<ChatMessage> {
    const messages = await this.listMessages();
    for (let index = 0; index < messages.length; index += 1) {
      if (messages[index].id === messageId) {
        return this.copyMessage(messages[index]);
      }
    }
    throw new Error('消息未找到: ' + messageId);
  }

  async listMessagesPage(startIndex: number, limit: number): Promise<Array<ChatMessage>> {
    const messages = await this.listMessages();
    const normalizedStart = Math.max(0, startIndex);
    const normalizedLimit = Math.max(0, limit);
    const result = new Array<ChatMessage>();
    const end = Math.min(messages.length, normalizedStart + normalizedLimit);
    for (let index = normalizedStart; index < end; index += 1) {
      result.push(this.copyMessage(messages[index]));
    }
    return result;
  }

  async updateMessage(messageId: string, params: ChatMessageUpdateParams): Promise<ChatMessage> {
    const messages = await this.listMessages();
    let updated: ChatMessage | undefined = undefined;
    for (let index = 0; index < messages.length; index += 1) {
      if (messages[index].id === messageId) {
        messages[index].text = params.text;
        messages[index].isSystem = params.isSystem;
        updated = messages[index];
      }
    }
    if (updated === undefined) {
      throw new Error('消息未找到: ' + messageId);
    }
    await this.messageStore().compact(messages);
    await this.touchChat();
    this.publishMessageEvent('message.updated', updated);
    return this.copyMessage(updated);
  }

  async deleteMessage(messageId: string): Promise<void> {
    const messages = await this.listMessages();
    const remaining = new Array<ChatMessage>();
    let deleted: ChatMessage | undefined = undefined;
    for (let index = 0; index < messages.length; index += 1) {
      const message = messages[index];
      if (message.id === messageId) {
        deleted = message;
      } else {
        remaining.push(message);
      }
    }
    if (deleted === undefined) {
      throw new Error('消息未找到: ' + messageId);
    }
    for (let index = 0; index < remaining.length; index += 1) {
      remaining[index].index = index;
    }
    await this.messageStore().compact(remaining);
    await this.touchChat();
    this.publishMessageEvent('message.deleted', deleted);
  }

  async deleteMessages(messageIds: Array<string>): Promise<Array<string>> {
    const messages = await this.listMessages();
    const targets = new Set<string>();
    for (let index = 0; index < messageIds.length; index += 1) {
      targets.add(messageIds[index]);
    }
    const remaining = new Array<ChatMessage>();
    const deleted = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      if (targets.has(messages[index].id)) {
        deleted.push(messages[index]);
      } else {
        remaining.push(messages[index]);
      }
    }
    if (deleted.length !== targets.size) {
      throw new Error('批量删除包含不存在的消息');
    }
    for (let index = 0; index < remaining.length; index += 1) {
      remaining[index].index = index;
    }
    await this.messageStore().compact(remaining);
    await this.touchChat();
    const deletedIds = new Array<string>();
    for (let index = 0; index < deleted.length; index += 1) {
      deletedIds.push(deleted[index].id);
      this.publishMessageEvent('message.deleted', deleted[index]);
    }
    return deletedIds;
  }

  async moveMessage(messageId: string, targetIndex: number): Promise<ChatMessage> {
    const messages = await this.listMessages();
    let sourceIndex = -1;
    for (let index = 0; index < messages.length; index += 1) {
      if (messages[index].id === messageId) {
        sourceIndex = index;
      }
    }
    if (sourceIndex < 0) {
      throw new Error('消息未找到: ' + messageId);
    }
    const normalizedTarget = Math.max(0, Math.min(targetIndex, messages.length - 1));
    const moved = messages[sourceIndex];
    const withoutMoved = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      if (index !== sourceIndex) {
        withoutMoved.push(messages[index]);
      }
    }
    const reordered = new Array<ChatMessage>();
    for (let index = 0; index < withoutMoved.length + 1; index += 1) {
      if (index === normalizedTarget) {
        reordered.push(moved);
      }
      if (index < withoutMoved.length) {
        reordered.push(withoutMoved[index]);
      }
    }
    for (let index = 0; index < reordered.length; index += 1) {
      reordered[index].index = index;
    }
    await this.messageStore().compact(reordered);
    await this.touchChat();
    this.publishMessageEvent('message.updated', moved);
    return this.copyMessage(moved);
  }

  async hideMessage(messageId: string, hidden: boolean): Promise<ChatMessage> {
    const messages = await this.listMessages();
    for (let i = 0; i < messages.length; i += 1) {
      if (messages[i].id === messageId) {
        messages[i].isSystem = hidden;
        await this.messageStore().compact(messages);
        await this.touchChat();
        return this.copyMessage(messages[i]);
      }
    }
    throw new Error('消息未找到: ' + messageId);
  }

  async setMessageRating(messageId: string, rating: number): Promise<ChatMessage> {
    const messages = await this.listMessages();
    for (let i = 0; i < messages.length; i += 1) {
      if (messages[i].id === messageId) {
        const extra = this.readExtra(messages[i].extraJson);
        extra.rating = Math.max(0, Math.min(5, rating));
        messages[i].extraJson = this.writeExtra(extra);
        await this.messageStore().compact(messages);
        await this.touchChat();
        return this.copyMessage(messages[i]);
      }
    }
    throw new Error('消息未找到: ' + messageId);
  }

  async setMessageBookmark(messageId: string, bookmarked: boolean): Promise<ChatMessage> {
    const messages = await this.listMessages();
    for (let i = 0; i < messages.length; i += 1) {
      if (messages[i].id === messageId) {
        const extra = this.readExtra(messages[i].extraJson);
        extra.bookmarked = bookmarked;
        messages[i].extraJson = this.writeExtra(extra);
        await this.messageStore().compact(messages);
        await this.touchChat();
        return this.copyMessage(messages[i]);
      }
    }
    throw new Error('消息未找到: ' + messageId);
  }

  private readExtra(extraJson: string): MessageExtraData {
    const fallback: MessageExtraData = {
      rating: 0,
      bookmarked: false,
      bookmark_link: '',
      branches: new Array<string>(),
    };
    if (extraJson.length === 0) {
      return fallback;
    }
    try {
      const parsed = JSON.parse(extraJson) as MessageExtraData;
      return {
        rating: parsed.rating === undefined ? 0 : parsed.rating,
        bookmarked: parsed.bookmarked === undefined ? false : parsed.bookmarked,
        bookmark_link: parsed.bookmark_link === undefined ? '' : parsed.bookmark_link,
        branches: parsed.branches === undefined ? new Array<string>() : parsed.branches.slice(),
      };
    } catch (error) {
      return fallback;
    }
  }

  private writeExtra(extra: MessageExtraData): string {
    return JSON.stringify(extra);
  }

  private async touchChat(): Promise<void> {
    const chat = await this.readChat();
    chat.updatedAt = Date.now();
    await this.writeChat(chat);
  }

  private publishMessageEvent(eventName: string, message: ChatMessage): void {
    const payload: MessageEventPayload = {
      chatId: this.chatId,
      message: this.copyMessage(message),
    };
    this.events.publish<MessageEventPayload>(eventName, payload);
  }

  private copyMessages(messages: Array<ChatMessage>): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push(this.copyMessage(messages[index]));
    }
    return result;
  }

  private copyMessage(message: ChatMessage): ChatMessage {
    return {
      schemaVersion: message.schemaVersion,
      id: message.id,
      index: message.index,
      name: message.name,
      role: message.role,
      isUser: message.isUser,
      isSystem: message.isSystem,
      sendDate: message.sendDate,
      text: message.text,
      swipes: message.swipes.slice(),
      activeSwipeIndex: message.activeSwipeIndex,
      extraJson: message.extraJson,
    };
  }

  private messageStore(): JsonlStore<ChatMessage> {
    return new JsonlStore<ChatMessage>(this.files, this.messagesPath());
  }

  private async readChat(): Promise<ChatRecord> {
    const exists = await this.files.exists(this.chatPath());
    if (!exists) {
      throw new Error(`Chat not found: ${this.chatId}`);
    }
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath());
    return store.read(this.defaultChat());
  }

  private async writeChat(chat: ChatRecord): Promise<void> {
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath());
    await store.write(chat);
  }

  private defaultChat(): ChatRecord {
    return {
      schemaVersion: 1,
      id: this.chatId,
      title: '',
      characterId: '',
      personaId: '',
      archived: false,
      nextMessageId: 1,
      createdAt: 0,
      updatedAt: 0,
    };
  }

  private chatPath(): string {
    return `${this.chatDirectory()}/chat.json`;
  }

  private messagesPath(): string {
    return `${this.chatDirectory()}/messages.jsonl`;
  }

  private chatDirectory(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/chats/${safePathSegment(this.chatId, 'chat')}`;
  }
}
