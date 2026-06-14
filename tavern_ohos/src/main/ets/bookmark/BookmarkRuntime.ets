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
   * 创建书签，在指定消息上附加书签链接并将更新后的消息列表和快照一并返回。
   * @param messages 原始消息列表。
   * @param messageIndex 要标记书签的消息索引。
   * @param nameInput 名称生成输入参数。
   * @param mainChatName 书签所属的主聊天会话名称。
   * @returns 包含书签名称、快照和更新后消息列表的结果对象。
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
   * 创建分支，在指定消息上附加分支引用并将更新后的消息列表和快照一并返回。
   * @param messages 原始消息列表。
   * @param messageIndex 要创建分支的消息索引。
   * @param nameInput 名称生成输入参数。
   * @param mainChatName 分支所属的主聊天会话名称。
   * @param swipeIndex 可选；生成快照时指定的 swipe 索引。
   * @returns 包含分支名称、快照和更新后消息列表的结果对象。
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
   * 根据会话上下文自动推荐一个书签名称。
   * @param input 包含当前聊天名称、已有名称列表和可选强制名称的输入。
   * @returns 推荐的书签名称。
   */
  suggestCheckpointName(input: BookmarkNameInput): string {
    return this.resolveName(input, BOOKMARK_NAME_TOKEN);
  }

  /**
   * 根据会话上下文自动推荐一个分支名称。
   * @param input 包含当前聊天名称、已有名称列表和可选强制名称的输入。
   * @returns 推荐的分支名称。
   */
  suggestBranchName(input: BookmarkNameInput): string {
    return this.resolveName(input, BRANCH_NAME_TOKEN);
  }

  /**
   * 根据输入上下文和前缀 token 解析出最终的可用名称。
   * @param input 名称生成输入参数。
   * @param token 名称前缀 token（如 "Checkpoint #" 或 "Branch #"）。
   * @returns 解析后的名称字符串。
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
   * 判断字符串从指定位置开始是否全为数字字符。
   * @param value 要检查的字符串。
   * @param startIndex 检查起始索引。
   * @returns 从 startIndex 到末尾全为数字时返回 true，否则返回 false。
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
   * 检查名称列表中是否已存在指定候选项。
   * @param names 已有名称列表。
   * @param candidate 待检查的候选项。
   * @returns 存在时返回 true，否则返回 false。
   */
  private containsName(names: Array<string>, candidate: string): boolean {
    for (let index = 0; index < names.length; index += 1) {
      if (names[index] === candidate) {
        return true;
      }
    }
    return false;
  }
  /**
   * 从消息列表中截取从开头到指定索引的消息，并按可选的 swipe 索引替换最后一条消息的文本内容。
   * @param messages 原始消息列表。
   * @param messageIndex 截取结束索引。
   * @param swipeIndex 可选；指定快照最终消息使用的 swipe 项索引。
   * @returns 快照消息列表副本。
   */
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
  /**
   * 将消息的 text 和 activeSwipeIndex 替换为指定 swipe 项的内容。
   * @param message 要应用 swipe 的消息。
   * @param swipeIndex 指定的 swipe 索引。
   */
  private applySwipe(message: ChatMessage, swipeIndex: number): void {
    if (swipeIndex < 0 || swipeIndex >= message.swipes.length) {
      throw new Error(`Invalid swipe index: ${swipeIndex}`);
    }
    message.text = message.swipes[swipeIndex];
    message.activeSwipeIndex = swipeIndex;
  }

  /**
   * 解析 extraJson 字符串为 BookmarkExtra 结构，解析失败时返回默认空值。
   * @param extraJson 消息的扩展 JSON 字符串。
   * @returns 解析后的 BookmarkExtra 对象。
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
   * 将 BookmarkExtra 序列化为 JSON 字符串。
   * @param extra 要持久化的书签扩展数据。
   * @returns 序列化后的 JSON 字符串。
   */
  private writeExtra(extra: BookmarkExtra): string {
    return JSON.stringify(extra);
  }

  /**
   * 深拷贝消息列表，返回独立副本。
   * @param messages 原始消息列表。
   * @returns 独立副本数组。
   */
  private cloneMessages(messages: Array<ChatMessage>): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push(this.cloneMessage(messages[index]));
    }
    return result;
  }

  /**
   * 深拷贝单条消息，返回独立副本。
   * @param message 原始消息。
   * @returns 消息的深拷贝副本。
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
   * 校验消息列表和索引的有效性，无效时抛出错误。
   * @param messages 消息列表。
   * @param messageIndex 要检查的消息索引。
   */
  private requireMessage(messages: Array<ChatMessage>, messageIndex: number): void {
    if (messages.length === 0) {
      throw new Error('The chat is empty.');
    }
    if (messageIndex < 0 || messageIndex >= messages.length) {
      throw new Error(`Invalid message index: ${messageIndex}`);
    }
  }
  /**
   * 根据主聊天名称构建 BookmarkMetadata 对象。
   * @param mainChatName 主聊天会话名称。
   * @returns 新创建的 BookmarkMetadata 实例。
   */
  private makeMetadata(mainChatName: string): BookmarkMetadata {
    return {
      mainChat: mainChatName,
    };
  }

  /**
   * 发布书签创建事件，通知监听方状态变化。
   * @param name 创建的书签名称。
   * @param messageId 被标记的消息 ID。
   * @param metadata 书签元数据。
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
   * 发布分支创建事件，通知监听方状态变化。
   * @param name 创建的分支名称。
   * @param messageId 被分支的消息 ID。
   * @param metadata 分支元数据。
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
   * 浅拷贝 BookmarkMetadata，避免外部修改影响内部状态。
   * @param metadata 原始元数据。
   * @returns 元数据的浅拷贝副本。
   */
  private copyMetadata(metadata: BookmarkMetadata): BookmarkMetadata {
    return {
      mainChat: metadata.mainChat,
    };
  }
}
