import type { ChatMessageRole } from '../contracts/PublicContracts';

/**
 * 创建聊天时所需的参数。
 */
export interface ChatCreateParams {
  /**
   * 聊天标题，存储于记录中由写入流程自动填充。
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
 * 聊天记录的完整数据对象，包含所有元数据字段。
 */
export interface ChatRecord {
  /**
   * 数据结构的 schema 版本号，用于持久化迁移判断。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * 聊天标题，由创建/更新操作写入记录。
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
   * 归档标记，标记聊天是否已归档隐藏。
   */
  archived: boolean;
  /**
   * 下一条消息的自增 ID，用于消息序号分配。
   */
  nextMessageId: number;
  /**
   * 记录的创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录的最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 聊天索引，维护聊天列表的元数据和自增 ID 生成器。
 */
export interface ChatIndex {
  /**
   * 索引结构的 schema 版本号，用于数据迁移判断。
   */
  schemaVersion: number;
  /**
   * 下一个聊天记录的自增 ID 值。
   */
  nextId: number;
  /**
   * 聊天索引条目列表，按顺序维护所有聊天的元数据摘要。
   */
  items: Array<ChatIndexEntry>;
}

/**
 * 聊天列表中的索引项，包含预览信息和消息计数，不包含完整聊天数据。
 */
export interface ChatIndexEntry {
  /**
   * 标识。
   */
  id: string;
  /**
   * 聊天标题，从索引同步写入以供列表展示。
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
   * 归档标记，索引中同步维护以支持过滤查询。
   */
  archived: boolean;
  /**
   * 聊天中的消息总数。
   */
  messageCount: number;
  /**
   * 最后一条消息的预览文本，用于列表展示。
   */
  previewMessage: string;
  /**
   * 索引条目的创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 索引条目的更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 聊天事件的载荷，包含变更后的聊天记录。
 */
export interface ChatEventPayload {
  /**
   * 事件关联的聊天记录。
   */
  chat: ChatRecord;
}

/**
 * 创建消息时所需的参数。
 */
export interface ChatMessageCreateParams {
  /**
   * 名称。
   */
  name: string;
  /**
   * 消息角色（user/assistant/system），确定消息发送者身份。
   */
  role: ChatMessageRole;
  /**
   * 文本内容。
   */
  text: string;
}

/**
 * 更新消息时所需的参数。
 */
export interface ChatMessageUpdateParams {
  /**
   * 文本内容。
   */
  text: string;
  /**
   * 是否为系统内部消息标记，影响渲染和导出行为。
   */
  isSystem: boolean;
}

/**
 * 单条消息的完整数据对象，包含内容、角色、Swipe 列表和扩展数据。
 */
export interface ChatMessage {
  /**
   * 数据结构的 schema 版本号，用于持久化迁移判断。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * 消息在聊天中的序号位置。
   */
  index: number;
  /**
   * 名称。
   */
  name: string;
  /**
   * 消息角色（user/assistant/system），确定发送者身份。
   */
  role: ChatMessageRole;
  /**
   * 是否为用户发送的消息，角色辅助判断标记。
   */
  isUser: boolean;
  /**
   * 是否为系统内部消息标记，影响渲染和导出行为。
   */
  isSystem: boolean;
  /**
   * 消息发送时间字符串（ISO 格式），用于界面展示。
   */
  sendDate: string;
  /**
   * 文本内容。
   */
  text: string;
  /**
   * 消息的 Swipe 备选回复列表，支持用户切换查看不同回复。
   */
  swipes: Array<string>;
  /**
   * 当前激活的 Swipe 索引，指定 swipes 列表中有效显示的条目。
   */
  activeSwipeIndex: number;
  /**
   * 扩展 JSON 字符串。
   */
  extraJson: string;
}

/**
 * 消息的扩展元数据，存储在 extraJson 字段中。
 */
export interface MessageExtraData {
  /**
   * 用户对消息的评分（如星级），用于偏好学习。
   */
  rating: number;
  /**
   * 消息是否标记为收藏，支持筛选和快速跳转。
   */
  bookmarked: boolean;
  /**
   * 书签关联链接，记录该消息在外部系统中的对应位置。
   */
  bookmark_link: string;
  /**
   * 消息的分支列表，记录由此消息衍生出的备选叙事线标识。
   */
  branches: Array<string>;
}

/**
 * 消息事件的载荷，包含所在聊天标识和变更后的消息。
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
 * 聊天导出元数据，标识导出内容所属的聊天和角色信息。
 */
export interface ChatExportMetadata {
  /**
   * 导出所属聊天的唯一标识。
   */
  chat_id: string;
  /**
   * 导出的聊天标题（与 ChatRecord 同步）。
   */
  title: string;
  /**
   * 导出所属聊天的关联角色标识。
   */
  character_id: string;
  /**
   * 导出所属聊天的关联 persona 标识。
   */
  persona_id: string;
}

/**
 * 聊天 JSONL 导出的头部信息，包含元数据和用户名映射。
 */
export interface ChatExportHeader {
  /**
   * 聊天元数据，包含所属聊天的标识和角色信息。
   */
  chat_metadata: ChatExportMetadata;
  /**
   * 导出时使用的用户名，用于对话回放时标识用户消息。
   */
  user_name: string;
  /**
   * 导出时使用的角色名，用于对话回放时标识角色消息。
   */
  character_name: string;
}

/**
 * 消息导出时的扩展数据，与 SillyTavern 格式兼容。
 */
export interface ChatExportExtra {
  /**
   * 用户对导出消息的评分，兼容 SillyTavern 格式。
   */
  rating?: number;
  /**
   * 导出消息是否被标记为收藏。
   */
  bookmarked?: boolean;
  /**
   * 书签关联链接，兼容 SillyTavern 格式。
   */
  bookmark_link?: string;
  /**
   * 导出消息的分支列表，记录备选叙事线标识。
   */
  branches?: Array<string>;
  /**
   * 消息来源类型（如插件或系统），用于导出时标记来源上下文。
   */
  source?: string;
}

/**
 * 聊天 JSONL 导出中的单条消息，与 SillyTavern 格式兼容。
 */
export interface ChatExportMessage {
  /**
   * 名称。
   */
  name?: string;
  /**
   * 是否为用户消息标记，用于导出时区分消息角色。
   */
  is_user?: boolean;
  /**
   * 是否为系统消息标记，用于导出时区分消息角色。
   */
  is_system?: boolean;
  /**
   * 消息发送日期字符串（ISO 格式），保持与导出规范一致。
   */
  send_date?: string;
  /**
   * 消息的文本内容，兼容 SillyTavern 导出格式的 mes 字段。
   */
  mes?: string;
  /**
   * 消息的 Swipe 备选回复列表，支持用户切换查看不同回复。
   */
  swipes?: Array<string>;
  /**
   * 消息的扩展元数据，包含评分、收藏和分支信息。
   */
  extra?: ChatExportExtra;
}
