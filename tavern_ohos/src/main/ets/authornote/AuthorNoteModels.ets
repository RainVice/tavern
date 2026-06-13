export const AUTHOR_NOTE_MODULE_NAME: string = '2_floating_prompt';

export interface AuthorNoteMetadata {
  prompt: string;
  interval: number;
  depth: number;
  position: number;
  role: number;
}

export interface AuthorNoteDefaults {
  prompt: string;
  interval: number;
  depth: number;
  position: number;
  role: number;
  allowWorldInfoScan: boolean;
}

export interface AuthorNoteCharacterNote {
  prompt: string;
  enabled: boolean;
  position: number;
}

export interface AuthorNoteBuildInput {
  chatId: string;
  inChat: boolean;
  userMessageCount: number;
  metadata: AuthorNoteMetadata;
  defaults: AuthorNoteDefaults;
  characterNote?: AuthorNoteCharacterNote;
}

export interface AuthorNoteInjection {
  moduleName: string;
  chatId: string;
  prompt: string;
  enabled: boolean;
  shouldScanWorldInfo: boolean;
  messagesTillInsertion: number;
  position: number;
  depth: number;
  role: number;
}

export interface AuthorNoteBuiltPayload {
  injection: AuthorNoteInjection;
}
