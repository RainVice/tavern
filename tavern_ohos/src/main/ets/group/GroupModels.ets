import type { GroupMemberRole } from '../contracts/PublicContracts';

/**
 * 描述调用群聊能力时需要传入的参数。
 */
export interface GroupCreateParams {
  /**
   * 群聊唯一标识。
   */
  id: string;
  /**
   * 群聊显示名称。
   */
  name: string;
  /**
   * 群聊描述信息。
   */
  description: string;
  /**
   * 关联的聊天会话标识。
   */
  chatId: string;
  /**
   * 群聊是否启用。
   */
  enabled: boolean;
  /**
   * 群聊的激活策略名称。
   */
  activationStrategy: string;
}

/**
 * 描述群聊持久化或内存索引中的一条记录。
 */
export interface GroupRecord {
  /**
   * 数据模式版本号。
   */
  schemaVersion: number;
  /**
   * 群聊唯一标识。
   */
  id: string;
  /**
   * 群聊显示名称。
   */
  name: string;
  /**
   * 群聊描述信息。
   */
  description: string;
  /**
   * 关联的聊天会话标识。
   */
  chatId: string;
  /**
   * 绑定的用户人格标识。
   */
  personaId: string;
  /**
   * 群聊是否启用。
   */
  enabled: boolean;
  /**
   * 群聊的激活策略名称。
   */
  activationStrategy: string;
  /**
   * 记录创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述调用群聊能力时需要传入的参数。
 */
export interface GroupMemberCreateParams {
  /**
   * 成员对应的角色标识。
   */
  characterId: string;
  /**
   * 成员对应的角色显示名称。
   */
  characterName: string;
  /**
   * 成员在群聊中的角色类型。
   */
  role: GroupMemberRole;
  /**
   * 成员发言活跃度，用于说话者选择。
   */
  talkativeness: number;
  /**
   * 成员是否在群聊中启用。
   */
  enabled: boolean;
  /**
   * 成员专属的世界信息文本。
   */
  worldInfoText: string;
}

/**
 * 描述群聊持久化或内存索引中的一条记录。
 */
export interface GroupMemberRecord {
  /**
   * 所属群聊的唯一标识。
   */
  groupId: string;
  /**
   * 成员对应的角色标识。
   */
  characterId: string;
  /**
   * 成员对应的角色显示名称。
   */
  characterName: string;
  /**
   * 成员在群聊中的角色类型。
   */
  role: GroupMemberRole;
  /**
   * 成员在群聊成员列表中的序号。
   */
  order: number;
  /**
   * 成员发言活跃度，用于说话者选择。
   */
  talkativeness: number;
  /**
   * 成员是否在群聊中启用。
   */
  enabled: boolean;
  /**
   * 成员专属的世界信息文本。
   */
  worldInfoText: string;
  /**
   * 记录创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述群聊持久化或内存索引中的一条记录。
 */
export interface GroupPersonaBindingRecord {
  /**
   * 群聊的唯一标识。
   */
  groupId: string;
  /**
   * 绑定的用户人格标识。
   */
  personaId: string;
  /**
   * 绑定记录更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述群聊模块在运行时交换的数据结构。
 */
export interface GroupPromptData {
  /**
   * 群聊的唯一标识。
   */
  groupId: string;
  /**
   * 群聊显示名称。
   */
  groupName: string;
  /**
   * 绑定的用户人格标识。
   */
  personaId: string;
  /**
   * 所有启用成员的角色名称列表（逗号分隔）。
   */
  memberNames: string;
  /**
   * 合并后的世界信息文本，包含共享与成员专属信息。
   */
  worldInfoText: string;
  /**
   * 最终构建的 Prompt 文本，包含群聊描述、成员和世界信息。
   */
  promptText: string;
}

/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface GroupGenerationRequest {
  /**
   * 请求唯一标识。
   */
  id: string;
  /**
   * 所属群聊标识。
   */
  groupId: string;
  /**
   * 关联的聊天会话标识。
   */
  chatId: string;
  /**
   * 关联的消息标识。
   */
  messageId: string;
  /**
   * 请求类型（如 regenerate、continue、tool_call）。
   */
  requestType: string;
  /**
   * 发言的角色标识。
   */
  speakerCharacterId: string;
  /**
   * 关联的工具名称（tool_call 类型时使用）。
   */
  toolName: string;
  /**
   * 请求创建时间戳（毫秒）。
   */
  createdAt: number;
}

/**
 * 描述群聊模块在运行时交换的数据结构。
 */
export interface GroupExportData {
  /**
   * 导出的群聊记录。
   */
  group: GroupRecord;
  /**
   * 导出的成员记录列表。
   */
  members: Array<GroupMemberRecord>;
  /**
   * 导出的生成请求记录列表。
   */
  requests: Array<GroupGenerationRequest>;
}

/**
 * 描述群聊索引文件中的持久化元数据。
 */
export interface GroupStorageIndex {
  /**
   * 数据模式版本号。
   */
  schemaVersion: number;
  /**
   * 索引中所有群聊的标识列表。
   */
  groupIds: Array<string>;
  /**
   * 生成请求自增计数器，用于生成唯一请求标识。
   */
  requestCounter: number;
}

/**
 * 描述单个群聊文件中的完整持久化快照。
 */
export interface GroupStorageSnapshot {
  /**
   * 数据模式版本号。
   */
  schemaVersion: number;
  /**
   * 群聊记录快照。
   */
  group: GroupRecord;
  /**
   * 成员记录列表快照。
   */
  members: Array<GroupMemberRecord>;
  /**
   * 生成请求记录列表快照。
   */
  requests: Array<GroupGenerationRequest>;
}

/**
 * 描述群聊事件发布时携带的数据结构。
 */
export interface GroupEventPayload {
  /**
   * 事件关联的群聊记录。
   */
  group: GroupRecord;
}

/**
 * 描述群聊事件发布时携带的数据结构。
 */
export interface GroupDeletedPayload {
  /**
   * 被删除群聊的唯一标识。
   */
  groupId: string;
}

/**
 * 描述群聊事件发布时携带的数据结构。
 */
export interface GroupMemberAddedPayload {
  /**
   * 所属群聊标识。
   */
  groupId: string;
  /**
   * 被添加成员的角色标识。
   */
  characterId: string;
  /**
   * 被添加的成员记录。
   */
  member: GroupMemberRecord;
}

/**
 * 描述群聊事件发布时携带的数据结构。
 */
export interface GroupSpeakerSelectedPayload {
  /**
   * 所属群聊标识。
   */
  groupId: string;
  /**
   * 被选中的角色标识。
   */
  characterId: string;
  /**
   * 被选中的成员记录。
   */
  member: GroupMemberRecord;
}
