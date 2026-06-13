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

export class BookmarkRuntime {
  private events: EventBus;

  constructor(events: EventBus) {
    this.events = events;
  }

  createCheckpoint(messages: Array<ChatMessage>, messageIndex: number, nameInput: BookmarkNameInput, mainChatName: string): BookmarkResult {
    this.requireMessage(messages, messageIndex);
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

  createBranch(messages: Array<ChatMessage>, messageIndex: number, nameInput: BookmarkNameInput, mainChatName: string, swipeIndex?: number): BranchResult {
    this.requireMessage(messages, messageIndex);
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

  suggestCheckpointName(input: BookmarkNameInput): string {
    return this.resolveName(input, BOOKMARK_NAME_TOKEN);
  }

  suggestBranchName(input: BookmarkNameInput): string {
    return this.resolveName(input, BRANCH_NAME_TOKEN);
  }

  private resolveName(input: BookmarkNameInput, token: string): string {
    if (input.forceName !== undefined && input.forceName.length > 0) {
      return input.forceName;
    }
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

  private writeExtra(extra: BookmarkExtra): string {
    return JSON.stringify(extra);
  }

  private cloneMessages(messages: Array<ChatMessage>): Array<ChatMessage> {
    const result = new Array<ChatMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push(this.cloneMessage(messages[index]));
    }
    return result;
  }

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

  private publishBookmark(name: string, messageId: string, metadata: BookmarkMetadata): void {
    const payload: BookmarkCreatedPayload = {
      name: name,
      messageId: messageId,
      metadata: this.copyMetadata(metadata),
    };
    this.events.publish<BookmarkCreatedPayload>('bookmark.created', payload);
  }

  private publishBranch(name: string, messageId: string, metadata: BookmarkMetadata): void {
    const payload: BranchCreatedPayload = {
      name: name,
      messageId: messageId,
      metadata: this.copyMetadata(metadata),
    };
    this.events.publish<BranchCreatedPayload>('bookmark.branch.created', payload);
  }

  private copyMetadata(metadata: BookmarkMetadata): BookmarkMetadata {
    return {
      mainChat: metadata.mainChat,
    };
  }
}
