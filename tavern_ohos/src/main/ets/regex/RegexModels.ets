export interface RegexScriptRecord {
  id: string;
  scriptName: string;
  sourceType: string;
  scopeId: string;
  findRegex: string;
  flags: string;
  replaceString: string;
  placements: Array<string>;
  disabled: boolean;
  markdownOnly: boolean;
  promptOnly: boolean;
  runOnEdit: boolean;
  minDepth: number;
  maxDepth: number;
  ephemeral: boolean;
  trimStrings: Array<string>;
}

export interface RegexApplyInput {
  text: string;
  placement: string;
  isMarkdown: boolean;
  isPrompt: boolean;
  isEdit: boolean;
  depth: number;
  scopeId: string;
}

export interface RegexApplyTrace {
  scriptId: string;
  scriptName: string;
  placement: string;
  before: string;
  after: string;
  changed: boolean;
  diff: string;
}

export interface RegexApplyResult {
  text: string;
  traces: Array<RegexApplyTrace>;
}

export interface RegexAppliedPayload {
  trace: RegexApplyTrace;
}
