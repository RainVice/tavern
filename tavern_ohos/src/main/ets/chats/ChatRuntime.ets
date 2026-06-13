import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import { JsonlStore } from '../storage/JsonlStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import {
  MessageRuntime,
} from './MessageRuntime';
import type {
  ChatCreateParams,
  ChatEventPayload,
  ChatExportExtra,
  ChatExportHeader,
  ChatExportMessage,
  ChatIndex,
  ChatIndexEntry,
  ChatMessage,
  ChatRecord,
  MessageExtraData,
} from './ChatModels';

export class ChatRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private rootPath: string;
  private userId: string;

  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  async createChat(params: ChatCreateParams): Promise<ChatRecord> {
    const index = await this.readIndex();
    const id = `chat-${index.nextId}`;
    index.nextId += 1;
    const now = Date.now();
    const chat: ChatRecord = {
      schemaVersion: 1,
      id: id,
      title: params.title,
      characterId: params.characterId,
      personaId: params.personaId,
      archived: false,
      nextMessageId: 1,
      createdAt: now,
      updatedAt: now,
    };

    await this.writeChat(chat);
    index.items.push(this.toIndexEntry(chat, 0, ''));
    await this.writeIndex(index);
    this.publishChatEvent('chat.created', chat);
    return this.copyChat(chat);
  }

  async listChats(): Promise<Array<ChatIndexEntry>> {
    const index = await this.readIndex();
    const refreshed = new Array<ChatIndexEntry>();
    for (let itemIndex = 0; itemIndex < index.items.length; itemIndex += 1) {
      const item = index.items[itemIndex];
      const chat = await this.getChat(item.id);
      const messages = await this.messages(item.id).listMessages();
      refreshed.push(this.toIndexEntry(chat, messages.length, this.preview(messages)));
    }
    index.items = refreshed;
    await this.writeIndex(index);
    return refreshed;
  }

  async searchChats(query: string): Promise<Array<ChatIndexEntry>> {
    const items = await this.listChats();
    const lower = query.toLowerCase();
    const result = new Array<ChatIndexEntry>();
    for (let it = 0; it < items.length; it += 1) {
      const item = items[it];
      if (item.title.toLowerCase().indexOf(lower) >= 0 || item.previewMessage.toLowerCase().indexOf(lower) >= 0) {
        result.push(item);
      }
    }
    return result;
  }

  async importChatJsonl(jsonl: string, title: string, characterId: string, personaId: string): Promise<ChatRecord> {
    const importedMessages = this.parseImportedMessages(jsonl);
    const chat = await this.createChat({ title, characterId, personaId });
    const writableChat = this.copyChat(chat);
    writableChat.nextMessageId = importedMessages.length + 1;
    writableChat.updatedAt = Date.now();
    await this.writeChat(writableChat);
    const store = new JsonlStore<ChatMessage>(this.files, this.messagesPath(writableChat.id));
    await store.compact(importedMessages);
    const updated = await this.getChat(writableChat.id);
    await this.replaceIndexEntry(updated);
    this.publishChatEvent('chat.imported', updated);
    return this.copyChat(updated);
  }

  private parseImportedMessages(jsonl: string): Array<ChatMessage> {
    const lines = jsonl.split('\n');
    const importedMessages = new Array<ChatMessage>();
    let nextMessageId = 1;
    for (let li = 0; li < lines.length; li += 1) {
      const line = lines[li].trim();
      if (line.length === 0) { continue; }
      const imported = JSON.parse(line) as ChatExportMessage;
      if (imported.name === undefined) { continue; }
      const isSystem = imported.is_system === undefined ? false : imported.is_system;
      const isUser = imported.is_user === undefined ? false : imported.is_user;
      const sendDate = imported.send_date === undefined || imported.send_date.length === 0
        ? new Date(Date.now()).toISOString()
        : imported.send_date;
      const message: ChatMessage = {
        schemaVersion: 1,
        id: `msg-${nextMessageId}`,
        index: importedMessages.length,
        name: imported.name,
        role: isSystem ? 'system' : (isUser ? 'user' : 'assistant'),
        isUser: isUser,
        isSystem: isSystem,
        sendDate: sendDate,
        text: imported.mes === undefined ? '' : imported.mes,
        swipes: imported.swipes === undefined ? new Array<string>() : imported.swipes.slice(),
        activeSwipeIndex: 0,
        extraJson: imported.extra === undefined ? '' : this.exportExtraToJson(imported.extra),
      };
      importedMessages.push(message);
      nextMessageId += 1;
    }
    return importedMessages;
  }

  async getChat(chatId: string): Promise<ChatRecord> {
    const exists = await this.files.exists(this.chatPath(chatId));
    if (!exists) {
      throw new Error(`Chat not found: ${chatId}`);
    }
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath(chatId));
    return this.copyChat(await store.read(this.defaultChat(chatId)));
  }

  async renameChat(chatId: string, title: string): Promise<ChatRecord> {
    const chat = await this.getChat(chatId);
    chat.title = title;
    chat.updatedAt = Date.now();
    await this.writeChat(chat);
    await this.replaceIndexEntry(chat);
    this.publishChatEvent('chat.updated', chat);
    return this.copyChat(chat);
  }

  async archiveChat(chatId: string, archived: boolean): Promise<ChatRecord> {
    const chat = await this.getChat(chatId);
    chat.archived = archived;
    chat.updatedAt = Date.now();
    await this.writeChat(chat);
    await this.replaceIndexEntry(chat);
    this.publishChatEvent('chat.updated', chat);
    return this.copyChat(chat);
  }

  async duplicateChat(chatId: string, title: string): Promise<ChatRecord> {
    const original = await this.getChat(chatId);
    const originalMessages = await this.messages(chatId).listMessages();
    const index = await this.readIndex();
    const id = `chat-${index.nextId}`;
    index.nextId += 1;
    const now = Date.now();
    const duplicate: ChatRecord = {
      schemaVersion: original.schemaVersion,
      id: id,
      title: title,
      characterId: original.characterId,
      personaId: original.personaId,
      archived: false,
      nextMessageId: original.nextMessageId,
      createdAt: now,
      updatedAt: now,
    };
    await this.writeChat(duplicate);
    const copiedMessages = this.copyMessages(originalMessages);
    const store = new JsonlStore<ChatMessage>(this.files, this.messagesPath(duplicate.id));
    await store.compact(copiedMessages);
    index.items.push(this.toIndexEntry(duplicate, copiedMessages.length, this.preview(copiedMessages)));
    await this.writeIndex(index);
    this.publishChatEvent('chat.created', duplicate);
    this.publishChatEvent('chat.duplicated', duplicate);
    return this.copyChat(duplicate);
  }

  async deleteChat(chatId: string): Promise<void> {
    const chat = await this.getChat(chatId);
    await this.deleteDirectoryTree(this.chatDirectory(chat.id));
    const index = await this.readIndex();
    const remaining = new Array<ChatIndexEntry>();
    for (let itemIndex = 0; itemIndex < index.items.length; itemIndex += 1) {
      if (index.items[itemIndex].id !== chat.id) {
        remaining.push(index.items[itemIndex]);
      }
    }
    index.items = remaining;
    await this.writeIndex(index);
    this.publishChatEvent('chat.deleted', chat);
  }

  async exportChatJsonl(chatId: string): Promise<string> {
    const chat = await this.getChat(chatId);
    const messages = await this.messages(chatId).listMessages();
    const lines = new Array<string>();
    const header: ChatExportHeader = {
      chat_metadata: {
        chat_id: chat.id,
        title: chat.title,
        character_id: chat.characterId,
        persona_id: chat.personaId,
      },
      user_name: 'unused',
      character_name: 'unused',
    };
    lines.push(JSON.stringify(header));
    for (let index = 0; index < messages.length; index += 1) {
      lines.push(JSON.stringify(this.toExportMessage(messages[index])));
    }
    return `${lines.join('\n')}\n`;
  }

  messages(chatId: string): MessageRuntime {
    return new MessageRuntime(this.files, this.events, this.rootPath, this.userId, chatId);
  }

  private toExportMessage(message: ChatMessage): ChatExportMessage {
    return {
      name: message.name,
      is_user: message.isUser,
      is_system: message.isSystem,
      send_date: message.sendDate,
      mes: message.text,
      swipes: message.swipes.slice(),
      extra: this.parseExtra(message.extraJson),
    };
  }

  private parseExtra(extraJson: string): ChatExportExtra {
    if (extraJson.length === 0) {
      return {};
    }
    try {
      const parsed = JSON.parse(extraJson) as MessageExtraData;
      return {
        rating: parsed.rating === undefined ? undefined : parsed.rating,
        bookmarked: parsed.bookmarked === undefined ? undefined : parsed.bookmarked,
        bookmark_link: parsed.bookmark_link === undefined ? undefined : parsed.bookmark_link,
        branches: parsed.branches === undefined ? undefined : parsed.branches.slice(),
      };
    } catch (error) {
      return {
        source: extraJson,
      };
    }
  }

  private exportExtraToJson(extra: ChatExportExtra): string {
    if (extra.source !== undefined && extra.source.length > 0) {
      return extra.source;
    }
    const parsed: MessageExtraData = {
      rating: extra.rating === undefined ? 0 : extra.rating,
      bookmarked: extra.bookmarked === undefined ? false : extra.bookmarked,
      bookmark_link: extra.bookmark_link === undefined ? '' : extra.bookmark_link,
      branches: extra.branches === undefined ? new Array<string>() : extra.branches.slice(),
    };
    return JSON.stringify(parsed);
  }

  private preview(messages: Array<ChatMessage>): string {
    if (messages.length === 0) {
      return '';
    }
    return messages[messages.length - 1].text;
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

  private async deleteDirectoryTree(path: string): Promise<void> {
    const children = await this.files.list(path);
    for (let index = 0; index < children.length; index += 1) {
      await this.deleteDirectoryTree(`${path}/${children[index]}`);
    }
    await this.files.delete(path);
  }

  private async replaceIndexEntry(chat: ChatRecord): Promise<void> {
    const index = await this.readIndex();
    const messages = await this.messages(chat.id).listMessages();
    const entry = this.toIndexEntry(chat, messages.length, this.preview(messages));
    let replaced = false;
    for (let itemIndex = 0; itemIndex < index.items.length; itemIndex += 1) {
      if (index.items[itemIndex].id === chat.id) {
        index.items[itemIndex] = entry;
        replaced = true;
      }
    }
    if (!replaced) {
      index.items.push(entry);
    }
    await this.writeIndex(index);
  }

  private publishChatEvent(eventName: string, chat: ChatRecord): void {
    const payload: ChatEventPayload = {
      chat: this.copyChat(chat),
    };
    this.events.publish<ChatEventPayload>(eventName, payload);
  }

  private copyChat(chat: ChatRecord): ChatRecord {
    return {
      schemaVersion: chat.schemaVersion,
      id: chat.id,
      title: chat.title,
      characterId: chat.characterId,
      personaId: chat.personaId,
      archived: chat.archived,
      nextMessageId: chat.nextMessageId,
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
    };
  }

  private async readIndex(): Promise<ChatIndex> {
    const store = new JsonStore<ChatIndex>(this.files, this.indexPath());
    return store.read(this.defaultIndex());
  }

  private async writeIndex(index: ChatIndex): Promise<void> {
    const store = new JsonStore<ChatIndex>(this.files, this.indexPath());
    await store.write(index);
  }

  private async writeChat(chat: ChatRecord): Promise<void> {
    await this.files.ensureDirectory(this.chatDirectory(chat.id));
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath(chat.id));
    await store.write(chat);
  }

  private toIndexEntry(chat: ChatRecord, messageCount: number, previewMessage: string): ChatIndexEntry {
    return {
      id: chat.id,
      title: chat.title,
      characterId: chat.characterId,
      personaId: chat.personaId,
      archived: chat.archived,
      messageCount: messageCount,
      previewMessage: previewMessage,
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
    };
  }

  private defaultIndex(): ChatIndex {
    return {
      schemaVersion: 1,
      nextId: 1,
      items: new Array<ChatIndexEntry>(),
    };
  }

  private defaultChat(chatId: string): ChatRecord {
    return {
      schemaVersion: 1,
      id: chatId,
      title: '',
      characterId: '',
      personaId: '',
      archived: false,
      nextMessageId: 1,
      createdAt: 0,
      updatedAt: 0,
    };
  }

  private indexPath(): string {
    return `${this.chatsRoot()}/index.json`;
  }

  private chatPath(chatId: string): string {
    return `${this.chatDirectory(chatId)}/chat.json`;
  }

  private messagesPath(chatId: string): string {
    return `${this.chatDirectory(chatId)}/messages.jsonl`;
  }

  private chatDirectory(chatId: string): string {
    return `${this.chatsRoot()}/${safePathSegment(chatId, 'chat')}`;
  }

  private chatsRoot(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/chats`;
  }
}
