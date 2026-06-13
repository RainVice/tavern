import type { ChatMessage } from '../chats/ChatModels';

export const BOOKMARK_NAME_TOKEN: string = 'Checkpoint #';
export const BRANCH_NAME_TOKEN: string = 'Branch #';

export interface BookmarkNameInput {
  currentChatName: string;
  existingChatNames: Array<string>;
  forceName?: string;
}

export interface BookmarkMetadata {
  mainChat: string;
}

export interface BookmarkExtra {
  bookmark_link: string;
  branches: Array<string>;
}

export interface BookmarkResult {
  name: string;
  metadata: BookmarkMetadata;
  snapshot: Array<ChatMessage>;
  updatedMessages: Array<ChatMessage>;
}

export interface BranchResult {
  name: string;
  metadata: BookmarkMetadata;
  snapshot: Array<ChatMessage>;
  updatedMessages: Array<ChatMessage>;
}

export interface BookmarkCreatedPayload {
  name: string;
  messageId: string;
  metadata: BookmarkMetadata;
}

export interface BranchCreatedPayload {
  name: string;
  messageId: string;
  metadata: BookmarkMetadata;
}
