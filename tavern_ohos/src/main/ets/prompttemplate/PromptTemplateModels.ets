export interface PromptTemplateDerivation {
  context: string | null;
  instruct: string | null;
}

export interface PromptTemplateRegistrationParams {
  id: string;
  content: string;
}

export interface PromptTemplateRecord {
  id: string;
  content: string;
}

export interface PromptTemplateRenderedPayload {
  templateId: string;
  output: string;
}
