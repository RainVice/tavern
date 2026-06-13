import { EventBus } from '../runtime/EventBus';
import type {
  GroupCreateParams,
  GroupDeletedPayload,
  GroupEventPayload,
  GroupExportData,
  GroupGenerationRequest,
  GroupMemberAddedPayload,
  GroupMemberCreateParams,
  GroupMemberRecord,
  GroupPersonaBindingRecord,
  GroupPromptData,
  GroupRecord,
  GroupSpeakerSelectedPayload,
} from './GroupModels';

/**
 * 提供群聊相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class GroupRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * groups 列表，由当前实例内部维护。
   */
  private groups: Map<string, GroupRecord> = new Map<string, GroupRecord>();
  /**
   * members 列表，由当前实例内部维护。
   */
  private members: Map<string, Array<GroupMemberRecord>> = new Map<string, Array<GroupMemberRecord>>();
  /**
   * requests 列表，由当前实例内部维护。
   */
  private requests: Map<string, Array<GroupGenerationRequest>> = new Map<string, Array<GroupGenerationRequest>>();
  /**
   * request Counter 值，由当前实例内部维护。
   */
  private requestCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的群聊记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  createGroup(params: GroupCreateParams): GroupRecord {
    if (this.groups.has(params.id)) {
      throw new Error(`Group already exists: ${params.id}`);
    }
    const now = Date.now();
    const group: GroupRecord = {
      schemaVersion: 1,
      id: params.id,
      name: params.name,
      description: params.description,
      chatId: params.chatId,
      personaId: '',
      enabled: params.enabled,
      activationStrategy: params.activationStrategy,
      createdAt: now,
      updatedAt: now,
    };
    this.groups.set(group.id, this.cloneGroup(group));
    this.members.set(group.id, new Array<GroupMemberRecord>());
    this.requests.set(group.id, new Array<GroupGenerationRequest>());
    this.publishGroupEvent('group.created', group);
    return this.cloneGroup(group);
  }

  /**
   * 更新指定群聊，写回存储并按需发布变更事件。
   * @param groupId 目标群聊标识。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  updateGroup(groupId: string, params: GroupCreateParams): GroupRecord {
    const group = this.requireGroup(groupId);
    group.name = params.name;
    group.description = params.description;
    group.chatId = params.chatId;
    group.enabled = params.enabled;
    group.activationStrategy = params.activationStrategy;
    group.updatedAt = Date.now();
    this.publishGroupEvent('group.updated', group);
    return this.cloneGroup(group);
  }

  /**
   * 删除指定群聊，并清理相关索引或资源引用。
   * @param groupId 目标群聊标识。
   */
  deleteGroup(groupId: string): void {
    this.requireGroup(groupId);
    this.groups.delete(groupId);
    this.members.delete(groupId);
    this.requests.delete(groupId);
    const payload: GroupDeletedPayload = {
      groupId: groupId,
    };
    this.events.publish<GroupDeletedPayload>('group.deleted', payload);
  }

  /**
   * 读取指定群聊，不存在时抛出错误。
   * @param groupId 目标群聊标识。
   * @returns 更新或读取后的记录副本。
   */
  getGroup(groupId: string): GroupRecord {
    return this.cloneGroup(this.requireGroup(groupId));
  }

  /**
   * 读取Groups列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listGroups(): Array<GroupRecord> {
    const result = new Array<GroupRecord>();
    const values = Array.from(this.groups.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.cloneGroup(values[index]));
    }
    return result;
  }

  /**
   * 创建或写入Member，完成持久化后返回可供调用方使用的结果。
   * @param groupId 目标群聊标识。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  addMember(groupId: string, params: GroupMemberCreateParams): GroupMemberRecord {
    this.requireGroup(groupId);
    const members = this.requireMembers(groupId);
    const now = Date.now();
    const member: GroupMemberRecord = {
      groupId: groupId,
      characterId: params.characterId,
      characterName: params.characterName,
      role: params.role,
      order: members.length,
      talkativeness: params.talkativeness,
      enabled: params.enabled,
      worldInfoText: params.worldInfoText,
      createdAt: now,
      updatedAt: now,
    };
    members.push(member);
    const payload: GroupMemberAddedPayload = {
      groupId: groupId,
      characterId: member.characterId,
      member: this.cloneMember(member),
    };
    this.events.publish<GroupMemberAddedPayload>('group.member.added', payload);
    return this.cloneMember(member);
  }

  /**
   * 移除成员，用于解除注册、绑定或索引关系。
   * @param groupId 目标群聊标识。
   * @param characterId 目标角色标识。
   */
  removeMember(groupId: string, characterId: string): void {
    const members = this.requireMembers(groupId);
    for (let index = 0; index < members.length; index += 1) {
      if (members[index].characterId === characterId) {
        members.splice(index, 1);
        this.reindexMembers(members);
        return;
      }
    }
    throw new Error(`Group member not found: ${characterId}`);
  }

  /**
   * 更新Members状态，必要时写回存储并发布对应事件。
   * @param groupId 目标群聊标识。
   * @param characterIds 目标角色标识列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  reorderMembers(groupId: string, characterIds: Array<string>): Array<GroupMemberRecord> {
    const members = this.requireMembers(groupId);
    if (characterIds.length !== members.length) {
      throw new Error(`Group member reorder must include every member: ${groupId}`);
    }
    const seen: Map<string, boolean> = new Map<string, boolean>();
    const reordered = new Array<GroupMemberRecord>();
    for (let order = 0; order < characterIds.length; order += 1) {
      if (seen.get(characterIds[order]) === true) {
        throw new Error(`Duplicate group member in reorder: ${characterIds[order]}`);
      }
      seen.set(characterIds[order], true);
      const member = this.findMember(members, characterIds[order]);
      member.order = order;
      member.updatedAt = Date.now();
      reordered.push(member);
    }
    this.members.set(groupId, reordered);
    return this.cloneMembers(reordered);
  }

  /**
   * 读取Members列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param groupId 目标群聊标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listMembers(groupId: string): Array<GroupMemberRecord> {
    return this.cloneMembers(this.requireMembers(groupId));
  }

  /**
   * 把群聊对象绑定到指定作用域，后续读取会按该绑定解析。
   * @param groupId 目标群聊标识。
   * @param personaId 目标用户人格标识。
   */
  bindPersona(groupId: string, personaId: string): GroupPersonaBindingRecord {
    const group = this.requireGroup(groupId);
    group.personaId = personaId;
    group.updatedAt = Date.now();
    const binding: GroupPersonaBindingRecord = {
      groupId: groupId,
      personaId: personaId,
      updatedAt: group.updatedAt,
    };
    this.publishGroupEvent('group.persona.bound', group);
    return this.cloneBinding(binding);
  }

  /**
   * 读取或解析Speaker，调用方应处理不存在或不匹配的情况。
   * @param groupId 目标群聊标识。
   * @param characterId 目标角色标识。
   */
  selectSpeaker(groupId: string, characterId: string): GroupMemberRecord {
    const members = this.requireMembers(groupId);
    let selected: GroupMemberRecord;
    if (characterId.length > 0) {
      selected = this.findMember(members, characterId);
    } else {
      selected = this.selectMostTalkative(members);
    }
    const payload: GroupSpeakerSelectedPayload = {
      groupId: groupId,
      characterId: selected.characterId,
      member: this.cloneMember(selected),
    };
    this.events.publish<GroupSpeakerSelectedPayload>('group.speaker.selected', payload);
    return this.cloneMember(selected);
  }

  /**
   * 根据入参构建Prompt Data 值，仅生成数据结构，不直接执行外部请求。
   * @param groupId 目标群聊标识。

   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildPromptData(groupId: string, sharedWorldInfoText: string): GroupPromptData {
    const group = this.requireGroup(groupId);
    const members = this.requireMembers(groupId);
    const memberNames = this.joinMemberNames(members);
    const worldInfoText = this.mergeWorldInfo(sharedWorldInfoText, members);
    const promptText = `Group: ${group.name}\nMembers: ${memberNames}\nPersona: ${group.personaId}\nWorldInfo:\n${worldInfoText}`;
    const data: GroupPromptData = {
      groupId: groupId,
      groupName: group.name,
      personaId: group.personaId,
      memberNames: memberNames,
      worldInfoText: worldInfoText,
      promptText: promptText,
    };
    return data;
  }

  /**
   * 执行 queueRegenerate 的内部处理步骤，供当前模块复用。
   * @param groupId 目标群聊标识。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   */
  queueRegenerate(groupId: string, chatId: string, messageId: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, messageId, 'regenerate', '', '');
  }

  /**
   * 执行 queueContinue 的内部处理步骤，供当前模块复用。
   * @param groupId 目标群聊标识。
   * @param chatId 目标聊天标识。
   */
  queueContinue(groupId: string, chatId: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, '', 'continue', '', '');
  }

  /**
   * 执行 queueToolCall 的内部处理步骤，供当前模块复用。
   * @param groupId 目标群聊标识。
   * @param chatId 目标聊天标识。
   * @param toolName tool名称。
   */
  queueToolCall(groupId: string, chatId: string, toolName: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, '', 'tool_call', '', toolName);
  }

  /**
   * 读取GenerationRequests列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param groupId 目标群聊标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listGenerationRequests(groupId: string): Array<GroupGenerationRequest> {
    return this.cloneRequests(this.requireRequests(groupId));
  }

  /**
   * 导出群聊，用于备份、迁移或与 SillyTavern 数据互通。
   * @param groupId 目标群聊标识。
   * @returns 可持久化或可传输的导出内容。
   */
  exportGroup(groupId: string): GroupExportData {
    const data: GroupExportData = {
      group: this.cloneGroup(this.requireGroup(groupId)),
      members: this.cloneMembers(this.requireMembers(groupId)),
      requests: this.cloneRequests(this.requireRequests(groupId)),
    };
    return data;
  }

  /**
   * 从外部数据导入Group 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   * @param newGroupId 目标新记录群聊标识。
   * @returns 更新或读取后的记录副本。
   */
  importGroup(data: GroupExportData, newGroupId: string): GroupRecord {
    if (this.groups.has(newGroupId)) {
      throw new Error(`Group already exists: ${newGroupId}`);
    }
    const group = this.cloneGroup(data.group);
    group.id = newGroupId;
    group.updatedAt = Date.now();
    this.groups.set(newGroupId, this.cloneGroup(group));
    const importedMembers = this.cloneMembers(data.members);
    for (let index = 0; index < importedMembers.length; index += 1) {
      importedMembers[index].groupId = newGroupId;
    }
    this.members.set(newGroupId, importedMembers);
    const importedRequests = this.cloneRequests(data.requests);
    for (let index = 0; index < importedRequests.length; index += 1) {
      importedRequests[index].groupId = newGroupId;
      this.requestCounter = Math.max(this.requestCounter, this.parseRequestCounter(importedRequests[index].id));
    }
    this.requests.set(newGroupId, importedRequests);
    this.publishGroupEvent('group.imported', group);
    return this.cloneGroup(group);
  }
  private queueRequest(
    groupId: string,
    chatId: string,
    messageId: string,
    requestType: string,
    speakerCharacterId: string,
    toolName: string,
  ): GroupGenerationRequest {
    this.requireGroup(groupId);
    const requests = this.requireRequests(groupId);
    this.requestCounter += 1;
    const request: GroupGenerationRequest = {
      id: `group-request-${this.requestCounter}`,
      groupId: groupId,
      chatId: chatId,
      messageId: messageId,
      requestType: requestType,
      speakerCharacterId: speakerCharacterId,
      toolName: toolName,
      createdAt: Date.now(),
    };
    requests.push(request);
    return this.cloneRequest(request);
  }

  /**
   * 读取必须存在的Group 值，缺失时抛出错误。
   * @param groupId 目标群聊标识。
   */
  private requireGroup(groupId: string): GroupRecord {
    const group = this.groups.get(groupId);
    if (group === undefined) {
      throw new Error(`Group not found: ${groupId}`);
    }
    return group;
  }

  /**
   * 读取必须存在的Members 列表，缺失时抛出错误。
   * @param groupId 目标群聊标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private requireMembers(groupId: string): Array<GroupMemberRecord> {
    const members = this.members.get(groupId);
    if (members === undefined) {
      throw new Error(`Group members not found: ${groupId}`);
    }
    return members;
  }

  /**
   * 读取必须存在的Requests 列表，缺失时抛出错误。
   * @param groupId 目标群聊标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private requireRequests(groupId: string): Array<GroupGenerationRequest> {
    const requests = this.requests.get(groupId);
    if (requests === undefined) {
      throw new Error(`Group requests not found: ${groupId}`);
    }
    return requests;
  }

  /**
   * 在当前集合中查找Member 值，未命中时返回空值或默认位置。

   * @param characterId 目标角色标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private findMember(members: Array<GroupMemberRecord>, characterId: string): GroupMemberRecord {
    for (let index = 0; index < members.length; index += 1) {
      if (members[index].characterId === characterId) {
        return members[index];
      }
    }
    throw new Error(`Group member not found: ${characterId}`);
  }

  /**
   * 读取或解析MostTalkative，调用方应处理不存在或不匹配的情况。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private selectMostTalkative(members: Array<GroupMemberRecord>): GroupMemberRecord {
    if (members.length === 0) {
      throw new Error('Group has no members.');
    }
    let selected: GroupMemberRecord | undefined = undefined;
    for (let index = 0; index < members.length; index += 1) {
      if (members[index].enabled && (selected === undefined || members[index].talkativeness > selected.talkativeness)) {
        selected = members[index];
      }
    }
    if (selected !== undefined) {
      return selected;
    }
    return members[0];
  }
  private reindexMembers(members: Array<GroupMemberRecord>): void {
    const now = Date.now();
    for (let index = 0; index < members.length; index += 1) {
      members[index].order = index;
      members[index].updatedAt = now;
    }
  }
  private joinMemberNames(members: Array<GroupMemberRecord>): string {
    const names = new Array<string>();
    for (let index = 0; index < members.length; index += 1) {
      names.push(members[index].characterName);
    }
    return names.join(', ');
  }
  private mergeWorldInfo(sharedWorldInfoText: string, members: Array<GroupMemberRecord>): string {
    const parts = new Array<string>();
    if (sharedWorldInfoText.length > 0) {
      parts.push(sharedWorldInfoText);
    }
    for (let index = 0; index < members.length; index += 1) {
      if (members[index].worldInfoText.length > 0) {
        parts.push(members[index].worldInfoText);
      }
    }
    return parts.join('\n');
  }

  /**
   * 复制Group 值，避免外部修改内部状态。
   */
  private cloneGroup(group: GroupRecord): GroupRecord {
    const cloned: GroupRecord = {
      schemaVersion: group.schemaVersion,
      id: group.id,
      name: group.name,
      description: group.description,
      chatId: group.chatId,
      personaId: group.personaId,
      enabled: group.enabled,
      activationStrategy: group.activationStrategy,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    };
    return cloned;
  }

  /**
   * 复制Members 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneMembers(members: Array<GroupMemberRecord>): Array<GroupMemberRecord> {
    const cloned = new Array<GroupMemberRecord>();
    for (let index = 0; index < members.length; index += 1) {
      cloned.push(this.cloneMember(members[index]));
    }
    return cloned;
  }

  /**
   * 复制Member 值，避免外部修改内部状态。
   */
  private cloneMember(member: GroupMemberRecord): GroupMemberRecord {
    return {
      groupId: member.groupId,
      characterId: member.characterId,
      characterName: member.characterName,
      role: member.role,
      order: member.order,
      talkativeness: member.talkativeness,
      enabled: member.enabled,
      worldInfoText: member.worldInfoText,
      createdAt: member.createdAt,
      updatedAt: member.updatedAt,
    };
  }

  /**
   * 复制Requests 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneRequests(requests: Array<GroupGenerationRequest>): Array<GroupGenerationRequest> {
    const cloned = new Array<GroupGenerationRequest>();
    for (let index = 0; index < requests.length; index += 1) {
      cloned.push(this.cloneRequest(requests[index]));
    }
    return cloned;
  }

  /**
   * 复制Request 值，避免外部修改内部状态。
   * @param request 待处理的请求对象。
   */
  private cloneRequest(request: GroupGenerationRequest): GroupGenerationRequest {
    return {
      id: request.id,
      groupId: request.groupId,
      chatId: request.chatId,
      messageId: request.messageId,
      requestType: request.requestType,
      speakerCharacterId: request.speakerCharacterId,
      toolName: request.toolName,
      createdAt: request.createdAt,
    };
  }

  /**
   * 解析RequestCounter，非法输入会返回失败标记或空结果。
   * @param requestId 目标请求标识。
   */
  private parseRequestCounter(requestId: string): number {
    const prefix = 'group-request-';
    if (!requestId.startsWith(prefix)) {
      return 0;
    }
    const value = Number.parseInt(requestId.substring(prefix.length), 10);
    if (Number.isNaN(value)) {
      return 0;
    }
    return value;
  }

  /**
   * 复制Binding 值，避免外部修改内部状态。
   */
  private cloneBinding(binding: GroupPersonaBindingRecord): GroupPersonaBindingRecord {
    return {
      groupId: binding.groupId,
      personaId: binding.personaId,
      updatedAt: binding.updatedAt,
    };
  }

  /**
   * 发布群聊事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。

   */
  private publishGroupEvent(eventName: string, group: GroupRecord): void {
    const payload: GroupEventPayload = {
      group: this.cloneGroup(group),
    };
    this.events.publish<GroupEventPayload>(eventName, payload);
  }
}
