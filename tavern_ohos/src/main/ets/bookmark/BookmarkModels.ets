import type { ChatMessage } from '../chats/ChatModels';

/**
 * 定义生成书签和分支默认名称时使用的前缀令牌，用于在自动命名时标识书签名称。
 */
export const BOOKMARK_NAME_TOKEN: string = 'Checkpoint #';
/**
 * 定义生成书签和分支默认名称时使用的前缀令牌，用于在自动命名时标识分支名称。
 */
export const BRANCH_NAME_TOKEN: string = 'Branch #';

/**
 * 生成书签或分支名称时所需的输入参数，在创建检查点或分支时由调用方提供。
 */
export interface BookmarkNameInput {
  /**
   * 当前聊天的名称，用作生成书签或分支名称的基准名称。
   */
  currentChatName: string;
  /**
   * 已存在的聊天名称列表，用于避免生成重复名称。
   */
  existingChatNames: Array<string>;
  /**
   * 强制指定的名称，不为空时直接使用此值，跳过自动递增命名逻辑。
   */
  forceName?: string;
}

/**
 * 书签元数据，记录书签所属的主聊天名称，用于在分支导航中关联回原始聊天。
 */
export interface BookmarkMetadata {
  /**
   * 书签所在的主聊天名称，用于标识书签属于哪个聊天树。
   */
  mainChat: string;
}

/**
 * 消息扩展数据，记录关联的书签链接和所有分支名称，用于在聊天消息中标记检查点和分支信息。
 */
export interface BookmarkExtra {
  /**
   * 关联的书签名称（指向创建该书签的那个检查点），用于从消息跳转到书签快照。
   */
  bookmark_link: string;
  /**
   * 从该消息分出的所有分支名称列表，用于展示消息的分支导航。
   */
  branches: Array<string>;
}

/**
 * 创建书签的结果，包含书签名、元数据、消息快照和更新后的消息列表，用于通知调用方书签创建的状态。
 */
export interface BookmarkResult {
  /**
   * 书签名称，用于标识该书签在聊天列表中的位置。
   */
  name: string;
  /**
   * 书签元数据，记录关联的主聊天名称。
   */
  metadata: BookmarkMetadata;
  /**
   * 创建书签时的消息快照（从开头到标记消息为止），用于在恢复书签时还原消息状态。
   */
  snapshot: Array<ChatMessage>;
  /**
   * 更新了书签链接后的完整消息列表，用于持久化替换原始消息列表。
   */
  updatedMessages: Array<ChatMessage>;
}

/**
 * 创建分支的结果，包含分支名、元数据、消息快照和更新后的消息列表，用于通知调用方分支创建的状态。
 */
export interface BranchResult {
  /**
   * 分支名称，用于标识该分支在聊天树中的路径。
   */
  name: string;
  /**
   * 分支元数据，记录关联的主聊天名称。
   */
  metadata: BookmarkMetadata;
  /**
   * 创建分支时的消息快照（从开头到锚点消息为止），用于在分支间切换时恢复消息状态。
   */
  snapshot: Array<ChatMessage>;
  /**
   * 更新了分支信息后的完整消息列表，用于持久化替换原始消息列表。
   */
  updatedMessages: Array<ChatMessage>;
}

/**
 * 书签创建事件发布时携带的数据结构，用于通知其他模块书签已被创建。
 */
export interface BookmarkCreatedPayload {
  /**
   * 创建的书签名称，供事件订阅者更新聊天列表或导航结构。
   */
  name: string;
  /**
   * 创建书签所基于的消息标识，供事件订阅者关联书签到具体消息。
   */
  messageId: string;
  /**
   * 书签元数据，供事件订阅者获取书签所属的主聊天信息。
   */
  metadata: BookmarkMetadata;
}

/**
 * 分支创建事件发布时携带的数据结构，用于通知其他模块分支已被创建。
 */
export interface BranchCreatedPayload {
  /**
   * 创建的分支名称，供事件订阅者更新聊天树结构。
   */
  name: string;
  /**
   * 创建分支所基于的消息标识，供事件订阅者关联分支到具体消息。
   */
  messageId: string;
  /**
   * 分支元数据，供事件订阅者获取分支所属的主聊天信息。
   */
  metadata: BookmarkMetadata;
}
