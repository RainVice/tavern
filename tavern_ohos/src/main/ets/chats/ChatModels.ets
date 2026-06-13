export interface ChatCreateParams {
  title: string;
  characterId: string;
  personaId: string;
}

export interface ChatRecord {
  schemaVersion: number;
  id: string;
  title: string;
  characterId: string;
  personaId: string;
  archived: boolean;
  nextMessageId: number;
  createdAt: number;
  updatedAt: number;
}

export interface ChatIndex {
  schemaVersion: number;
  nextId: number;
  items: Array<ChatIndexEntry>;
}

export interface ChatIndexEntry {
  id: string;
  title: string;
  characterId: string;
  personaId: string;
  archived: boolean;
  messageCount: number;
  previewMessage: string;
  createdAt: number;
  updatedAt: number;
}

export interface ChatEventPayload {
  chat: ChatRecord;
}

export interface ChatMessageCreateParams {
  name: string;
  role: string;
  text: string;
}

export interface ChatMessageUpdateParams {
  text: string;
  isSystem: boolean;
}

export interface ChatMessage {
  schemaVersion: number;
  id: string;
  index: number;
  name: string;
  role: string;
  isUser: boolean;
  isSystem: boolean;
  sendDate: string;
  text: string;
  swipes: Array<string>;
  activeSwipeIndex: number;
  extraJson: string;
}

export interface MessageExtraData {
  rating: number;
  bookmarked: boolean;
  bookmark_link: string;
  branches: Array<string>;
}

export interface MessageEventPayload {
  chatId: string;
  message: ChatMessage;
}

export interface ChatExportMetadata {
  chat_id: string;
  title: string;
  character_id: string;
  persona_id: string;
}

export interface ChatExportHeader {
  chat_metadata: ChatExportMetadata;
  user_name: string;
  character_name: string;
}

export interface ChatExportExtra {
  rating?: number;
  bookmarked?: boolean;
  bookmark_link?: string;
  branches?: Array<string>;
  source?: string;
}

export interface ChatExportMessage {
  name?: string;
  is_user?: boolean;
  is_system?: boolean;
  send_date?: string;
  mes?: string;
  swipes?: Array<string>;
  extra?: ChatExportExtra;
}
