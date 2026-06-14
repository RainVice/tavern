import type { GroupMemberRole } from '../contracts/PublicContracts';

/**
 * 描述调用群聊能力时需要传入的参数。
 */
export interface GroupCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * activation Strategy 值，由当前实例内部维护。
   */
  activationStrategy: string;
}

/**
 * 描述群聊持久化或内存索引中的一条记录。
 */
export interface GroupRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * persona 标识。
   */
  personaId: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * activation Strategy 值，由当前实例内部维护。
   */
  activationStrategy: string;
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
 * 描述调用群聊能力时需要传入的参数。
 */
export interface GroupMemberCreateParams {
  /**
   * 角色标识。
   */
  characterId: string;
  /**
   * character 名称。
   */
  characterName: string;
  /**
   * role 值，由当前实例内部维护。
   */
  role: GroupMemberRole;
  /**
   * talkativeness 列表，由当前实例内部维护。
   */
  talkativeness: number;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * world Info Text 值，由当前实例内部维护。
   */
  worldInfoText: string;
}

/**
 * 描述群聊持久化或内存索引中的一条记录。
 */
export interface GroupMemberRecord {
  /**
   * group 标识。
   */
  groupId: string;
  /**
   * 角色标识。
   */
  characterId: string;
  /**
   * character 名称。
   */
  characterName: string;
  /**
   * role 值，由当前实例内部维护。
   */
  role: GroupMemberRole;
  /**
   * order 值，由当前实例内部维护。
   */
  order: number;
  /**
   * talkativeness 列表，由当前实例内部维护。
   */
  talkativeness: number;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * world Info Text 值，由当前实例内部维护。
   */
  worldInfoText: string;
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
 * 描述群聊持久化或内存索引中的一条记录。
 */
export interface GroupPersonaBindingRecord {
  /**
   * group 标识。
   */
  groupId: string;
  /**
   * persona 标识。
   */
  personaId: string;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述群聊模块在运行时交换的数据结构。
 */
export interface GroupPromptData {
  /**
   * group 标识。
   */
  groupId: string;
  /**
   * group 名称。
   */
  groupName: string;
  /**
   * persona 标识。
   */
  personaId: string;
  /**
   * member Names 列表，由当前实例内部维护。
   */
  memberNames: string;
  /**
   * world Info Text 值，由当前实例内部维护。
   */
  worldInfoText: string;
  /**
   * prompt Text 值，由当前实例内部维护。
   */
  promptText: string;
}

/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface GroupGenerationRequest {
  /**
   * 标识。
   */
  id: string;
  /**
   * group 标识。
   */
  groupId: string;
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * 消息标识。
   */
  messageId: string;
  /**
   * request Type 值，由当前实例内部维护。
   */
  requestType: string;
  /**
   * speaker Character 标识。
   */
  speakerCharacterId: string;
  /**
   * tool 名称。
   */
  toolName: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
}

/**
 * 描述群聊模块在运行时交换的数据结构。
 */
export interface GroupExportData {
  /**
   * group 值，由当前实例内部维护。
   */
  group: GroupRecord;
  /**
   * members 列表，由当前实例内部维护。
   */
  members: Array<GroupMemberRecord>;
  /**
   * requests 列表，由当前实例内部维护。
   */
  requests: Array<GroupGenerationRequest>;
}

/**
 * 描述群聊索引文件中的持久化元数据。
 */
export interface GroupStorageIndex {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * group 标识列表。
   */
  groupIds: Array<string>;
  /**
   * 下一次生成请求编号之前已经使用过的最大编号。
   */
  requestCounter: number;
}

/**
 * 描述单个群聊文件中的完整持久化快照。
 */
export interface GroupStorageSnapshot {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * group 值，由当前实例内部维护。
   */
  group: GroupRecord;
  /**
   * members 列表，由当前实例内部维护。
   */
  members: Array<GroupMemberRecord>;
  /**
   * requests 列表，由当前实例内部维护。
   */
  requests: Array<GroupGenerationRequest>;
}

/**
 * 描述群聊事件发布时携带的数据结构。
 */
export interface GroupEventPayload {
  /**
   * group 值，由当前实例内部维护。
   */
  group: GroupRecord;
}

/**
 * 描述群聊事件发布时携带的数据结构。
 */
export interface GroupDeletedPayload {
  /**
   * group 标识。
   */
  groupId: string;
}

/**
 * 描述群聊事件发布时携带的数据结构。
 */
export interface GroupMemberAddedPayload {
  /**
   * group 标识。
   */
  groupId: string;
  /**
   * 角色标识。
   */
  characterId: string;
  /**
   * member 值，由当前实例内部维护。
   */
  member: GroupMemberRecord;
}

/**
 * 描述群聊事件发布时携带的数据结构。
 */
export interface GroupSpeakerSelectedPayload {
  /**
   * group 标识。
   */
  groupId: string;
  /**
   * 角色标识。
   */
  characterId: string;
  /**
   * member 值，由当前实例内部维护。
   */
  member: GroupMemberRecord;
}
