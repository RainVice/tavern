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

/**
 * 提供聊天和消息相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ChatRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 数据根路径。
   */
  private rootPath: string;
  /**
   * 用户标识。
   */
  private userId: string;

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   * @param rootPath 数据根路径。
   * @param userId 用户标识。
   */
  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 创建新的聊天记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 读取聊天列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 按查询条件检索聊天和消息数据，并返回匹配结果。
   * @param query 检索条件。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 从外部数据导入Chat Jsonl 值，转换为当前运行时的数据结构。

   * @param title 标题。
   * @param characterId 目标角色标识。
   * @param personaId 目标用户人格标识。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 解析输入内容并转换为Imported Messages 列表结构。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private parseImportedMessages(jsonl: string): Array<ChatMessage> {
    const lines = jsonl.split('\n');
    const importedMessages = new Array<ChatMessage>();
    // next Message 标识。
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

  /**
   * 读取指定聊天，不存在时抛出错误。
   * @param chatId 目标聊天标识。
   * @returns 更新或读取后的记录副本。
   */
  async getChat(chatId: string): Promise<ChatRecord> {
    const exists = await this.files.exists(this.chatPath(chatId));
    if (!exists) {
      throw new Error(`Chat not found: ${chatId}`);
    }
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath(chatId));
    return this.copyChat(await store.read(this.defaultChat(chatId)));
  }

  /**
   * 更新聊天状态，必要时写回存储并发布对应事件。
   * @param chatId 目标聊天标识。
   * @param title 标题。
   */
  async renameChat(chatId: string, title: string): Promise<ChatRecord> {
    const chat = await this.getChat(chatId);
    chat.title = title;
    chat.updatedAt = Date.now();
    await this.writeChat(chat);
    await this.replaceIndexEntry(chat);
    this.publishChatEvent('chat.updated', chat);
    return this.copyChat(chat);
  }

  /**
   * 执行 archiveChat 的内部处理步骤，供当前模块复用。
   * @param chatId 目标聊天标识。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  async archiveChat(chatId: string, archived: boolean): Promise<ChatRecord> {
    const chat = await this.getChat(chatId);
    chat.archived = archived;
    chat.updatedAt = Date.now();
    await this.writeChat(chat);
    await this.replaceIndexEntry(chat);
    this.publishChatEvent('chat.updated', chat);
    return this.copyChat(chat);
  }

  /**
   * 执行 duplicateChat 的内部处理步骤，供当前模块复用。
   * @param chatId 目标聊天标识。
   * @param title 标题。
   */
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

  /**
   * 删除指定聊天，并清理相关索引或资源引用。
   * @param chatId 目标聊天标识。
   */
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

  /**
   * 导出聊天 JSONL，用于备份、迁移或与 SillyTavern 数据互通。
   * @param chatId 目标聊天标识。
   * @returns 可持久化或可传输的导出内容。
   */
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

  /**
   * 执行 messages 的内部处理步骤，供当前模块复用。
   * @param chatId 目标聊天标识。
   */
  messages(chatId: string): MessageRuntime {
    return new MessageRuntime(this.files, this.events, this.rootPath, this.userId, chatId);
  }

  /**
   * 把内部消息记录转换为聊天 JSONL 导出行。
   * @param message 消息记录。
   */
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

  /**
   * 解析Extra，非法输入会返回失败标记或空结果。
   * @param extraJson 扩展 JSON 字符串。
   */
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

  /**
   * 导出消息扩展 JSON 字符串，用于备份、迁移或与 SillyTavern 数据互通。

   * @returns 可持久化或可传输的导出内容。
   */
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

  /**
   * 复制Messages 列表，避免外部修改内部状态。
   * @param messages 消息列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyMessages(messages: Array<ChatMessage>): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push(this.copyMessage(messages[index]));
    }
    return result;
  }

  /**
   * 复制Message 值，避免外部修改内部状态。
   * @param message 消息记录。
   */
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

  /**
   * 删除指定DirectoryTree，并清理相关索引或资源引用。
   * @param path 目标文件或目录路径。
   */
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

  /**
   * 发布聊天和消息事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。
   * @param chat 聊天记录。
   */
  private publishChatEvent(eventName: string, chat: ChatRecord): void {
    const payload: ChatEventPayload = {
      chat: this.copyChat(chat),
    };
    this.events.publish<ChatEventPayload>(eventName, payload);
  }

  /**
   * 复制Chat 值，避免外部修改内部状态。
   * @param chat 聊天记录。
   */
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

  /**
   * 读取Index 值，并转换为运行时使用的数据结构。
   */
  private async readIndex(): Promise<ChatIndex> {
    const store = new JsonStore<ChatIndex>(this.files, this.indexPath());
    return store.read(this.defaultIndex());
  }

  /**
   * 写入Index 值，持久化当前运行时状态。
   * @param index 索引数据或循环位置。
   */
  private async writeIndex(index: ChatIndex): Promise<void> {
    const store = new JsonStore<ChatIndex>(this.files, this.indexPath());
    await store.write(index);
  }

  /**
   * 写入Chat 值，持久化当前运行时状态。
   * @param chat 聊天记录。
   */
  private async writeChat(chat: ChatRecord): Promise<void> {
    await this.files.ensureDirectory(this.chatDirectory(chat.id));
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath(chat.id));
    await store.write(chat);
  }

  /**
   * 把聊天完整记录转换为列表索引项。
   * @param chat 聊天记录。
   * @param messageCount 计数值。
   */
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
