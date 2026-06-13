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

export class GroupRuntime {
  private events: EventBus;
  private groups: Map<string, GroupRecord> = new Map<string, GroupRecord>();
  private members: Map<string, Array<GroupMemberRecord>> = new Map<string, Array<GroupMemberRecord>>();
  private requests: Map<string, Array<GroupGenerationRequest>> = new Map<string, Array<GroupGenerationRequest>>();
  private requestCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

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

  getGroup(groupId: string): GroupRecord {
    return this.cloneGroup(this.requireGroup(groupId));
  }

  listGroups(): Array<GroupRecord> {
    const result = new Array<GroupRecord>();
    const values = Array.from(this.groups.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.cloneGroup(values[index]));
    }
    return result;
  }

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

  listMembers(groupId: string): Array<GroupMemberRecord> {
    return this.cloneMembers(this.requireMembers(groupId));
  }

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

  queueRegenerate(groupId: string, chatId: string, messageId: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, messageId, 'regenerate', '', '');
  }

  queueContinue(groupId: string, chatId: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, '', 'continue', '', '');
  }

  queueToolCall(groupId: string, chatId: string, toolName: string): GroupGenerationRequest {
    return this.queueRequest(groupId, chatId, '', 'tool_call', '', toolName);
  }

  listGenerationRequests(groupId: string): Array<GroupGenerationRequest> {
    return this.cloneRequests(this.requireRequests(groupId));
  }

  exportGroup(groupId: string): GroupExportData {
    const data: GroupExportData = {
      group: this.cloneGroup(this.requireGroup(groupId)),
      members: this.cloneMembers(this.requireMembers(groupId)),
      requests: this.cloneRequests(this.requireRequests(groupId)),
    };
    return data;
  }

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

  private requireGroup(groupId: string): GroupRecord {
    const group = this.groups.get(groupId);
    if (group === undefined) {
      throw new Error(`Group not found: ${groupId}`);
    }
    return group;
  }

  private requireMembers(groupId: string): Array<GroupMemberRecord> {
    const members = this.members.get(groupId);
    if (members === undefined) {
      throw new Error(`Group members not found: ${groupId}`);
    }
    return members;
  }

  private requireRequests(groupId: string): Array<GroupGenerationRequest> {
    const requests = this.requests.get(groupId);
    if (requests === undefined) {
      throw new Error(`Group requests not found: ${groupId}`);
    }
    return requests;
  }

  private findMember(members: Array<GroupMemberRecord>, characterId: string): GroupMemberRecord {
    for (let index = 0; index < members.length; index += 1) {
      if (members[index].characterId === characterId) {
        return members[index];
      }
    }
    throw new Error(`Group member not found: ${characterId}`);
  }

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

  private cloneMembers(members: Array<GroupMemberRecord>): Array<GroupMemberRecord> {
    const cloned = new Array<GroupMemberRecord>();
    for (let index = 0; index < members.length; index += 1) {
      cloned.push(this.cloneMember(members[index]));
    }
    return cloned;
  }

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

  private cloneRequests(requests: Array<GroupGenerationRequest>): Array<GroupGenerationRequest> {
    const cloned = new Array<GroupGenerationRequest>();
    for (let index = 0; index < requests.length; index += 1) {
      cloned.push(this.cloneRequest(requests[index]));
    }
    return cloned;
  }

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

  private cloneBinding(binding: GroupPersonaBindingRecord): GroupPersonaBindingRecord {
    return {
      groupId: binding.groupId,
      personaId: binding.personaId,
      updatedAt: binding.updatedAt,
    };
  }

  private publishGroupEvent(eventName: string, group: GroupRecord): void {
    const payload: GroupEventPayload = {
      group: this.cloneGroup(group),
    };
    this.events.publish<GroupEventPayload>(eventName, payload);
  }
}
