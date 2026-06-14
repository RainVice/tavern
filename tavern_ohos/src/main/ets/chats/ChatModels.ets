/**
 * 描述创建聊天时需要传入的参数，用于聊天创建流程的输入验证和数据组装。
 */
export interface ChatCreateParams {
  /**
   * 聊天标题，显示在聊天列表和对话窗口顶部，用于标识和区分不同对话。
   */
  title: string;
  /**
   * 角色标识，用于将聊天与角色卡记录关联，决定对话中 AI 回复使用的角色设定。
   */
  characterId: string;
  /**
   * persona 标识，用于将聊天与用户人格设定记录关联，决定对话中用户消息的格式和风格。
   */
  personaId: string;
}

/**
 * 描述聊天记录的完整持久化数据结构，用于聊天管理全流程（创建、查询、更新、归档、删除）的数据载体。
 */
export interface ChatRecord {
  /**
   * schema 版本号，用于数据格式向下兼容和数据迁移的判断依据。
   */
  schemaVersion: number;
  /**
   * 聊天记录的唯一标识，用于索引和关联消息存储路径。
   */
  id: string;
  /**
   * 聊天标题，显示在聊天列表和对话窗口顶部，用于标识和区分不同对话。
   */
  title: string;
  /**
   * 角色标识，关联到角色卡记录，决定对话中使用的角色设定。
   */
  characterId: string;
  /**
   * persona 标识，关联到用户人格设定记录，决定对话中用户的身份和语气。
   */
  personaId: string;
  /**
   * 是否已归档，归档后的聊天在列表中默认隐藏，用于整理不再活跃的对话。
   */
  archived: boolean;
  /**
   * 下一条消息的自增编号，用于 addMessage 时生成新消息的唯一标识。
   */
  nextMessageId: number;
  /**
   * 聊天记录的创建时间戳（毫秒），用于列表排序和时间线展示。
   */
  createdAt: number;
  /**
   * 聊天记录的最后更新时间戳（毫秒），用于冲突检测和列表按最近活跃排序。
   */
  updatedAt: number;
}

/**
 * 描述聊天模块在运行时交换的索引数据结构，用于聊天列表查询和自增 ID 管理。
 */
export interface ChatIndex {
  /**
   * schema 版本号，用于索引数据格式的向下兼容和迁移判断。
   */
  schemaVersion: number;
  /**
   * 下一条聊天记录的自增编号，用于 createChat 时生成新的唯一标识。
   */
  nextId: number;
  /**
   * 聊天索引条目列表，按创建顺序排列，用于聊天列表展示。
   */
  items: Array<ChatIndexEntry>;
}

/**
 * 描述聊天索引中的摘要条目，用于聊天列表页的快速展示，包含消息数量和最后一条预览。
 */
export interface ChatIndexEntry {
  /**
   * 聊天记录的唯一标识，用于关联索引条目与完整聊天记录。
   */
  id: string;
  /**
   * 聊天标题，显示在聊天列表中的条目标题。
   */
  title: string;
  /**
   * 角色标识，用于在聊天列表中显示关联的角色名或头像。
   */
  characterId: string;
  /**
   * persona 标识，用于在聊天列表中区分不同人格设定下的对话。
   */
  personaId: string;
  /**
   * 是否已归档，归档后的聊天在列表中默认隐藏。
   */
  archived: boolean;
  /**
   * 当前聊天包含的消息数量，用于在聊天列表中显示消息计数。
   */
  messageCount: number;
  /**
   * 最后一条消息的文本预览，用于聊天列表快速展示对话摘要。
   */
  previewMessage: string;
  /**
   * 聊天记录的创建时间戳（毫秒），用于列表排序。
   */
  createdAt: number;
  /**
   * 聊天记录的最后更新时间戳（毫秒），用于列表按最近活跃排序。
   */
  updatedAt: number;
}

/**
 * 描述聊天数据变更事件（创建/更新/归档）发布时携带的数据结构，供监听者获取变更后的聊天记录用于 UI 刷新。
 */
export interface ChatEventPayload {
  /**
   * 发生变更的聊天记录副本，供事件订阅者用于 UI 更新或联动处理。
   */
  chat: ChatRecord;
}

/**
 * 描述创建消息时需要传入的参数，用于 addMessage 流程的输入验证和数据组装。
 */
export interface ChatMessageCreateParams {
  /**
   * 消息发送者显示名称（角色名或用户名），用于在对话气泡中标识发送者。
   */
  name: string;
  /**
   * 消息角色标识，取值 'user'（用户消息）、'assistant'（AI 回复）或 'system'（系统提示），用于决定消息在对话中的渲染样式和语义作用。
   */
  role: string;
  /**
   * 消息文本内容，即对话中的实际消息文本。
   */
  text: string;
}

/**
 * 描述更新消息时需要传入的参数，用于 updateMessage 流程的输入验证。
 */
export interface ChatMessageUpdateParams {
  /**
   * 更新后的消息文本内容，用于修改已有消息的文字。
   */
  text: string;
  /**
   * 是否标记为系统消息，当前也用作隐藏状态标记，控制消息在对话窗口中的可见性。
   */
  isSystem: boolean;
}

/**
 * 描述运行时中的完整消息数据结构，用于对话窗口显示和消息管理流程（增删改、排序、变体切换等）。
 */
export interface ChatMessage {
  /**
   * schema 版本号，用于消息数据格式向下兼容和迁移判断。
   */
  schemaVersion: number;
  /**
   * 消息的唯一标识，用于索引和引用特定消息进行更新或删除。
   */
  id: string;
  /**
   * 消息在聊天中的序号位置，用于决定消息在对话窗口中的渲染顺序。
   */
  index: number;
  /**
   * 消息发送者显示名称，用于在对话气泡标签中标识发送者。
   */
  name: string;
  /**
   * 消息角色标识，'user'（用户）、'assistant'（AI）或 'system'（系统），用于决定对话渲染样式和系统上下文构建。
   */
  role: string;
  /**
   * 是否为用户发送的消息，用于在对话中区分用户消息和 AI 回复的样式差异。
   */
  isUser: boolean;
  /**
   * 是否为系统消息或隐藏状态标记，控制消息在对话窗口中的可见性。
   */
  isSystem: boolean;
  /**
   * 消息发送的 ISO 8601 日期时间字符串，用于消息时间戳展示和排序。
   */
  sendDate: string;
  /**
   * 消息文本内容，即对话中的实际消息文本。
   */
  text: string;
  /**
   * 消息的可选变体列表，用于同一消息的多版本（swipe）功能，让用户可在不同 AI 回复间切换。
   */
  swipes: Array<string>;
  /**
   * 当前激活的变体索引，指向 swipes 列表中的位置，决定当前显示哪个版本的回复。
   */
  activeSwipeIndex: number;
  /**
   * 扩展数据的 JSON 字符串，包含评分、书签、分支等额外信息，用于消息的附属功能。
   */
  extraJson: string;
}

/**
 * 描述消息扩展数据（评分、书签、分支）的运行时结构，用于消息的进阶功能记录。
 */
export interface MessageExtraData {
  /**
   * 消息评分，取值范围 0-5，用于评价 AI 回复质量。
   */
  rating: number;
  /**
   * 是否标记为书签，用于标记重要消息以便快速定位。
   */
  bookmarked: boolean;
  /**
   * 书签关联链接，用于在书签消息中附加外部资源引用。
   */
  bookmark_link: string;
  /**
   * 消息分支列表，记录消息的替代路径标识，用于对话分支管理和导航。
   */
  branches: Array<string>;
}

/**
 * 描述消息变更事件发布时携带的数据结构，供监听者获取变更后的消息用于 UI 刷新。
 */
export interface MessageEventPayload {
  /**
   * 消息所属的聊天标识，供事件订阅者定位到对应的聊天上下文。
   */
  chatId: string;
  /**
   * 发生变更的消息数据，供事件订阅者用于 UI 更新或联动处理。
   */
  message: ChatMessage;
}

/**
 * 描述聊天导出时附带的元数据，用于导出的 JSONL 首行 header，标识聊天来源。
 */
export interface ChatExportMetadata {
  /**
   * 导出时记录的聊天标识，用于导入后恢复关联。
   */
  chat_id: string;
  /**
   * 导出时记录的聊天标题，用于导入后恢复显示。
   */
  title: string;
  /**
   * 导出时记录的角色标识，用于导入后重新关联角色卡。
   */
  character_id: string;
  /**
   * 导出时记录的 persona 标识，用于导入后恢复用户人格设定。
   */
  persona_id: string;
}

/**
 * 描述聊天导出文件的 header 结构（JSONL 首行），包含元数据和用户名信息。
 */
export interface ChatExportHeader {
  /**
   * 聊天导出元数据，包含标识和关联信息，用于导入恢复聊天上下文。
   */
  chat_metadata: ChatExportMetadata;
  /**
   * 导出时记录的用户名，用于兼容外部导入格式。
   */
  user_name: string;
  /**
   * 导出时记录的角色名，用于兼容外部导入格式。
   */
  character_name: string;
}

/**
 * 描述聊天导出文件中单条消息的扩展数据，用于导入时恢复消息的评分、书签、分支等信息。
 */
export interface ChatExportExtra {
  /**
   * 消息评分，导出时可选。
   */
  rating?: number;
  /**
   * 是否标记为书签，导出时可选。
   */
  bookmarked?: boolean;
  /**
   * 书签关联链接，导出时可选。
   */
  bookmark_link?: string;
  /**
   * 消息分支列表，导出时可选。
   */
  branches?: Array<string>;
  /**
   * 扩展数据的原始来源文本，当 JSON 解析失败时存储原文以避免数据丢失。
   */
  source?: string;
}

/**
 * 描述聊天导出文件中单条消息的结构，用于与 SillyTavern 等外部工具的数据交换。
 */
export interface ChatExportMessage {
  /**
   * 消息发送者显示名称。
   */
  name?: string;
  /**
   * 导出时标记是否为用户消息，用于导入后正确区分发送者。
   */
  is_user?: boolean;
  /**
   * 导出时标记是否为系统消息，用于导入后恢复隐藏/系统状态。
   */
  is_system?: boolean;
  /**
   * 消息发送的日期字符串，用于导入后恢复消息时间线。
   */
  send_date?: string;
  /**
   * 消息文本内容，用于导入后恢复对话内容。
   */
  mes?: string;
  /**
   * 消息的变体列表，用于导入后恢复多版本回复功能。
   */
  swipes?: Array<string>;
  /**
   * 消息的扩展数据（评分、书签等），用于导入后恢复消息附属信息。
   */
  extra?: ChatExportExtra;
}
