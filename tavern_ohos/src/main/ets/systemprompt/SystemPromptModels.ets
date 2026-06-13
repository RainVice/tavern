export interface SystemPromptRecord {
  name: string;
  content: string;
  postHistory: string;
}

export interface SystemPromptState {
  enabled: boolean;
  name: string;
  content: string;
  postHistory: string;
}

export interface SystemPromptPayload {
  state: SystemPromptState;
}
