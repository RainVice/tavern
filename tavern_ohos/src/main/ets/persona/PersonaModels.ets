export interface PersonaCreateParams {
  id: string;
  name: string;
  description: string;
  avatarRef: string;
  tags: Array<string>;
  lorebookId: string;
  promptInjectionStrategy: string;
  userMacroValue: string;
  enabled: boolean;
}

export interface PersonaRecord {
  id: string;
  name: string;
  description: string;
  avatarRef: string;
  tags: Array<string>;
  lorebookId: string;
  promptInjectionStrategy: string;
  userMacroValue: string;
  enabled: boolean;
  updatedAt: number;
}

export interface PersonaBindingRecord {
  scope: string;
  scopeId: string;
  personaId: string;
  updatedAt: number;
}

export interface PersonaPromptData {
  personaId: string;
  name: string;
  description: string;
  avatarRef: string;
  lorebookId: string;
  promptInjectionStrategy: string;
  userMacroValue: string;
  tags: Array<string>;
}

export interface PersonaExportData {
  persona: PersonaRecord;
}

export interface PersonaChangedPayload {
  persona: PersonaRecord;
  previousPersonaId: string;
}

export interface PersonaUpdatedPayload {
  persona: PersonaRecord;
}

export interface PersonaDeletedPayload {
  personaId: string;
}
