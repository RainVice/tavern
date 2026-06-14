import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  GroupCreateParams,
  GroupDeletedPayload,
  GroupEventPayload,
  GroupExportData,
  GroupGenerationRequest,
  GroupStorageIndex,
  GroupStorageSnapshot,
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
   * 文件存储适配器；未传入时仅使用内存态。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 用户标识。
   */
  private userId: string = 'default';
  /**
   * 内存中所有群聊记录的映射表。
   */
  private groups: Map<string, GroupRecord> = new Map<string, GroupRecord>();
  /**
   * 内存中每个群聊的成员记录列表映射表。
   */
  private members: Map<string, Array<GroupMemberRecord>> = new Map<string, Array<GroupMemberRecord>>();
  /**
   * 内存中每个群聊的生成请求记录列表映射表。
   */
  private requests: Map<string, Array<GroupGenerationRequest>> = new Map<string, Array<GroupGenerationRequest>>();
  /**
   * 生成请求的自增计数器，用于生成唯一请求标识。
   */
  private requestCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   * @param files 文件存储适配器。
   * @param rootPath 数据根路径。
   * @param userId 用户标识。
   */
  constructor(events: EventBus, files?: TavernFileStore, rootPath: string = 'tavern-data', userId: string = 'default') {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从 SDK 内部文件存储恢复群聊索引和群聊明细。
   */
  async loadFromStore(): Promise<void> {
    const files = this.requireFiles();
    const indexStore = new JsonStore<GroupStorageIndex>(files, this.groupIndexPath());
    const index = await indexStore.read(this.defaultStorageIndex());
    this.groups.clear();
    this.members.clear();
    this.requests.clear();
    this.requestCounter = index.requestCounter;
    for (let itemIndex = 0; itemIndex < index.groupIds.length; itemIndex += 1) {
      const groupId = index.groupIds[itemIndex];
      const path = this.groupSnapshotPath(groupId);
      if (!(await files.exists(path))) {
        continue;
      }
      const store = new JsonStore<GroupStorageSnapshot>(files, path);
      const snapshot = await store.read(this.defaultStorageSnapshot(groupId));
      this.groups.set(snapshot.group.id, this.cloneGroup(snapshot.group));
      this.members.set(snapshot.group.id, this.cloneMembers(snapshot.members));
      this.requests.set(snapshot.group.id, this.cloneRequests(snapshot.requests));
      this.requestCounter = Math.max(this.requestCounter, this.maxRequestCounter(snapshot.requests));
    }
  }

  /**
   * 把当前群聊、成员、Persona 绑定和生成请求写入 SDK 内部文件存储。
   */
  async saveToStore(): Promise<void> {
    const files = this.requireFiles();
    const previousIndex = await new JsonStore<GroupStorageIndex>(files, this.groupIndexPath()).read(this.defaultStorageIndex());
    const groupIds = Array.from(this.groups.keys()).sort();
    for (let index = 0; index < groupIds.length; index += 1) {
      const groupId = groupIds[index];
      const snapshot = this.buildStorageSnapshot(groupId);
      const store = new JsonStore<GroupStorageSnapshot>(files, this.groupSnapshotPath(groupId));
      await store.write(snapshot);
    }
    await this.deleteRemovedGroupSnapshots(files, previousIndex.groupIds, groupIds);
    const requestCounter = this.requestCounter;
    const storageIndex: GroupStorageIndex = {
      schemaVersion: 1,
      groupIds: groupIds,
      requestCounter: requestCounter,
    };
    await new JsonStore<GroupStorageIndex>(files, this.groupIndexPath()).write(storageIndex);
  }

  /**
   * 创建新的群聊记录，写入存储并返回副本。
   * @param params 创建群聊所需的参数。
   * @returns 新创建的群聊记录副本。
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
   * @param params 更新群聊所需的参数。
   * @returns 更新后的群聊记录副本。
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
   * 删除指定群聊，并清理相关成员和请求数据，发布删除事件。
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
   * 获取指定群聊的记录副本。
   * @param groupId 目标群聊标识。
   * @returns 群聊记录副本；调用方可安全读取，修改不影响内部状态。
   */
  getGroup(groupId: string): GroupRecord {
    return this.cloneGroup(this.requireGroup(groupId));
  }

  /**
   * 获取所有群聊记录的列表副本。
   * @returns 群聊记录列表副本；调用方可安全读取，修改不影响内部状态。
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
   * 向指定群聊添加成员。
   * @param groupId 目标群聊标识。
   * @param params 成员创建参数。
   * @returns 新创建的成员记录副本；调用方可安全读取，修改不影响内部状态。
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
    const payloadMember = this.cloneMember(member);
    const payload: GroupMemberAddedPayload = {
      groupId: groupId,
      characterId: member.characterId,
      member: payloadMember,
    };
    this.events.publish<GroupMemberAddedPayload>('group.member.added', payload);
    return this.cloneMember(member);
  }

  /**
   * 从指定群聊移除成员。
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
   * 重新排序指定群聊的成员列表。
   * @param groupId 目标群聊标识。
   * @param characterIds 按新顺序排列的角色标识列表，必须包含所有成员。
   * @returns 重排序后的成员记录列表副本；调用方可安全读取。
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
   * 获取指定群聊的成员列表副本。
   * @param groupId 目标群聊标识。
   * @returns 成员记录列表副本；调用方可安全读取，修改不影响内部状态。
   */
  listMembers(groupId: string): Array<GroupMemberRecord> {
    return this.cloneMembers(this.requireMembers(groupId));
  }

  /**
   * 将指定用户人格绑定到群聊。
   * @param groupId 目标群聊标识。
   * @param personaId 用户人格标识。
   * @returns 新的绑定记录副本；调用方可安全读取。
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
   * 从指定群聊中选择发言者。
   * 若指定角色标识则选择该角色，否则从已启用成员中选出活跃度最高的角色。
   * @param groupId 目标群聊标识。
   * @param characterId 指定角色标识；传入空字符串则自动选择。
   * @returns 被选中的成员记录副本。
   */
  selectSpeaker(groupId: string, characterId: string): GroupMemberRecord {
    const members = this.requireMembers(groupId);
    let selected: GroupMemberRecord;
    if (characterId.length > 0) {
      selected = this.findMember(members, characterId);
    } else {
      selected = this.selectMostTalkative(members);
    }
    const payloadMember = this.cloneMember(selected);
    const payload: GroupSpeakerSelectedPayload = {
      groupId: groupId,
      characterId: selected.characterId,
      member: payloadMember,
    };
    this.events.publish<GroupSpeakerSelectedPayload>('group.speaker.selected', payload);
    return this.cloneMember(selected);
  }

  /**
   * 根据群聊信息和世界信息构建 Prompt 数据。
   * @param groupId 目标群聊标识。
   * @param sharedWorldInfoText 共享的世界信息文本。
   * @returns 构建好的 Prompt 数据，包含群聊描述、成员和世界信息。
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
   * 将指定聊天消息排队等待重新生成。
   * @param groupId 目标群聊标识。
   * @param chatId 目标聊天标识。
   * @param messageId 目标消息标识。
   * @returns 新建的生成请求记录。
   */
  queueRegenerate(groupId: string, chatId: string, messageId: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, messageId, 'regenerate', '', '');
  }

  /**
   * 将指定聊天排队等待继续生成。
   * @param groupId 目标群聊标识。
   * @param chatId 目标聊天标识。
   * @returns 新建的生成请求记录。
   */
  queueContinue(groupId: string, chatId: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, '', 'continue', '', '');
  }

  /**
   * 将指定工具调用排队等待执行。
   * @param groupId 目标群聊标识。
   * @param chatId 目标聊天标识。
   * @param toolName 工具名称。
   * @returns 新建的生成请求记录。
   */
  queueToolCall(groupId: string, chatId: string, toolName: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, '', 'tool_call', '', toolName);
  }

  /**
   * 获取指定群聊的生成请求列表副本。
   * @param groupId 目标群聊标识。
   * @returns 生成请求记录列表副本；调用方可安全读取，修改不影响内部状态。
   */
  listGenerationRequests(groupId: string): Array<GroupGenerationRequest> {
    return this.cloneRequests(this.requireRequests(groupId));
  }

  /**
   * 导出群聊完整数据，包含群聊记录、成员列表和生成请求列表。
   * 可用于备份、迁移或与外部工具数据互通。
   * @param groupId 目标群聊标识。
   * @returns 包含群聊、成员和请求的导出数据。
   */
  exportGroup(groupId: string): GroupExportData {
    const group = this.cloneGroup(this.requireGroup(groupId));
    const members = this.cloneMembers(this.requireMembers(groupId));
    const requests = this.cloneRequests(this.requireRequests(groupId));
    const data: GroupExportData = {
      group: group,
      members: members,
      requests: requests,
    };
    return data;
  }

  /**
   * 从外部导入的群聊数据创建新群聊。
   * 会为数据分配新的群聊标识，保留成员和请求记录。
   * @param data 要导入的群聊数据。
   * @param newGroupId 新群聊的唯一标识。
   * @returns 导入后创建的群聊记录副本。
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
   * @returns 群聊成员记录列表副本
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
   * @returns 群聊成员记录列表副本
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
   * @returns 群聊成员记录列表副本
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

   * @returns 群聊成员记录列表副本
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

   * @returns 群聊成员记录列表副本
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

   * @returns 群聊成员记录列表副本
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

  private requireFiles(): TavernFileStore {
    if (this.files === undefined) {
      throw new Error('GroupRuntime storage is not configured.');
    }
    return this.files;
  }

  private groupDirectoryPath(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/groups`;
  }

  private groupIndexPath(): string {
    return `${this.groupDirectoryPath()}/index.json`;
  }

  private groupSnapshotPath(groupId: string): string {
    return `${this.groupDirectoryPath()}/${safePathSegment(groupId, 'group')}.json`;
  }

  private defaultStorageIndex(): GroupStorageIndex {
    return {
      schemaVersion: 1,
      groupIds: new Array<string>(),
      requestCounter: 0,
    };
  }

  private defaultStorageSnapshot(groupId: string): GroupStorageSnapshot {
    const now = Date.now();
    const group: GroupRecord = {
      schemaVersion: 1,
      id: groupId,
      name: '',
      description: '',
      chatId: '',
      personaId: '',
      enabled: false,
      activationStrategy: '',
      createdAt: now,
      updatedAt: now,
    };
    return {
      schemaVersion: 1,
      group: group,
      members: new Array<GroupMemberRecord>(),
      requests: new Array<GroupGenerationRequest>(),
    };
  }

  private buildStorageSnapshot(groupId: string): GroupStorageSnapshot {
    const group = this.cloneGroup(this.requireGroup(groupId));
    const members = this.cloneMembers(this.requireMembers(groupId));
    const requests = this.cloneRequests(this.requireRequests(groupId));
    const snapshot: GroupStorageSnapshot = {
      schemaVersion: 1,
      group: group,
      members: members,
      requests: requests,
    };
    return snapshot;
  }

  private async deleteRemovedGroupSnapshots(
    files: TavernFileStore,
    previousGroupIds: Array<string>,
    currentGroupIds: Array<string>,
  ): Promise<void> {
    const current = new Set<string>();
    for (let index = 0; index < currentGroupIds.length; index += 1) {
      current.add(currentGroupIds[index]);
    }
    for (let index = 0; index < previousGroupIds.length; index += 1) {
      const groupId = previousGroupIds[index];
      if (!current.has(groupId)) {
        await files.delete(this.groupSnapshotPath(groupId));
      }
    }
  }

  private maxRequestCounter(requests: Array<GroupGenerationRequest>): number {
    let max = 0;
    for (let index = 0; index < requests.length; index += 1) {
      max = Math.max(max, this.parseRequestCounter(requests[index].id));
    }
    return max;
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
    const payloadGroup = this.cloneGroup(group);
    const payload: GroupEventPayload = {
      group: payloadGroup,
    };
    this.events.publish<GroupEventPayload>(eventName, payload);
  }
}
