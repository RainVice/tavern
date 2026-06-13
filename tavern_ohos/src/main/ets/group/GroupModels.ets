export interface GroupCreateParams {
  id: string;
  name: string;
  description: string;
  chatId: string;
  enabled: boolean;
  activationStrategy: string;
}

export interface GroupRecord {
  schemaVersion: number;
  id: string;
  name: string;
  description: string;
  chatId: string;
  personaId: string;
  enabled: boolean;
  activationStrategy: string;
  createdAt: number;
  updatedAt: number;
}

export interface GroupMemberCreateParams {
  characterId: string;
  characterName: string;
  role: string;
  talkativeness: number;
  enabled: boolean;
  worldInfoText: string;
}

export interface GroupMemberRecord {
  groupId: string;
  characterId: string;
  characterName: string;
  role: string;
  order: number;
  talkativeness: number;
  enabled: boolean;
  worldInfoText: string;
  createdAt: number;
  updatedAt: number;
}

export interface GroupPersonaBindingRecord {
  groupId: string;
  personaId: string;
  updatedAt: number;
}

export interface GroupPromptData {
  groupId: string;
  groupName: string;
  personaId: string;
  memberNames: string;
  worldInfoText: string;
  promptText: string;
}

export interface GroupGenerationRequest {
  id: string;
  groupId: string;
  chatId: string;
  messageId: string;
  requestType: string;
  speakerCharacterId: string;
  toolName: string;
  createdAt: number;
}

export interface GroupExportData {
  group: GroupRecord;
  members: Array<GroupMemberRecord>;
  requests: Array<GroupGenerationRequest>;
}

export interface GroupEventPayload {
  group: GroupRecord;
}

export interface GroupDeletedPayload {
  groupId: string;
}

export interface GroupMemberAddedPayload {
  groupId: string;
  characterId: string;
  member: GroupMemberRecord;
}

export interface GroupSpeakerSelectedPayload {
  groupId: string;
  characterId: string;
  member: GroupMemberRecord;
}
