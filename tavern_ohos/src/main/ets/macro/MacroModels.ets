import type { VariableResolveContext } from '../variable/VariableModels';

export interface MacroEvaluationContext {
  userName: string;
  characterName: string;
  personaName: string;
  chatName: string;
  messageText: string;
  worldInfoName: string;
  variableContext: VariableResolveContext;
}

export interface MacroExecutionContext {
  name: string;
  args: Array<string>;
  raw: string;
  context: MacroEvaluationContext;
}

export interface MacroAction {
  expand(context: MacroExecutionContext): string;
}

export interface MacroRegistrationParams {
  name: string;
  category: string;
  description: string;
  source: string;
  pluginId: string;
  action: MacroAction;
}

export interface MacroRecord {
  name: string;
  category: string;
  description: string;
  source: string;
  pluginId: string;
}

export interface MacroDiagnostic {
  macroName: string;
  message: string;
  offset: number;
  raw: string;
}

export interface MacroExpansionResult {
  text: string;
  diagnostics: Array<MacroDiagnostic>;
}

export interface MacroExpandedPayload {
  input: string;
  output: string;
  diagnostics: Array<MacroDiagnostic>;
}

export interface MacroRegisteredPayload {
  macro: MacroRecord;
}
