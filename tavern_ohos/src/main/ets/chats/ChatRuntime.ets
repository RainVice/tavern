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
 * 提供聊天和消息相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布，
 * 供聊天列表页、对话页面、消息管理流程等 UI 层调用。
 */
export class ChatRuntime {
  /**
   * 文件存储适配器，用于读写聊天数据和索引文件。
   */
  private files: TavernFileStore;
  /**
   * 事件总线，用于发布聊天创建、更新、删除等事件。
   */
  private events: EventBus;
  /**
   * 聊天数据存储的根路径。
   */
  private rootPath: string;
  /**
   * 当前操作用户的标识。
   */
  private userId: string;

  /**
   * 初始化当前运行时实例，在应用启动或进入聊天管理模块时调用。
   * @param files 文件存储适配器，负责聊天数据和索引文件的实际读写操作。
   * @param events 事件总线，用于在聊天创建、更新、删除后发布事件通知其他模块。
   * @param rootPath 数据存储的根路径，用于构建聊天文件的存储目录结构。
   * @param userId 当前操作用户的标识，用于隔离不同用户的聊天数据。
   */
  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 创建新的聊天记录，在用户通过聊天创建表单（选择角色和 persona）时调用。
   * 流程：分配自增唯一标识 -> 组装聊天记录 -> 写入文件存储 -> 更新索引 -> 发布 chat.created 事件。
   * @param params 包含标题、角色标识和 persona 标识的创建参数，由聊天创建表单提供。
   * @returns 写入存储后的聊天记录副本，用于 UI 跳转到新聊天对话页。
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
   * 重新整理聊天索引列表，在聊天列表页加载或刷新时调用。
   * 流程：遍历所有聊天 -> 读取完整记录和消息列表 -> 刷新消息数量和最后一条预览 -> 写回索引。
   * @returns 刷新后的聊天索引条目副本列表，用于聊天列表展示（含最新消息预览和消息计数）。
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
   * 根据标题或消息预览内容模糊搜索匹配的聊天记录，在用户使用聊天搜索功能时调用。
   * @param query 搜索关键词（大小写不敏感），由搜索输入框提供。
   * @returns 匹配的聊天索引条目列表，用于搜索结果展示。
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
   * 从聊天 JSONL 字符串导入消息数据，在用户从外部工具（如 SillyTavern）导入聊天备份时调用。
   * 流程：创建新聊天 -> 解析 JSONL 行 -> 批量写入消息 -> 刷新索引 -> 发布 chat.imported 事件。
   * @param jsonl 符合 SillyTavern 导出格式的 JSONL 字符串，由文件读取提供。
   * @param title 新聊天的标题，由用户输入或导入文件元数据提供。
   * @param characterId 关联的角色标识，由用户选择或导入文件元数据提供。
   * @param personaId 关联的用户人格标识，由用户选择或导入文件元数据提供。
   * @returns 导入完成后的聊天记录副本，用于 UI 跳转到新聊天对话页。
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
   * 解析聊天 JSONL 字符串，将每条导出行转为 ChatMessage 内部数据结构。
   * @param jsonl 聊天 JSONL 字符串，首行为包含元数据的 header。
   * @returns 解析后的 ChatMessage 列表。
   */
  private parseImportedMessages(jsonl: string): Array<ChatMessage> {
    const lines = jsonl.split('\n');
    const importedMessages = new Array<ChatMessage>();
    // 自增编号，用于生成导入消息的 id。
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
   * 根据聊天标识读取对应的聊天记录，在聊天对话页或详情页加载时调用。
   * 文件不存在时抛出错误，由调用方处理。
   * @param chatId 要读取的聊天标识，由路由参数或列表选择传入。
   * @returns 聊天记录的副本，用于 UI 展示和消息加载。
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
   * 更新指定聊天的标题，在用户重命名聊天时调用。
   * 流程：读取聊天记录 -> 更新 title 和 updatedAt -> 写回存储 -> 刷新索引 -> 发布 chat.updated 事件。
   * @param chatId 要重命名的聊天标识，由聊天列表选中项传入。
   * @param title 新的聊天标题，由用户输入提供。
   * @returns 更新后的聊天记录副本，用于 UI 刷新列表显示。
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
   * 设置聊天的归档状态，在用户归档或取消归档聊天时调用。
   * 归档后的聊天在列表中默认隐藏，用于整理不再活跃的对话。
   * @param chatId 要归档或取消归档的聊天标识，由聊天列表操作传入。
   * @param archived true 表示归档（从默认列表隐藏），false 表示取消归档（恢复显示）。
   * @returns 更新后的聊天记录副本，用于 UI 刷新列表。
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
   * 复制指定聊天及其全部消息，在用户点击聊天列表的"复制"按钮时调用。
   * 流程：读取原聊天和消息 -> 分配新 ID -> 写入存储 -> 刷新索引 -> 发布 chat.created 和 chat.duplicated 事件。
   * @param chatId 要复制的原聊天标识，由聊天列表选中项传入。
   * @param title 复制后的新聊天标题，由用户输入提供。
   * @returns 复制后的聊天记录副本，用于 UI 跳转到新聊天。
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
   * 删除指定聊天及其关联的所有文件，在用户确认删除聊天时调用。
   * 流程：读取聊天记录 -> 递归删除聊天目录（含消息文件）-> 从索引移除 -> 发布 chat.deleted 事件。
   * @param chatId 要删除的聊天标识，由聊天列表的删除操作传入。
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
   * 导出聊天 JSONL，在用户点击聊天导出按钮时调用，用于备份、迁移或与 SillyTavern 数据互通。
   * 流程：读取聊天和消息列表 -> 构建 header（含元数据）-> 逐消息转换为导出格式 -> 拼接 JSONL 字符串。
   * @param chatId 要导出的聊天标识，由聊天列表选中项传入。
   * @returns 符合 SillyTavern 导入格式的 JSONL 字符串，首行为包含聊天元数据的 header，可用于保存为文件。
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
   * 创建指定聊天的消息运行时实例，在需要读写该聊天下的消息时调用。
   * MessageRuntime 实例绑定到指定聊天，提供该聊天下所有消息的增删改查操作。
   * @param chatId 目标聊天标识，绑定消息运行时到该聊天。
   * @returns MessageRuntime 实例，绑定到指定聊天，用于操作该聊天的消息数据。
   */
  messages(chatId: string): MessageRuntime {
    return new MessageRuntime(this.files, this.events, this.rootPath, this.userId, chatId);
  }

  /**
   * 把内部消息记录转换为聊天 JSONL 导出行。
   * @param message 待转换的消息记录。
   * @returns 可用于 JSONL 导出的 ChatExportMessage 结构。
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
   * 解析消息扩展 JSON 字符串为 ChatExportExtra 结构，解析失败时将原文存入 source 字段。
   * @param extraJson 消息记录中的扩展 JSON 字符串。
   * @returns 解析后的 ChatExportExtra 结构。
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
   * 把 ChatExportExtra 结构序列化为消息扩展 JSON 字符串。
   * @param extra 待序列化的扩展数据。
   * @returns 可用于消息 extraJson 字段的 JSON 字符串。
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
   * 复制消息列表，避免外部修改内部状态。
   * @param messages 原消息列表。
   * @returns 消息列表的副本。
   */
  private copyMessages(messages: Array<ChatMessage>): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push(this.copyMessage(messages[index]));
    }
    return result;
  }

  /**
   * 复制单条消息，确保 swipes 等引用类型数组不会被外部直接修改。
   * @param message 原消息记录。
   * @returns 消息记录的副本。
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
   * @param path 要删除的目录路径。
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
   * 通过事件总线发布聊天事件，将状态变更通知给其他运行时或 UI 组件。
   * @param eventName 发布的事件名称。
   * @param chat 关联的聊天记录。
   */
  private publishChatEvent(eventName: string, chat: ChatRecord): void {
    const payload: ChatEventPayload = {
      chat: this.copyChat(chat),
    };
    this.events.publish<ChatEventPayload>(eventName, payload);
  }

  /**
   * 复制聊天记录的所有字段，避免外部代码持有内部可变引用。
   * @param chat 原聊天记录。
   * @returns 聊天记录的副本。
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
   * 从索引 JSON 文件中读取聊天索引数据。
   * @returns 读取到的 ChatIndex，文件不存在时返回默认索引。
   */
  private async readIndex(): Promise<ChatIndex> {
    const store = new JsonStore<ChatIndex>(this.files, this.indexPath());
    return store.read(this.defaultIndex());
  }

  /**
   * 将聊天索引数据写入索引 JSON 文件。
   * @param index 要持久化的索引数据。
   */
  private async writeIndex(index: ChatIndex): Promise<void> {
    const store = new JsonStore<ChatIndex>(this.files, this.indexPath());
    await store.write(index);
  }

  /**
   * 将聊天记录写入文件存储。
   * @param chat 要写入的聊天记录。
   */
  private async writeChat(chat: ChatRecord): Promise<void> {
    await this.files.ensureDirectory(this.chatDirectory(chat.id));
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath(chat.id));
    await store.write(chat);
  }

  /**
   * 把聊天完整记录转换为列表索引项，包含消息数量和预览文本。
   * @param chat 聊天记录。
   * @param messageCount 该聊天的消息数量。
   * @param previewMessage 最后一条消息的文本预览。
   * @returns 聊天索引条目。
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
