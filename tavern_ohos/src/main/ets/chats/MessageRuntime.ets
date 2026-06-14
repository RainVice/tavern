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

/**
 * 提供消息相关的无 UI 运行时能力，负责消息的增删改查、Swipe 管理和事件发布。
 */
export class MessageRuntime {
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
   * 聊天标识。
   */
  private chatId: string;

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   * @param rootPath 数据根路径。
   * @param userId 用户标识。
   * @param chatId 聊天标识。
   */
  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string, chatId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
    this.chatId = chatId;
  }

  /**
   * 向当前聊天追加一条消息，更新聊天元数据，写入消息 JSONL，并发布 message.added 事件。
   * @param params 创建消息所需的参数。
   */
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

  /**
   * 读取当前聊天的全部消息。
   * @returns 按 index 排列的消息副本列表，修改返回值不会直接写回存储。
   */
  async listMessages(): Promise<Array<ChatMessage>> {
    const store = this.messageStore();
    return this.copyMessages(await store.readAll());
  }

  /**
   * 读取指定消息，不存在时抛出错误。
   * @param messageId 目标消息标识。
   * @returns 消息记录副本。
   */
  async getMessage(messageId: string): Promise<ChatMessage> {
    const messages = await this.listMessages();
    for (let index = 0; index < messages.length; index += 1) {
      if (messages[index].id === messageId) {
        return this.copyMessage(messages[index]);
      }
    }
    throw new Error('消息未找到: ' + messageId);
  }

  /**
   * 按分页参数读取当前聊天的消息片段。
   * @param startIndex 分页起始索引（从 0 开始）。
   * @param limit 返回数量上限。
   * @returns 位于指定范围内的消息副本列表。
   */
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

  /**
   * 更新指定消息，写回存储并按需发布变更事件。
   * @param messageId 目标消息标识。
   * @param params 更新消息所需的参数。
   * @returns 消息记录副本。
   */
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

  /**
   * 删除指定消息，重排剩余消息索引，并发布 message.deleted 事件。
   * @param messageId 目标消息标识。
   */
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

  /**
   * 批量删除消息，任何一个标识不存在时会抛出错误。
   * @param messageIds 要删除的消息标识列表。
   * @returns 成功删除的消息标识列表。
   */
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

  /**
   * 移动消息到指定位置，重排全部 index，并发布 message.updated 事件。
   * @param messageId 目标消息标识。
   * @param targetIndex 目标位置索引。
   */
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

  /**
   * 切换消息的隐藏状态。
   *
   * 当前实现通过 isSystem 表示隐藏状态，因此调用方应避免同时把该字段用于其他语义。
   * @param messageId 目标消息标识。
   * @param hidden 是否隐藏该消息。
   * @returns 更新后的消息副本。
   */
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

  /**
   * 设置消息评分，评分会被限制在 0 到 5 之间并写入 extraJson。
   * @param messageId 目标消息标识。
   * @param rating 调用方给出的评分值。
   * @returns 更新后的消息副本。
   */
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

  /**
   * 设置消息书签状态，结果写入 extraJson。
   * @param messageId 目标消息标识。
   * @param bookmarked 是否标记为书签。
   * @returns 更新后的消息副本。
   */
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

  /**
   * 解析消息 extraJson，字段缺失或 JSON 非法时返回默认扩展数据。
   * @param extraJson 消息扩展 JSON 字符串。
   * @returns 解析后的扩展数据。
   */
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

  /**
   * 把消息扩展数据序列化成 extraJson 字符串。
   * @param extra 要保存的消息扩展数据。
   */
  private writeExtra(extra: MessageExtraData): string {
    return JSON.stringify(extra);
  }

  /**
   * 更新当前聊天的修改时间，用于列表排序和同步判断。
   */
  private async touchChat(): Promise<void> {
    const chat = await this.readChat();
    chat.updatedAt = Date.now();
    await this.writeChat(chat);
  }

  /**
   * 发布消息事件，通知其他模块消息状态的变化。
   * @param eventName 事件名称（如 message.added、message.updated）。
   * @param message 事件关联的消息（将被复制）。
   */
  private publishMessageEvent(eventName: string, message: ChatMessage): void {
    const payload: MessageEventPayload = {
      chatId: this.chatId,
      message: this.copyMessage(message),
    };
    this.events.publish<MessageEventPayload>(eventName, payload);
  }

  /**
   * 批量复制消息列表，确保 swipes 数组不被外部直接修改。
   * @param messages 消息列表。
   * @returns 消息副本列表。
   */
  private copyMessages(messages: Array<ChatMessage>): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push(this.copyMessage(messages[index]));
    }
    return result;
  }

  /**
   * 复制单条消息，确保 swipes 数组不被外部直接修改。
   * @param message 消息记录。
   * @returns 消息副本。
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
   * 创建当前聊天消息 JSONL 文件的存储包装器。
   */
  private messageStore(): JsonlStore<ChatMessage> {
    return new JsonlStore<ChatMessage>(this.files, this.messagesPath());
  }

  /**
   * 读取当前聊天记录，文件不存在时抛出错误。
   * @returns 聊天记录。
   */
  private async readChat(): Promise<ChatRecord> {
    const exists = await this.files.exists(this.chatPath());
    if (!exists) {
      throw new Error(`Chat not found: ${this.chatId}`);
    }
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath());
    return store.read(this.defaultChat());
  }

  /**
   * 写回当前聊天记录。
   * @param chat 待持久化的聊天记录。
   */
  private async writeChat(chat: ChatRecord): Promise<void> {
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath());
    await store.write(chat);
  }

  /**
   * 构造 JsonStore 读取失败时使用的聊天默认值。
   */
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

  /**
   * 返回当前聊天元数据文件路径。
   */
  private chatPath(): string {
    return `${this.chatDirectory()}/chat.json`;
  }

  /**
   * 返回当前聊天消息 JSONL 文件路径。
   */
  private messagesPath(): string {
    return `${this.chatDirectory()}/messages.jsonl`;
  }

  /**
   * 返回当前用户下当前聊天的数据目录。
   */
  private chatDirectory(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/chats/${safePathSegment(this.chatId, 'chat')}`;
  }
}
