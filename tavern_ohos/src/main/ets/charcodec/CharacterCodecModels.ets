export type CharacterCardFormat = 'v1' | 'v2' | 'charx' | 'png_metadata' | 'unknown';
export interface CharacterCodecResult {
  format: CharacterCardFormat; raw: string; name: string; description: string;
  personality: string; scenario: string; firstMessage: string; exampleDialogue: string;
  creatorNotes: string; systemPrompt: string; postHistoryInstructions: string;
  creator: string; characterVersion: string; tags: Array<string>;
  alternateGreetings: Array<string>; extensions: Record<string, string>;
}
export interface CharacterCardV1 { name?: string; description?: string; personality?: string; scenario?: string; first_mes?: string; mes_example?: string; }
export interface CharacterCardV2Input {
  spec?: string; spec_version?: string; data?: CharacterCardV2InputData;
}
export interface CharacterCardV2InputData {
  name?: string; description?: string; personality?: string; scenario?: string;
  first_mes?: string; mes_example?: string; creator_notes?: string; system_prompt?: string;
  post_history_instructions?: string; creator?: string; character_version?: string;
  tags?: Array<string>; alternate_greetings?: Array<string>; extensions?: CharacterCardV2InputExtensions;
}
export type CharacterCardV2InputExtensionValue = string | number | boolean;
export type CharacterCardV2InputExtensions = Record<string, CharacterCardV2InputExtensionValue>;
export interface CharacterCardV2Export {
  spec: string; spec_version: string; data: CharacterCardV2ExportData;
}
export interface CharacterCardV2ExportData {
  name: string; description: string; personality: string; scenario: string;
  first_mes: string; mes_example: string; creator_notes: string; system_prompt: string;
  post_history_instructions: string; creator: string; character_version: string;
  tags: Array<string>; alternate_greetings: Array<string>; extensions: Record<string, string>;
}
export interface CharxArchive { spec: string; spec_version: string; characters: Array<CharacterCardV1>; }
export interface CharacterBookInput { name?: string; entries?: Array<CharacterBookEntryInput>; }
export interface CharacterBookEntryInput { id?: string; keys?: Array<string>; content?: string; }
export interface CharacterBookEntry { id: string; keys: Array<string>; content: string; }
export interface CharacterBook { name: string; entries: Array<CharacterBookEntry>; }
export interface CodecExportData { formatVersions: Array<string>; }
