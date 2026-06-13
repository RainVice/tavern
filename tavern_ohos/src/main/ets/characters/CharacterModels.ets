export interface CharacterCreateParams {
  name: string;
  description: string;
  personality: string;
  scenario: string;
  firstMessage: string;
  exampleDialogue: string;
  tags: Array<string>;
  favorite?: boolean;
  talkativeness?: number;
  world?: string;
}

export interface CharacterUpdateParams {
  name: string;
  description: string;
  personality: string;
  scenario: string;
  firstMessage: string;
  exampleDialogue: string;
  tags: Array<string>;
  favorite: boolean;
}

export interface CharacterRecord {
  schemaVersion: number;
  id: string;
  name: string;
  description: string;
  personality: string;
  scenario: string;
  firstMessage: string;
  exampleDialogue: string;
  creatorNotes: string;
  systemPrompt: string;
  postHistoryInstructions: string;
  creator: string;
  characterVersion: string;
  avatarPath: string;
  tags: Array<string>;
  alternateGreetings: Array<string>;
  favorite: boolean;
  talkativeness: number;
  world: string;
  sourceFormat: string;
  sourceJson: string;
  createdAt: number;
  updatedAt: number;
}

export interface CharacterIndexEntry {
  id: string;
  name: string;
  avatarPath: string;
  tags: Array<string>;
  favorite: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface CharacterIndex {
  schemaVersion: number;
  nextId: number;
  items: Array<CharacterIndexEntry>;
}

export interface CharacterEventPayload {
  character: CharacterRecord;
}

export interface CharacterDeletedPayload {
  characterId: string;
}

export interface CharacterCardV2 {
  spec: string;
  spec_version: string;
  data: CharacterCardV2Data;
}

export interface CharacterCardV2Data {
  name: string;
  description: string;
  personality: string;
  scenario: string;
  first_mes: string;
  mes_example: string;
  creator_notes?: string;
  system_prompt?: string;
  post_history_instructions?: string;
  creator?: string;
  character_version?: string;
  tags?: Array<string>;
  alternate_greetings?: Array<string>;
  extensions?: CharacterCardV2Extensions;
}

export interface CharacterCardV2Extensions {
  fav?: boolean;
  talkativeness?: number;
  world?: string;
}
