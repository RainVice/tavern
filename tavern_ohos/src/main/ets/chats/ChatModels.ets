import type { ChatMessageRole } from '../contracts/PublicContracts';

/**
 * 描述调用聊天和消息能力时需要传入的参数。
 */
export interface ChatCreateParams {
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * 角色标识。
   */
  characterId: string;
  /**
   * persona 标识。
   */
  personaId: string;
}

/**
 * 描述聊天和消息持久化或内存索引中的一条记录。
 */
export interface ChatRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * 角色标识。
   */
  characterId: string;
  /**
   * persona 标识。
   */
  personaId: string;
  /**
   * archived 值，由当前实例内部维护。
   */
  archived: boolean;
  /**
   * next Message 标识。
   */
  nextMessageId: number;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述聊天和消息模块在运行时交换的数据结构。
 */
export interface ChatIndex {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * next 标识。
   */
  nextId: number;
  /**
   * 项目列表，由当前实例内部维护。
   */
  items: Array<ChatIndexEntry>;
}

/**
 * 描述聊天和消息持久化或内存索引中的一条记录。
 */
export interface ChatIndexEntry {
  /**
   * 标识。
   */
  id: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * 角色标识。
   */
  characterId: string;
  /**
   * persona 标识。
   */
  personaId: string;
  /**
   * archived 值，由当前实例内部维护。
   */
  archived: boolean;
  /**
   * message Count 值，由当前实例内部维护。
   */
  messageCount: number;
  /**
   * preview Message 值，由当前实例内部维护。
   */
  previewMessage: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述聊天和消息事件发布时携带的数据结构。
 */
export interface ChatEventPayload {
  /**
   * 聊天记录，由当前实例内部维护。
   */
  chat: ChatRecord;
}

/**
 * 描述调用聊天和消息能力时需要传入的参数。
 */
export interface ChatMessageCreateParams {
  /**
   * 名称。
   */
  name: string;
  /**
   * role 值，由当前实例内部维护。
   */
  role: ChatMessageRole;
  /**
   * 文本内容。
   */
  text: string;
}

/**
 * 描述调用聊天和消息能力时需要传入的参数。
 */
export interface ChatMessageUpdateParams {
  /**
   * 文本内容。
   */
  text: string;
  /**
   * is System 值，由当前实例内部维护。
   */
  isSystem: boolean;
}

/**
 * 描述聊天和消息模块在运行时交换的数据结构。
 */
export interface ChatMessage {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * 索引数据或循环位置，由当前实例内部维护。
   */
  index: number;
  /**
   * 名称。
   */
  name: string;
  /**
   * role 值，由当前实例内部维护。
   */
  role: ChatMessageRole;
  /**
   * is User 值，由当前实例内部维护。
   */
  isUser: boolean;
  /**
   * is System 值，由当前实例内部维护。
   */
  isSystem: boolean;
  /**
   * send Date 值，由当前实例内部维护。
   */
  sendDate: string;
  /**
   * 文本内容。
   */
  text: string;
  /**
   * swipes 列表，由当前实例内部维护。
   */
  swipes: Array<string>;
  /**
   * active Swipe Index 值，由当前实例内部维护。
   */
  activeSwipeIndex: number;
  /**
   * 扩展 JSON 字符串。
   */
  extraJson: string;
}

/**
 * 描述聊天和消息模块在运行时交换的数据结构。
 */
export interface MessageExtraData {
  /**
   * rating 值，由当前实例内部维护。
   */
  rating: number;
  /**
   * bookmarked 值，由当前实例内部维护。
   */
  bookmarked: boolean;
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
 * 描述聊天和消息事件发布时携带的数据结构。
 */
export interface MessageEventPayload {
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * 消息数据。
   */
  message: ChatMessage;
}

/**
 * 描述聊天和消息模块在运行时交换的数据结构。
 */
export interface ChatExportMetadata {
  /**
   * chat id 值，由当前实例内部维护。
   */
  chat_id: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * character id 值，由当前实例内部维护。
   */
  character_id: string;
  /**
   * persona id 值，由当前实例内部维护。
   */
  persona_id: string;
}

/**
 * 描述聊天和消息模块在运行时交换的数据结构。
 */
export interface ChatExportHeader {
  /**
   * chat metadata 值，由当前实例内部维护。
   */
  chat_metadata: ChatExportMetadata;
  /**
   * user name 值，由当前实例内部维护。
   */
  user_name: string;
  /**
   * character name 值，由当前实例内部维护。
   */
  character_name: string;
}

/**
 * 描述聊天和消息模块在运行时交换的数据结构。
 */
export interface ChatExportExtra {
  /**
   * rating 值，由当前实例内部维护。
   */
  rating?: number;
  /**
   * bookmarked 值，由当前实例内部维护。
   */
  bookmarked?: boolean;
  /**
   * bookmark link 值，由当前实例内部维护。
   */
  bookmark_link?: string;
  /**
   * branches 列表，由当前实例内部维护。
   */
  branches?: Array<string>;
  /**
   * 来源类型，由当前实例内部维护。
   */
  source?: string;
}

/**
 * 描述聊天和消息模块在运行时交换的数据结构。
 */
export interface ChatExportMessage {
  /**
   * 名称。
   */
  name?: string;
  /**
   * is user 值，由当前实例内部维护。
   */
  is_user?: boolean;
  /**
   * is system 值，由当前实例内部维护。
   */
  is_system?: boolean;
  /**
   * send date 值，由当前实例内部维护。
   */
  send_date?: string;
  /**
   * mes 列表，由当前实例内部维护。
   */
  mes?: string;
  /**
   * swipes 列表，由当前实例内部维护。
   */
  swipes?: Array<string>;
  /**
   * extra 值，由当前实例内部维护。
   */
  extra?: ChatExportExtra;
}
