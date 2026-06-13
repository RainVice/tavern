import type { CharacterRecord } from '../characters/CharacterModels';
import type { ChatMessage } from '../chats/ChatModels';
import type { WorldInfoActivation } from '../worldinfo/WorldInfoModels';

export interface PromptBuildInput {
  id: string;
  systemPrompt: string;
  personaName: string;
  personaDescription: string;
  authorNote: string;
  character: CharacterRecord;
  messages: Array<ChatMessage>;
  worldInfo: WorldInfoActivation;
  maxEstimatedTokens: number;
}

export interface PromptBuildResult {
  id: string;
  sections: Array<PromptSection>;
  finalText: string;
  debug: PromptDebugSnapshot;
}

export interface PromptSection {
  id: string;
  type: string;
  role: string;
  source: string;
  content: string;
  estimatedTokens: number;
}

export interface PromptDebugSnapshot {
  promptId: string;
  sectionCount: number;
  estimatedTokens: number;
  maxEstimatedTokens: number;
  trimmedSections: Array<string>;
}

export interface PromptBuiltPayload {
  prompt: PromptBuildResult;
}
