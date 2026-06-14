import type { ChatMessage } from '../chats/ChatModels';

/**
 * 定义书签和分支模块使用的固定配置值。
 */
export const BOOKMARK_NAME_TOKEN: string = 'Checkpoint #';
/**
 * 定义书签和分支模块使用的固定配置值。
 */
export const BRANCH_NAME_TOKEN: string = 'Branch #';

/**
 * 描述调用书签和分支能力时需要传入的参数。
 */
export interface BookmarkNameInput {
  /**
   * current Chat 名称。
   */
  currentChatName: string;
  /**
   * existing Chat Names 列表，由当前实例内部维护。
   */
  existingChatNames: Array<string>;
  /**
   * force 名称。
   */
  forceName?: string;
}

/**
 * 描述书签和分支模块在运行时交换的数据结构。
 */
export interface BookmarkMetadata {
  /**
   * main Chat 值，由当前实例内部维护。
   */
  mainChat: string;
}

/**
 * 描述书签和分支模块在运行时交换的数据结构。
 */
export interface BookmarkExtra {
  /**
   * bookmark link 值，由当前实例内部维护。
   */
  bookmark_link: string;
  /**
   * branches 列表，由当前实例内部维护。
   */
  branches: Array<string>;
}

/**
 * 描述书签和分支操作完成后返回给调用方的结果。
 */
export interface BookmarkResult {
  /**
   * 名称。
   */
  name: string;
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: BookmarkMetadata;
  /**
   * snapshot 值，由当前实例内部维护。
   */
  snapshot: Array<ChatMessage>;
  /**
   * updated Messages 列表，由当前实例内部维护。
   */
  updatedMessages: Array<ChatMessage>;
}

/**
 * 描述书签和分支操作完成后返回给调用方的结果。
 */
export interface BranchResult {
  /**
   * 名称。
   */
  name: string;
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: BookmarkMetadata;
  /**
   * snapshot 值，由当前实例内部维护。
   */
  snapshot: Array<ChatMessage>;
  /**
   * updated Messages 列表，由当前实例内部维护。
   */
  updatedMessages: Array<ChatMessage>;
}

/**
 * 描述书签和分支事件发布时携带的数据结构。
 */
export interface BookmarkCreatedPayload {
  /**
   * 名称。
   */
  name: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: BookmarkMetadata;
}

/**
 * 描述书签和分支事件发布时携带的数据结构。
 */
export interface BranchCreatedPayload {
  /**
   * 名称。
   */
  name: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: BookmarkMetadata;
}
