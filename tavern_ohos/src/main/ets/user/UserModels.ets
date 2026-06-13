export interface UserCreateParams {
  handle: string;
  name: string;
  password?: string;
  admin?: boolean;
  enabled?: boolean;
}

export interface UserRecord {
  handle: string;
  name: string;
  created: number;
  passwordHash: string;
  salt: string;
  enabled: boolean;
  admin: boolean;
  avatar: string;
  accountVersion: number;
  updatedAt: number;
}

export interface UserViewModel {
  handle: string;
  name: string;
  avatar: string;
  admin: boolean;
  password: boolean;
  enabled: boolean;
  created: number;
}

export interface UserDirectoryList {
  root: string;
  thumbnails: string;
  thumbnailsBg: string;
  thumbnailsAvatar: string;
  thumbnailsPersona: string;
  worlds: string;
  user: string;
  avatars: string;
  userImages: string;
  groups: string;
  groupChats: string;
  chats: string;
  characters: string;
  backgrounds: string;
  novelAI_Settings: string;
  koboldAI_Settings: string;
  openAI_Settings: string;
  textGen_Settings: string;
  themes: string;
  movingUI: string;
  extensions: string;
  instruct: string;
  context: string;
  quickreplies: string;
  assets: string;
  comfyWorkflows: string;
  files: string;
  vectors: string;
  backups: string;
  sysprompt: string;
  reasoning: string;
}

export interface UserSessionRecord {
  id: string;
  handle: string;
  accountVersion: number;
  createdAt: number;
  updatedAt: number;
}

export interface UserLoginResult {
  user: UserViewModel;
  session: UserSessionRecord;
}

export interface UserEventPayload {
  user: UserViewModel;
}

export interface UserDeletedPayload {
  handle: string;
  purge: boolean;
}

export interface UserSessionPayload {
  session: UserSessionRecord;
  user: UserViewModel;
}
