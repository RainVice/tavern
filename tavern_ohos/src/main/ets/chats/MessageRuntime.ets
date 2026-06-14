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
 * 提供消息读写管理能力，负责指定聊天下消息的新增、查询、更新、删除和排序，
 * 供对话页面中的消息发送、编辑、删除、滑动切换等操作调用。
 */
export class MessageRuntime {
  /**
   * 文件存储适配器，用于读写消息数据和聊天元数据。
   */
  private files: TavernFileStore;
  /**
   * 事件总线，用于发布消息新增、更新、删除等事件。
   */
  private events: EventBus;
  /**
   * 数据存储的根路径。
   */
  private rootPath: string;
  /**
   * 当前操作用户的标识。
   */
  private userId: string;
  /**
   * 消息所属的聊天标识。
   */
  private chatId: string;

  /**
   * 初始化当前运行时实例，在进入聊天对话页或进行消息操作时由 ChatRuntime.messages() 创建。
   * @param files 文件存储适配器，负责消息数据和聊天元数据的实际读写操作。
   * @param events 事件总线，用于在消息新增、更新、删除后发布事件通知 UI 或其它模块。
   * @param rootPath 数据存储的根路径，用于构建消息文件的存储目录结构。
   * @param userId 当前操作用户的标识，用于隔离不同用户的消息数据。
   * @param chatId 消息所属的聊天标识，用于定位消息 JSONL 文件和关联的聊天记录。
   */
  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string, chatId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
    this.chatId = chatId;
  }

  /**
   * 向当前聊天追加一条消息，在用户发送消息或 AI 生成回复时调用。
   * 流程：读取聊天记录 -> 分配消息 ID -> 根据 role 自动标记 isUser/isSystem -> 写入 JSONL -> 更新聊天元数据 -> 发布 message.added 事件。
   * @param params 包含发送者名称、角色标识和文本内容的消息创建参数，由输入框或 AI 回复提供。
   * @returns 添加后的消息副本，用于 UI 即时显示新消息。
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
   * 读取当前聊天的全部消息列表，在对话页面加载或消息刷新时调用。
   * @returns 按 index 升序排列的消息副本列表，用于渲染对话窗口的全部消息气泡。
   */
  async listMessages(): Promise<Array<ChatMessage>> {
    const store = this.messageStore();
    return this.copyMessages(await store.readAll());
  }

  /**
   * 根据消息标识查找单条消息，在需要获取特定消息详情时调用。
   * 消息不存在时抛出错误，由调用方处理。
   * @param messageId 要查找的消息标识，由消息操作（如编辑、删除）传入。
   * @returns 查找到的消息副本，用于编辑初始化或详情展示。
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
   * 按分页参数读取当前聊天的消息片段，在对话虚拟滚动或懒加载场景下调用以避免一次加载全部消息导致性能问题。
   * @param startIndex 分页起始索引（从 0 开始），由滚动位置计算得出。
   * @param limit 返回的最大消息数量，由分页配置决定。
   * @returns 位于指定范围内的消息副本列表，用于渲染可视区域内的消息气泡。
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
   * 更新指定消息的文本内容和系统标记，在用户编辑消息或修改消息类型时调用。
   * 流程：读取全部消息 -> 定位目标消息 -> 更新字段 -> 写回 JSONL -> 更新聊天时间戳 -> 发布 message.updated 事件。
   * @param messageId 要更新的消息标识，由编辑操作传入。
   * @param params 包含新文本内容和系统标记的更新参数，由编辑表单提供。
   * @returns 更新后的消息副本，用于 UI 刷新消息显示。
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
   * 删除指定消息，在用户删除单条消息时调用。
   * 流程：读取全部消息 -> 过滤移除目标消息 -> 重排剩余消息的 index -> 写回 JSONL -> 更新聊天时间戳 -> 发布 message.deleted 事件。
   * @param messageId 要删除的消息标识，由删除操作传入。
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
   * 批量删除多条消息，在用户选择多条消息批量删除时调用。
   * 任一标识不存在时抛出错误；每个已删除消息单独发布删除事件供 UI 逐个移除。
   * @param messageIds 要删除的消息标识列表，由多选删除操作传入。
   * @returns 成功删除的消息标识列表，用于删除结果确认。
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
   * 将指定消息移动到新位置，在用户通过拖拽或上下移动按钮调整消息顺序时调用。
   * 流程：读取全部消息 -> 计算目标位置（自动钳制到有效范围）-> 重新排列 -> 重写 index 序号 -> 写回 JSONL -> 发布 message.updated 事件。
   * @param messageId 要移动的消息标识，由移动操作传入。
   * @param targetIndex 目标位置的索引，超出范围会自动钳制到有效范围。
   * @returns 移动后的消息副本，用于 UI 刷新消息顺序。
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
   * 切换消息的隐藏状态，在用户隐藏或显示特定消息时调用。
   * 当前通过 isSystem 字段表示隐藏，调用方应避免把该字段用于其他语义。
   * @param messageId 要隐藏或显示的消息标识，由操作传入。
   * @param hidden true 表示隐藏消息（不在对话窗口显示），false 表示显示消息。
   * @returns 更新后的消息副本，用于 UI 刷新消息可见性。
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
   * 设置消息评分，在用户对 AI 回复进行打分时调用。
   * 评分限制在 0 到 5 之间，结果写入消息的 extraJson 字段用于后续排序和质量分析。
   * @param messageId 要设置评分的消息标识，由评分操作传入。
   * @param rating 评分值（0-5），超出范围会自动钳制。
   * @returns 更新后的消息副本，用于 UI 刷新评分显示。
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
   * 设置消息的书签状态，在用户标记或取消消息书签时调用。
   * 结果写入消息的 extraJson 字段，用于书签列表的快速定位。
   * @param messageId 要设置书签的消息标识，由书签操作传入。
   * @param bookmarked true 标记为书签，false 取消书签标记。
   * @returns 更新后的消息副本，用于 UI 刷新书签图标。
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
   * 解析消息 extraJson 字段，缺失字段或 JSON 非法时返回默认扩展数据。
   * @param extraJson 消息的扩展 JSON 字符串。
   * @returns 解析后的 MessageExtraData，包含评分、书签和分支信息。
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
   * 将消息扩展数据 MessageExtraData 序列化为 JSON 字符串。
   * @param extra 待序列化的消息扩展数据。
   * @returns 可用于 extraJson 字段的 JSON 字符串。
   */
  private writeExtra(extra: MessageExtraData): string {
    return JSON.stringify(extra);
  }

  /**
   * 更新当前聊天的最后修改时间，用于列表排序和同步判断。
   */
  private async touchChat(): Promise<void> {
    const chat = await this.readChat();
    chat.updatedAt = Date.now();
    await this.writeChat(chat);
  }

  /**
   * 通过事件总线发布消息事件，将变更通知给其他运行时或 UI 组件。
   * @param eventName 发布的事件名称。
   * @param message 关联的消息记录。
   */
  private publishMessageEvent(eventName: string, message: ChatMessage): void {
    const payload: MessageEventPayload = {
      chatId: this.chatId,
      message: this.copyMessage(message),
    };
    this.events.publish<MessageEventPayload>(eventName, payload);
  }

  /**
   * 复制消息列表的所有元素，避免外部代码持有内部可变对象。
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
   * 复制单条消息，确保 swipes 数组不会被外部直接修改。
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
   * 创建当前聊天消息 JSONL 文件的存储包装器。
   * @returns 绑定到当前聊天消息文件的 JsonlStore 实例。
   */
  private messageStore(): JsonlStore<ChatMessage> {
    return new JsonlStore<ChatMessage>(this.files, this.messagesPath());
  }

  /**
   * 读取当前聊天记录，文件不存在时抛出错误。
   * @returns 读取到的聊天记录。
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
   * 将聊天记录写回文件。
   * @param chat 要写入的聊天记录。
   */
  private async writeChat(chat: ChatRecord): Promise<void> {
    const store = new JsonStore<ChatRecord>(this.files, this.chatPath());
    await store.write(chat);
  }

  /**
   * 构造聊天文件缺失时使用的默认聊天记录。
   * @returns 默认空聊天记录。
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
   * @returns 聊天 JSON 文件的完整路径。
   */
  private chatPath(): string {
    return `${this.chatDirectory()}/chat.json`;
  }

  /**
   * 返回当前聊天消息 JSONL 文件路径。
   * @returns 消息 JSONL 文件的完整路径。
   */
  private messagesPath(): string {
    return `${this.chatDirectory()}/messages.jsonl`;
  }

  /**
   * 返回当前用户下当前聊天的数据目录。
   * @returns 聊天目录的完整路径。
   */
  private chatDirectory(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/chats/${safePathSegment(this.chatId, 'chat')}`;
  }
}
