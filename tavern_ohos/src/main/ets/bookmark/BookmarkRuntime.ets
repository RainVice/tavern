import { EventBus } from '../runtime/EventBus';
import type { ChatMessage } from '../chats/ChatModels';
import {
  BOOKMARK_NAME_TOKEN,
  BRANCH_NAME_TOKEN,
  type BookmarkCreatedPayload,
  type BookmarkExtra,
  type BookmarkMetadata,
  type BookmarkNameInput,
  type BookmarkResult,
  type BranchCreatedPayload,
  type BranchResult,
} from './BookmarkModels';

/**
 * 提供书签和分支相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class BookmarkRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的检查点记录，写入存储并返回副本。
   * @param messages 消息列表。
   * @param messageIndex 目标位置索引。

   * @param mainChatName main聊天名称。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  createCheckpoint(messages: Array<ChatMessage>, messageIndex: number, nameInput: BookmarkNameInput, mainChatName: string): BookmarkResult {
    this.requireMessage(messages, messageIndex);
    // 名称。
    const name = this.resolveName(nameInput, BOOKMARK_NAME_TOKEN);
    const updatedMessages = this.cloneMessages(messages);
    const target = updatedMessages[messageIndex];
    const extra = this.readExtra(target.extraJson);
    extra.bookmark_link = name;
    target.extraJson = this.writeExtra(extra);
    const metadata = this.makeMetadata(mainChatName);
    const result: BookmarkResult = {
      name: name,
      metadata: metadata,
      snapshot: this.snapshot(updatedMessages, messageIndex, undefined),
      updatedMessages: updatedMessages,
    };
    this.publishBookmark(result.name, target.id, result.metadata);
    return result;
  }

  /**
   * 创建新的分支记录，写入存储并返回副本。
   * @param messages 消息列表。
   * @param messageIndex 目标位置索引。

   * @param mainChatName main聊天名称。
   * @param swipeIndex 目标位置索引。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  createBranch(messages: Array<ChatMessage>, messageIndex: number, nameInput: BookmarkNameInput, mainChatName: string, swipeIndex?: number): BranchResult {
    this.requireMessage(messages, messageIndex);
    // 名称。
    const name = this.resolveName(nameInput, BRANCH_NAME_TOKEN);
    const updatedMessages = this.cloneMessages(messages);
    const target = updatedMessages[messageIndex];
    const extra = this.readExtra(target.extraJson);
    extra.branches.push(name);
    target.extraJson = this.writeExtra(extra);
    const metadata = this.makeMetadata(mainChatName);
    const result: BranchResult = {
      name: name,
      metadata: metadata,
      snapshot: this.snapshot(updatedMessages, messageIndex, swipeIndex),
      updatedMessages: updatedMessages,
    };
    this.publishBranch(result.name, target.id, result.metadata);
    return result;
  }

  /**
   * 执行 suggestCheckpointName 的内部处理步骤，供当前模块复用。
   * @param input 待处理的输入对象。
   */
  suggestCheckpointName(input: BookmarkNameInput): string {
    return this.resolveName(input, BOOKMARK_NAME_TOKEN);
  }

  /**
   * 执行 suggestBranchName 的内部处理步骤，供当前模块复用。
   * @param input 待处理的输入对象。
   */
  suggestBranchName(input: BookmarkNameInput): string {
    return this.resolveName(input, BRANCH_NAME_TOKEN);
  }

  /**
   * 根据当前上下文解析 名称，返回实际可用值。
   * @param input 待处理的输入对象。
   * @param token 待处理的 token。
   */
  private resolveName(input: BookmarkNameInput, token: string): string {
    if (input.forceName !== undefined && input.forceName.length > 0) {
      return input.forceName;
    }
    // base 名称。
    const baseName = this.stripGeneratedSuffix(input.currentChatName, token);
    let index = 1;
    let candidate = `${baseName} - ${token}${index}`;
    while (this.containsName(input.existingChatNames, candidate)) {
      index += 1;
      candidate = `${baseName} - ${token}${index}`;
    }
    return candidate;
  }
  private stripGeneratedSuffix(name: string, token: string): string {
    const marker = ` - ${token}`;
    const markerIndex = name.lastIndexOf(marker);
    if (markerIndex >= 0 && this.hasTrailingNumber(name, markerIndex + marker.length)) {
      return name.substring(0, markerIndex).trim();
    }
    if (name.indexOf(token) === 0) {
      const separator = ' - ';
      const separatorIndex = name.indexOf(separator);
      if (separatorIndex > 0) {
        return name.substring(separatorIndex + separator.length).trim();
      }
    }
    return name;
  }

  /**
   * 判断当前对象是否包含Trailing Number 值。
   * @param value 要保存或比较的字段值。
   * @param startIndex 分页起始索引。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  private hasTrailingNumber(value: string, startIndex: number): boolean {
    if (startIndex >= value.length) {
      return false;
    }
    for (let index = startIndex; index < value.length; index += 1) {
      const code = value.charCodeAt(index);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  /**
   * 检查Name是否满足当前规则。


   * @returns 条件命中时返回 true，否则返回 false。
   */
  private containsName(names: Array<string>, candidate: string): boolean {
    for (let index = 0; index < names.length; index += 1) {
      if (names[index] === candidate) {
        return true;
      }
    }
    return false;
  }
  private snapshot(messages: Array<ChatMessage>, messageIndex: number, swipeIndex: number | undefined): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index <= messageIndex; index += 1) {
      result.push(this.cloneMessage(messages[index]));
    }
    if (swipeIndex !== undefined) {
      this.applySwipe(result[messageIndex], swipeIndex);
    }
    return result;
  }
  private applySwipe(message: ChatMessage, swipeIndex: number): void {
    if (swipeIndex < 0 || swipeIndex >= message.swipes.length) {
      throw new Error(`Invalid swipe index: ${swipeIndex}`);
    }
    message.text = message.swipes[swipeIndex];
    message.activeSwipeIndex = swipeIndex;
  }

  /**
   * 读取Extra 值，并转换为运行时使用的数据结构。
   * @param extraJson 扩展 JSON 字符串。
   */
  private readExtra(extraJson: string): BookmarkExtra {
    const fallback: BookmarkExtra = {
      bookmark_link: '',
      branches: new Array<string>(),
    };
    if (extraJson.length === 0) {
      return fallback;
    }
    try {
      const parsed = JSON.parse(extraJson) as BookmarkExtra;
      return {
        bookmark_link: parsed.bookmark_link === undefined ? '' : parsed.bookmark_link,
        branches: parsed.branches === undefined ? new Array<string>() : parsed.branches.slice(),
      };
    } catch (error) {
      return fallback;
    }
  }

  /**
   * 写入Extra 值，持久化当前运行时状态。
   */
  private writeExtra(extra: BookmarkExtra): string {
    return JSON.stringify(extra);
  }

  /**
   * 复制Messages 列表，避免外部修改内部状态。
   * @param messages 消息列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneMessages(messages: Array<ChatMessage>): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push(this.cloneMessage(messages[index]));
    }
    return result;
  }

  /**
   * 复制Message 值，避免外部修改内部状态。
   * @param message 消息记录。
   */
  private cloneMessage(message: ChatMessage): ChatMessage {
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
   * 读取必须存在的Message 值，缺失时抛出错误。
   * @param messages 消息列表。
   * @param messageIndex 目标位置索引。
   */
  private requireMessage(messages: Array<ChatMessage>, messageIndex: number): void {
    if (messages.length === 0) {
      throw new Error('The chat is empty.');
    }
    if (messageIndex < 0 || messageIndex >= messages.length) {
      throw new Error(`Invalid message index: ${messageIndex}`);
    }
  }
  private makeMetadata(mainChatName: string): BookmarkMetadata {
    return {
      mainChat: mainChatName,
    };
  }

  /**
   * 发布书签和分支事件，把状态变化通知给宿主或其他 Runtime。
   * @param name 显示名称或注册名称。
   * @param messageId 目标消息标识。

   */
  private publishBookmark(name: string, messageId: string, metadata: BookmarkMetadata): void {
    const payload: BookmarkCreatedPayload = {
      name: name,
      messageId: messageId,
      metadata: this.copyMetadata(metadata),
    };
    this.events.publish<BookmarkCreatedPayload>('bookmark.created', payload);
  }

  /**
   * 发布书签和分支事件，把状态变化通知给宿主或其他 Runtime。
   * @param name 显示名称或注册名称。
   * @param messageId 目标消息标识。

   */
  private publishBranch(name: string, messageId: string, metadata: BookmarkMetadata): void {
    const payload: BranchCreatedPayload = {
      name: name,
      messageId: messageId,
      metadata: this.copyMetadata(metadata),
    };
    this.events.publish<BranchCreatedPayload>('bookmark.branch.created', payload);
  }

  /**
   * 复制Metadata 值，避免外部修改内部状态。
   */
  private copyMetadata(metadata: BookmarkMetadata): BookmarkMetadata {
    return {
      mainChat: metadata.mainChat,
    };
  }
}
