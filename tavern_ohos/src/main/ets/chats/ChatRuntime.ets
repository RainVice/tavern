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
   * @param params 创建聊天所需的参数。
   * @returns 新创建的聊天记录副本。
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
   * @returns 聊天记录列表副本。
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
   * 按标题或预览文本查询聊天列表，不搜索消息内容。
   * @param query 查询关键字（大小写不敏感）。
   * @returns 符合条件的聊天索引项列表。
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
   * 从 JSONL 字符串导入聊天消息，转换为当前运行时的数据结构并持久化。
   * @param jsonl SillyTavern 兼容的聊天 JSONL 字符串。
   * @param title 聊天标题。
   * @param characterId 目标角色标识。
   * @param personaId 目标用户人格标识。
   * @returns 导入后的聊天记录副本。
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
   * 解析 JSONL 字符串，校验格式后返回消息数组，跳过无效行。
   * @returns 解析成功的消息列表。
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
   * 读取指定聊天记录，文件不存在时抛出错误。
   * @param chatId 目标聊天标识。
   * @returns 聊天记录副本。
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
   * 重命名聊天标题，写回存储并发布 chat.updated 事件。
   * @param chatId 目标聊天标识。
   * @param title 新标题。
   * @returns 更新后的聊天记录副本。
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
   * 切换聊天的归档状态，写回存储并发布 chat.updated 事件。
   * @param chatId 目标聊天标识。
   * @param archived 是否归档。
   * @returns 更新后的聊天记录副本。
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
   * 复制指定聊天的全部消息到新聊天中，含消息重新索引。
   * @param chatId 源聊天标识。
   * @param title 新聊天标题。
   * @returns 新创建的聊天记录副本。
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
   * 删除指定聊天记录、其消息文件和索引项，并发布 chat.deleted 事件。
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
   * 为指定聊天创建 MessageRuntime 实例。
   * @param chatId 目标聊天标识。
   * @returns 消息运行时实例。
   */
  messages(chatId: string): MessageRuntime {
    return new MessageRuntime(this.files, this.events, this.rootPath, this.userId, chatId);
  }

  /**
   * 把内部 ChatMessage 转换为 SillyTavern 兼容的导出格式。
   * @param message 内部消息记录。
   * @returns SillyTavern 导出行格式的消息对象。
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
   * 解析消息 extraJson 为导出格式，非法 JSON 时将原文放入 source 字段。
   * @param extraJson 消息扩展 JSON 字符串。
   * @returns 解析后的扩展数据对象。
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
   * 将导出扩展数据序列化为 extraJson 字符串，保留 source 原始字符串以供兼容。
   * @param extra 导出扩展格式的扩展数据。
   * @returns 持久化用的 JSON 字符串。
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
  /**
   * 获取最后一条消息的文本作为列表预览。
   */
  private preview(messages: Array<ChatMessage>): string {
    if (messages.length === 0) {
      return '';
    }
    return messages[messages.length - 1].text;
  }

  /**
   * 深拷贝消息列表，防止外部修改影响内部状态。
   * @param messages 源消息列表。
   * @returns 独立副本列表。
   */
  private copyMessages(messages: Array<ChatMessage>): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push(this.copyMessage(messages[index]));
    }
    return result;
  }

  /**
   * 深拷贝单条消息，确保 swipes 数组不被外部直接修改。
   * @param message 源消息。
   * @returns 独立副本。
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
   * 递归删除指定路径及其所有子文件和子目录。
   * @param path 文件或目录路径。
   */
  private async deleteDirectoryTree(path: string): Promise<void> {
    const children = await this.files.list(path);
    for (let index = 0; index < children.length; index += 1) {
      await this.deleteDirectoryTree(`${path}/${children[index]}`);
    }
    await this.files.delete(path);
  }
  /**
   * 用最新数据替换索引中的现有项，若不存在则追加。
   */
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
   * 发布聊天事件，通知其他模块聊天状态的变化。
   * @param eventName 事件名称（如 chat.created、chat.updated）。
   * @param chat 事件关联的聊天记录（将被复制）。
   */
  private publishChatEvent(eventName: string, chat: ChatRecord): void {
    const payload: ChatEventPayload = {
      chat: this.copyChat(chat),
    };
    this.events.publish<ChatEventPayload>(eventName, payload);
  }

  /**
   * 深拷贝聊天记录，防止外部修改影响内部状态。
   * @param chat 源聊天记录。
   * @returns 独立副本。
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
   * 从持久化存储中读取聊天索引，不存在时返回默认索引。
   * @returns 索引数据。
   */
  private async readIndex(): Promise<ChatIndex> {
    const store = new JsonStore<ChatIndex>(this.files, this.indexPath());
    return store.read(this.defaultIndex());
  }

  /**
   * 将聊天索引写回持久化存储。
   * @param index 待持久化的索引数据。
   */
  private async writeIndex(index: ChatIndex): Promise<void> {
    const store = new JsonStore<ChatIndex>(this.files, this.indexPath());
    await store.write(index);
  }

  /**
   * 将聊天记录写回持久化存储，确保目录存在。
   * @param chat 待持久化的聊天记录。
   */
  private async writeChat(chat: ChatRecord): Promise<void> {
    await this.files.ensureDirectory(this.chatDirectory(chat.id));
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath(chat.id));
    await store.write(chat);
  }

  /**
   * 将完整聊天记录转换为列表索引项，供 ChatIndex.items 使用。
   * @param chat 聊天记录。
   * @param messageCount 当前消息数。
   * @param previewMessage 最后一条消息的预览文本。
   * @returns 索引项。
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
  /**
   * 返回默认的聊天索引初始值。
   */
  private defaultIndex(): ChatIndex {
    return {
      schemaVersion: 1,
      nextId: 1,
      items: new Array<ChatIndexEntry>(),
    };
  }
  /**
   * 返回指定聊天的默认初始值，用于 JsonStore 读取失败时的回退。
   */
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
  /**
   * 返回聊天索引 JSON 文件的存储路径。
   */
  private indexPath(): string {
    return `${this.chatsRoot()}/index.json`;
  }
  /**
   * 返回指定聊天的元数据 JSON 文件路径。
   */
  private chatPath(chatId: string): string {
    return `${this.chatDirectory(chatId)}/chat.json`;
  }
  /**
   * 返回指定聊天的消息 JSONL 文件路径。
   */
  private messagesPath(chatId: string): string {
    return `${this.chatDirectory(chatId)}/messages.jsonl`;
  }
  /**
   * 返回指定聊天的数据目录路径。
   */
  private chatDirectory(chatId: string): string {
    return `${this.chatsRoot()}/${safePathSegment(chatId, 'chat')}`;
  }
  /**
   * 返回当前用户聊天数据的根目录路径。
   */
  private chatsRoot(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/chats`;
  }
}
