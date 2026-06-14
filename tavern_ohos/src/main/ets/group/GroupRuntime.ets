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
 * 群聊功能允许多个角色在同一个聊天会话中参与 AI 对话，
 * 支持成员管理、发言者选择、生成请求队列和持久化存储。
 */
export class GroupRuntime {
  /**
   * 事件总线，用于在群聊创建/更新/删除/成员添加/发言者选择等操作时，
   * 向 UI 层和其他模块广播事件。
   */
  private events: EventBus;
  /**
   * 文件存储适配器；未配置时仅使用内存状态，不进行持久化。
   * 用于在 saveToStore/loadFromStore 流程中读写群聊快照文件。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 数据存储的根路径，用于构建持久化文件路径，
   * 默认值为 'tavern-data'。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 当前用户标识，用于构建用户级存储路径，
   * 默认值为 'default'。
   */
  private userId: string = 'default';
  /**
   * 群聊记录的内存索引，键为群聊 ID（GroupRecord.id），
   * 用于在运行时快速查找群聊元数据。
   */
  private groups: Map<string, GroupRecord> = new Map<string, GroupRecord>();
  /**
   * 群聊成员的内存索引，键为群聊 ID，值为该群聊的成员数组，
   * 用于管理各群聊的角色组成和发言配置。
   */
  private members: Map<string, Array<GroupMemberRecord>> = new Map<string, Array<GroupMemberRecord>>();
  /**
   * 群聊生成请求的内存索引，键为群聊 ID，值为该群聊的请求数组，
   * 用于排队管理 regenerate/continue/tool_call 等生成请求。
   */
  private requests: Map<string, Array<GroupGenerationRequest>> = new Map<string, Array<GroupGenerationRequest>>();
  /**
   * 生成请求的自增计数器，确保请求 ID 全局唯一，
   * 格式为 'group-request-{计数器值}'。
   */
  private requestCounter: number = 0;

  /**
   * 初始化群聊运行时实例。
   * @param events 事件总线实例，用于在群聊变更时发布事件（如 group.created、group.deleted 等）。
   * @param files 可选的文件存储适配器，传入后可启用持久化功能（saveToStore / loadFromStore）。
   * @param rootPath 数据存储的根路径，用于在 groupDirectoryPath 中构建存储子目录。
   * @param userId 当前用户标识，用于在持久化路径中区分不同用户的数据。
   */
  constructor(events: EventBus, files?: TavernFileStore, rootPath: string = 'tavern-data', userId: string = 'default') {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从持久化存储中加载群聊索引及各群聊的详细数据，恢复运行时状态。
   * 在应用启动或切换用户时由宿主调用，读取 index.json 和各群聊快照文件恢复到内存。
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
   * 将当前运行时中的群聊、成员和请求持久化到文件存储，并清理已删除的群聊快照。
   * 在群聊数据发生变更后由宿主或自动保存流程调用，确保数据持久化。
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
   * 创建新群聊，写入内存索引并发布创建事件。
   * 在用户新建群聊时由宿主或 UI 层调用。
   * @param params 群聊创建参数，包含 ID、名称、描述、聊天关联及激活策略等。
   * @returns 新创建的群聊记录副本。
   * @throws 当指定 ID 已存在时抛出错误。
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
   * 更新指定群聊的名称、描述、关联聊天等属性，并发布更新事件。
   * 在用户编辑群聊配置时由宿主或 UI 层调用。
   * @param groupId 要更新的群聊标识，用于在 groups 索引中查找对应记录。
   * @param params 包含新属性的群聊参数对象，会更新 group 的 name、description、chatId、enabled、activationStrategy 字段。
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
   * 删除指定群聊及其所有关联的成员和请求记录，并发布删除事件。
   * 在用户删除群聊时由宿主调用。
   * @param groupId 要删除的群聊标识，用于在 groups 索引中查找记录并清理成员和请求索引。
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
   * 根据群聊 ID 获取群聊记录副本，不存在时抛出错误。
   * 在需要查询群聊详情时由宿主调用。
   * @param groupId 要获取的群聊标识。
   * @returns 群聊记录副本。
   */
  getGroup(groupId: string): GroupRecord {
    return this.cloneGroup(this.requireGroup(groupId));
  }

  /**
   * 返回所有群聊记录的副本列表。
   * 在 UI 群聊列表展示时由宿主调用。
   * @returns 群聊记录列表，每个条目均为副本，修改返回值不影响内部状态。
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
   * 向指定群聊中添加一名成员，并发布成员添加事件。
   * 在用户将角色加入群聊时由宿主或 UI 层调用。
   * @param groupId 目标群聊标识，用于在 members 索引中查找并追加成员。
   * @param params 成员创建参数，包含角色 ID、角色名、群聊角色、活跃度等。
   * @returns 新创建的群聊成员记录副本。
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
   * 从群聊中移除指定角色成员，并重新调整剩余成员的排序。
   * 在用户从群聊中移除角色时由宿主或 UI 层调用。
   * @param groupId 目标群聊标识，用于在 members 索引中查找成员列表。
   * @param characterId 要移除的角色标识，用于在成员列表中查找和删除对应成员。
   * @throws 当指定角色不在群聊成员中时抛出错误。
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
   * 重新排序群聊成员，按传入的 ID 列表顺序更新 order 字段。
   * 在用户手动调整群聊成员顺序时由 UI 层调用。
   * @param groupId 目标群聊标识，用于在 members 索引中查找成员列表。
   * @param characterIds 新的成员顺序（角色 ID 列表），必须包含所有成员且不重复。
   * @returns 重排序后的成员记录列表副本。
   * @throws 当 characterIds 数量与成员数不匹配或包含重复 ID 时抛出错误。
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
   * 返回指定群聊的所有成员记录副本列表。
   * 在 UI 群聊成员列表展示或提示词构建时由宿主调用。
   * @param groupId 目标群聊标识。
   * @returns 成员记录列表副本。
   */
  listMembers(groupId: string): Array<GroupMemberRecord> {
    return this.cloneMembers(this.requireMembers(groupId));
  }

  /**
   * 将群聊绑定到指定的用户人格，并发布绑定事件。
   * 在用户为群聊选择角色人格时由宿主或 UI 层调用。
   * @param groupId 目标群聊标识，用于在 groups 索引中查找并更新群聊的 personaId 字段。
   * @param personaId 要绑定的用户人格标识，更新到 GroupRecord.personaId 并在提示词中使用。
   * @returns 绑定记录，包含群聊 ID、人格 ID 和更新时间。
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
   * 选择群聊中的发言者：指定角色则返回该角色成员，未指定则按 talkativeness 选择最活跃的成员，并发布选择事件。
   * 在 AI 生成消息前由宿主或生成引擎调用，确定由哪个角色发言。
   * @param groupId 目标群聊标识，用于在 members 索引中获取候选成员列表。
   * @param characterId 指定的发言角色标识；传空字符串则通过 selectMostTalkative 自动选择最活跃成员。
   * @returns 被选中的群聊成员记录副本。
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
   * 根据群聊和共享世界信息构建提示词数据结构，供 AI 生成使用。
   * 在构建 AI 请求上下文时由生成引擎调用，生成包含群聊信息、成员列表和世界信息的提示词。
   * @param groupId 目标群聊标识，用于获取群聊记录和成员列表。
   * @param sharedWorldInfoText 共享的世界信息文本，在 mergeWorldInfo 中与各成员独有 worldInfoText 合并。
   * @returns 包含群聊上下文、成员信息、世界信息和完整提示词的 Prompt 数据。
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
   * 将重新生成请求加入群聊请求队列。
   * 在用户要求 AI 重新生成某条消息时由宿主或 UI 层调用。
   * @param groupId 目标群聊标识，用于在 requests 索引中定位队列。
   * @param chatId 关联的聊天标识，用于确定生成内容的归属聊天会话。
   * @param messageId 要重新生成的消息标识，指明需要替换哪条现有消息。
   * @returns 创建的生成请求记录。
   */
  queueRegenerate(groupId: string, chatId: string, messageId: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, messageId, 'regenerate', '', '');
  }

  /**
   * 将续写请求加入群聊请求队列。
   * 在用户要求 AI 继续生成后续消息时由宿主或 UI 层调用。
   * @param groupId 目标群聊标识，用于在 requests 索引中定位队列。
   * @param chatId 关联的聊天标识，用于确定续写内容的归属聊天会话。
   * @returns 创建的生成请求记录。
   */
  queueContinue(groupId: string, chatId: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, '', 'continue', '', '');
  }

  /**
   * 将工具调用请求加入群聊请求队列。
   * 在 AI 需要调用外部工具（如搜索、计算等）时由生成引擎调用。
   * @param groupId 目标群聊标识，用于在 requests 索引中定位队列。
   * @param chatId 关联的聊天标识。
   * @param toolName 要调用的工具名称，指明需要哪个 AI 工具执行操作。
   * @returns 创建的生成请求记录。
   */
  queueToolCall(groupId: string, chatId: string, toolName: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, '', 'tool_call', '', toolName);
  }

  /**
   * 返回指定群聊的所有生成请求记录副本列表。
   * 在查询群聊待处理请求时由宿主或生成引擎调用。
   * @param groupId 目标群聊标识。
   * @returns 生成请求记录列表副本。
   */
  listGenerationRequests(groupId: string): Array<GroupGenerationRequest> {
    return this.cloneRequests(this.requireRequests(groupId));
  }

  /**
   * 导出指定群聊的完整数据（群聊记录、成员列表和生成请求），用于备份和数据互通。
   * 在设置页面执行群聊导出操作时由宿主调用。
   * @param groupId 要导出的群聊标识。
   * @returns 包含群聊、成员和请求的可序列化导出对象。
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
   * 从外部数据导入群聊，转换为当前运行时的数据结构并分配新 ID。
   * 在设置页面执行群聊导入操作时由宿主调用。
   * @param data 待导入的群聊导出数据，包含群聊记录、成员和请求。
   * @param newGroupId 导入后群聊的新标识，避免与已有群聊 ID 冲突。
   * @returns 导入后的群聊记录副本。
   * @throws 当 newGroupId 已存在时抛出错误。
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
   * 按群聊 ID 查找群聊记录，不存在时抛出错误。
   * @param groupId 要查找的群聊标识。
   */
  private requireGroup(groupId: string): GroupRecord {
    const group = this.groups.get(groupId);
    if (group === undefined) {
      throw new Error(`Group not found: ${groupId}`);
    }
    return group;
  }

  /**
   * 按群聊 ID 查找成员列表，不存在时抛出错误。
   * @param groupId 要查找的群聊标识。
   * @returns 该群聊的成员列表（引用，非副本，调用方不应直接修改）。
   */
  private requireMembers(groupId: string): Array<GroupMemberRecord> {
    const members = this.members.get(groupId);
    if (members === undefined) {
      throw new Error(`Group members not found: ${groupId}`);
    }
    return members;
  }

  /**
   * 按群聊 ID 查找生成请求列表，不存在时抛出错误。
   * @param groupId 要查找的群聊标识。
   * @returns 该群聊的请求列表（引用，非副本）。
   */
  private requireRequests(groupId: string): Array<GroupGenerationRequest> {
    const requests = this.requests.get(groupId);
    if (requests === undefined) {
      throw new Error(`Group requests not found: ${groupId}`);
    }
    return requests;
  }

  /**
   * 在成员列表中按角色 ID 查找成员，未找到时抛出错误。
   * @param members 要搜索的成员列表。
   * @param characterId 要查找的角色标识。
   * @returns 匹配的成员记录。
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
   * 从启用的成员中选择 talkativeness 最高的成员作为发言者。
   * @param members 要筛选的成员列表。
   * @returns 选中的最活跃成员；如果所有成员均未启用，则返回列表第一个。
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
   * 深拷贝群聊记录，防止外部代码修改内部状态。
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
   * 深拷贝成员列表，每个成员均为副本。
   * @returns 成员记录副本列表。
   */
  private cloneMembers(members: Array<GroupMemberRecord>): Array<GroupMemberRecord> {
    const cloned = new Array<GroupMemberRecord>();
    for (let index = 0; index < members.length; index += 1) {
      cloned.push(this.cloneMember(members[index]));
    }
    return cloned;
  }

  /**
   * 深拷贝群聊成员记录，防止外部代码修改内部状态。
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
   * 深拷贝生成请求列表，每个请求均为副本。
   * @returns 生成请求记录副本列表。
   */
  private cloneRequests(requests: Array<GroupGenerationRequest>): Array<GroupGenerationRequest> {
    const cloned = new Array<GroupGenerationRequest>();
    for (let index = 0; index < requests.length; index += 1) {
      cloned.push(this.cloneRequest(requests[index]));
    }
    return cloned;
  }

  /**
   * 深拷贝生成请求记录，防止外部代码修改内部状态。
   * @param request 要复制的原始生成请求对象。
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
   * 从请求 ID 中解析出自增计数器值，用于导入时保持计数器不冲突。
   * @param requestId 生成请求标识，格式为 'group-request-{数字}'。
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
   * 深拷贝人格绑定记录，防止外部代码修改内部状态。
   */
  private cloneBinding(binding: GroupPersonaBindingRecord): GroupPersonaBindingRecord {
    return {
      groupId: binding.groupId,
      personaId: binding.personaId,
      updatedAt: binding.updatedAt,
    };
  }

  /**
   * 发布群聊事件，将状态变化通过事件总线通知给宿主或其他模块。
   * @param eventName 要发布的事件名称。
   * @param group 事件关联的群聊记录。
   */
  private publishGroupEvent(eventName: string, group: GroupRecord): void {
    const payloadGroup = this.cloneGroup(group);
    const payload: GroupEventPayload = {
      group: payloadGroup,
    };
    this.events.publish<GroupEventPayload>(eventName, payload);
  }
}
