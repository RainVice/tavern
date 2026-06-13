export interface VariableResolveContext {
  userId: string;
  characterId: string;
  personaId: string;
  chatId: string;
  groupId: string;
  messageId: string;
  pluginId: string;
}

export interface VariableEntry {
  scope: string;
  scopeId: string;
  pluginId: string;
  key: string;
  value: string;
  persistent: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface VariableResolveResult {
  found: boolean;
  scope: string;
  scopeId: string;
  key: string;
  value: string;
}

export interface VariableChangedPayload {
  scope: string;
  scopeId: string;
  key: string;
  oldValue: string;
  newValue: string;
  persistent: boolean;
}

export interface VariableDeletedPayload {
  scope: string;
  scopeId: string;
  key: string;
  oldValue: string;
}

export interface VariableExportData {
  entries: Array<VariableEntry>;
  exportedAt: number;
}
