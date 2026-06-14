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
 * 在聊天对话的对话分支、检查点保存等流程中被调用，用于创建和管理消息历史的分支结构。
 */
export class BookmarkRuntime {
  /**
   * 事件总线，用于发布书签和分支创建事件通知其他模块。
   */
  private events: EventBus;

  /**
   * 初始化当前运行时实例，由宿主在应用启动时通过依赖注入创建。
   * @param events 事件总线，用于发布书签和分支创建事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建检查点（书签）：备份当前消息状态，在目标消息添加书签链接，并发布书签创建事件。
   * 在聊天界面中用户点击"创建检查点"按钮时触发，用于保存会话快照以便后续恢复。
   * @param messages 当前聊天的完整消息列表，作为创建书签的源数据。
   * @param messageIndex 要创建书签的目标消息索引，书签将标记在该消息上。
   * @param nameInput 书签名称生成所需的输入参数，包含当前聊天名称和已有名称列表。
   * @param mainChatName 书签所属的主聊天名称，用于元数据中关联回原始聊天。
   * @returns 书签结果，包含名称、消息快照和更新后的消息列表。
   */
  createCheckpoint(messages: Array<ChatMessage>, messageIndex: number, nameInput: BookmarkNameInput, mainChatName: string): BookmarkResult {
    this.requireMessage(messages, messageIndex);
    // 解析书签或分支的唯一名称（自动递增或使用 forceName）
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
   * 创建分支：备份当前消息状态，在目标消息中添加分支名称，并发布分支创建事件。
   * 在聊天界面中用户点击"创建分支"按钮时触发，用于从当前消息衍生出新分支。
   * @param messages 当前聊天的完整消息列表，作为创建分支的源数据。
   * @param messageIndex 分支锚点的消息索引，分支将从该消息之后开始分叉。
   * @param nameInput 分支名称生成所需的输入参数，包含当前聊天名称和已有名称列表。
   * @param mainChatName 分支所属的主聊天名称，用于元数据中关联回原始聊天。
   * @param swipeIndex 可选的滑动索引，指定快照中使用的备选回复，用于分支切换时选择特定回复。
   * @returns 分支结果，包含名称、消息快照和更新后的消息列表。
   */
  createBranch(messages: Array<ChatMessage>, messageIndex: number, nameInput: BookmarkNameInput, mainChatName: string, swipeIndex?: number): BranchResult {
    this.requireMessage(messages, messageIndex);
    // 解析书签或分支的唯一名称（自动递增或使用 forceName）
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
   * 根据输入生成建议的检查点名称（不实际创建书签），用于在 UI 中预览名称。
   * @param input 名称生成所需的输入参数，包含当前聊天名称和已有名称列表。
   * @returns 建议的检查点名称，可直接在 UI 中显示。
   */
  suggestCheckpointName(input: BookmarkNameInput): string {
    return this.resolveName(input, BOOKMARK_NAME_TOKEN);
  }

  /**
   * 根据输入生成建议的分支名称（不实际创建分支），用于在 UI 中预览名称。
   * @param input 名称生成所需的输入参数，包含当前聊天名称和已有名称列表。
   * @returns 建议的分支名称，可直接在 UI 中显示。
   */
  suggestBranchName(input: BookmarkNameInput): string {
    return this.resolveName(input, BRANCH_NAME_TOKEN);
  }

  /**
   * 解析名称：优先使用 forceName，否则基于当前聊天名称和令牌自动生成一个不重复的名称。
   * 在创建书签、分支或建议名称时统一调用，确保名称的唯一性和可读性。
   * @param input 名称生成所需的输入参数，包含当前聊天名称和已有名称列表。
   * @param token 名称前缀令牌（如 "Checkpoint #" 或 "Branch #"），用于标识名称类型。
   * @returns 解析后的实际名称，保证与 existingChatNames 中的名称不重复。
   */
  private resolveName(input: BookmarkNameInput, token: string): string {
    if (input.forceName !== undefined && input.forceName.length > 0) {
      return input.forceName;
    }
    // 基础名称：去除已生成的令牌后缀
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
   * 检查字符串从指定位置开始是否全部由数字字符组成，用于判断名称后缀是否为自动生成的编号。
   * @param value 要检查的字符串，通常是聊天名称的后缀部分。
   * @param startIndex 开始检查的起始索引，从检测到令牌后的位置开始。
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
   * 检查候选名称是否与已有名称列表中的任意项重复，用于确保生成的名称唯一。
   * @param names 已有名称列表，通常是当前用户的全部聊天名称。
   * @param candidate 待检查的候选名称。
   * @returns 存在重复时返回 true，否则返回 false。
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
   * 从消息的 extraJson 中解析 BookmarkExtra 数据，用于提取消息上的书签链接和分支信息。
   * @param extraJson 消息的扩展 JSON 字符串，可能包含 bookmark_link 和 branches 字段。
   * @returns 解析后的 BookmarkExtra，解析失败或 extraJson 为空时返回空值默认对象。
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
   * 将 BookmarkExtra 序列化为 JSON 字符串，用于持久化到消息的 extraJson 字段。
   */
  private writeExtra(extra: BookmarkExtra): string {
    return JSON.stringify(extra);
  }

  /**
   * 深度复制消息列表，防止外部修改内部状态，用于创建书签或分支时生成消息快照。
   * @param messages 要复制的源消息列表，原列表不会被修改。
   * @returns 元素相同但独立的消息数组，调用方可安全修改。
   */
  private cloneMessages(messages: Array<ChatMessage>): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push(this.cloneMessage(messages[index]));
    }
    return result;
  }

  /**
   * 深度复制单条消息，生成值副本，防止外部修改内部状态，用于创建快照时的消息深拷贝。
   * @param message 要复制的源消息对象，原对象不会被修改。
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
   * 校验消息列表和索引的有效性，无效时抛出异常，用于创建书签或分支前的参数校验。
   * @param messages 消息列表，校验是否为空。
   * @param messageIndex 要校验的消息索引，校验是否在有效范围内。
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
   * 发布书签创建事件，将书签状态变化通知给宿主或其他模块。
   * @param name 书签名称，用于事件载荷中标识书签。
   * @param messageId 书签锚点的消息标识，用于事件载荷中关联书签到具体消息。
   * @param metadata 书签元数据，包含关联的主聊天名称。
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
   * 发布分支创建事件，将分支状态变化通知给宿主或其他模块。
   * @param name 分支名称，用于事件载荷中标识分支。
   * @param messageId 分支锚点的消息标识，用于事件载荷中关联分支到具体消息。
   * @param metadata 分支元数据，包含关联的主聊天名称。
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
   * 复制书签元数据，生成值副本，防止外部修改内部状态，用于事件发布时构造载荷。
   */
  private copyMetadata(metadata: BookmarkMetadata): BookmarkMetadata {
    return {
      mainChat: metadata.mainChat,
    };
  }
}
