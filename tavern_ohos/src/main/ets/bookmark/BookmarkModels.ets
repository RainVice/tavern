import type { ChatMessage } from '../chats/ChatModels';

/**
 * 书签（Checkpoint）名称的前缀 token，用于生成形如 "Checkpoint #1" 的默认名称。
 */
export const BOOKMARK_NAME_TOKEN: string = 'Checkpoint #';
/**
 * 分支（Branch）名称的前缀 token，用于生成形如 "Branch #1" 的默认名称。
 */
export const BRANCH_NAME_TOKEN: string = 'Branch #';

/**
 * 描述调用书签和分支能力时需要传入的参数。
 */
export interface BookmarkNameInput {
  /**
   * 当前聊天会话的名称，用作生成默认书签/分支名称的基座。
   */
  currentChatName: string;
  /**
   * 当前实例中已存在聊天名称列表，用于避免生成重复名称。
   */
  existingChatNames: Array<string>;
  /**
   * 强制指定的名称，传入时将跳过自动生成逻辑直接使用该值。
   */
  forceName?: string;
}

/**
 * 描述书签和分支模块在运行时交换的数据结构。
 */
export interface BookmarkMetadata {
  /**
   * 所属主聊天会话名称。
   */
  mainChat: string;
}

/**
 * 描述书签和分支模块在运行时交换的数据结构。
 */
export interface BookmarkExtra {
  /**
   * 书签链接标识。
   */
  bookmark_link: string;
  /**
   * 从该检查点创建的分支列表。
   */
  branches: Array<string>;
}

/**
 * 书签操作的返回结果，包含生成名称、快照和更新后的消息列表。
 */
export interface BookmarkResult {
  /**
   * 生成的书签名称。
   */
  name: string;
  /**
   * 书签元数据，记录所属主聊天会话名。
   */
  metadata: BookmarkMetadata;
  /**
   * 从起始位置到书签标记点的消息快照副本。
   */
  snapshot: Array<ChatMessage>;
  /**
   * 更新了书签链接信息的消息列表副本。
   */
  updatedMessages: Array<ChatMessage>;
}

/**
 * 分支操作的返回结果，包含生成名称、快照和更新后的消息列表。
 */
export interface BranchResult {
  /**
   * 生成的分支名称。
   */
  name: string;
  /**
   * 分支元数据，记录所属主聊天会话名。
   */
  metadata: BookmarkMetadata;
  /**
   * 从起始位置到分支标记点的消息快照副本。
   */
  snapshot: Array<ChatMessage>;
  /**
   * 更新了分支信息的消息列表副本。
   */
  updatedMessages: Array<ChatMessage>;
}

/**
 * 书签创建事件发布时携带的数据载荷。
 */
export interface BookmarkCreatedPayload {
  /**
   * 创建的书签名称。
   */
  name: string;
  /**
   * 被标记的消息 ID。
   */
  messageId: string;
  /**
   * 书签关联的元数据。
   */
  metadata: BookmarkMetadata;
}

/**
 * 分支创建事件发布时携带的数据载荷。
 */
export interface BranchCreatedPayload {
  /**
   * 创建的分支名称。
   */
  name: string;
  /**
   * 被分支的消息 ID。
   */
  messageId: string;
  /**
   * 分支关联的元数据。
   */
  metadata: BookmarkMetadata;
}
