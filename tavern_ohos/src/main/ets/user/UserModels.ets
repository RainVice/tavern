/**
 * 描述调用用户和会话能力时需要传入的参数。
 */
export interface UserCreateParams {
  /**
   * handle 值，由当前实例内部维护。
   */
  handle: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * password 值，由当前实例内部维护。
   */
  password?: string;
  /**
   * admin 值，由当前实例内部维护。
   */
  admin?: boolean;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled?: boolean;
}

/**
 * 描述用户和会话持久化或内存索引中的一条记录。
 */
export interface UserRecord {
  /**
   * handle 值，由当前实例内部维护。
   */
  handle: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * 创建后的记录，由当前实例内部维护。
   */
  created: number;
  /**
   * password Hash 值，由当前实例内部维护。
   */
  passwordHash: string;
  /**
   * salt 值，由当前实例内部维护。
   */
  salt: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * admin 值，由当前实例内部维护。
   */
  admin: boolean;
  /**
   * avatar 值，由当前实例内部维护。
   */
  avatar: string;
  /**
   * account Version 值，由当前实例内部维护。
   */
  accountVersion: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述用户和会话模块在运行时交换的数据结构。
 */
export interface UserViewModel {
  /**
   * handle 值，由当前实例内部维护。
   */
  handle: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * avatar 值，由当前实例内部维护。
   */
  avatar: string;
  /**
   * admin 值，由当前实例内部维护。
   */
  admin: boolean;
  /**
   * password 值，由当前实例内部维护。
   */
  password: boolean;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * 创建后的记录，由当前实例内部维护。
   */
  created: number;
}

/**
 * 描述用户和会话模块在运行时交换的数据结构。
 */
export interface UserDirectoryList {
  /**
   * 规范化后的根路径，由当前实例内部维护。
   */
  root: string;
  /**
   * thumbnails 列表，由当前实例内部维护。
   */
  thumbnails: string;
  /**
   * thumbnails Bg 值，由当前实例内部维护。
   */
  thumbnailsBg: string;
  /**
   * thumbnails Avatar 值，由当前实例内部维护。
   */
  thumbnailsAvatar: string;
  /**
   * thumbnails Persona 值，由当前实例内部维护。
   */
  thumbnailsPersona: string;
  /**
   * worlds 列表，由当前实例内部维护。
   */
  worlds: string;
  /**
   * user 值，由当前实例内部维护。
   */
  user: string;
  /**
   * avatars 列表，由当前实例内部维护。
   */
  avatars: string;
  /**
   * user Images 列表，由当前实例内部维护。
   */
  userImages: string;
  /**
   * groups 列表，由当前实例内部维护。
   */
  groups: string;
  /**
   * group Chats 列表，由当前实例内部维护。
   */
  groupChats: string;
  /**
   * chats 列表，由当前实例内部维护。
   */
  chats: string;
  /**
   * characters 列表，由当前实例内部维护。
   */
  characters: string;
  /**
   * backgrounds 列表，由当前实例内部维护。
   */
  backgrounds: string;
  /**
   * novel AI Settings 列表，由当前实例内部维护。
   */
  novelAI_Settings: string;
  /**
   * kobold AI Settings 列表，由当前实例内部维护。
   */
  koboldAI_Settings: string;
  /**
   * open AI Settings 列表，由当前实例内部维护。
   */
  openAI_Settings: string;
  /**
   * text Gen Settings 列表，由当前实例内部维护。
   */
  textGen_Settings: string;
  /**
   * themes 列表，由当前实例内部维护。
   */
  themes: string;
  /**
   * moving UI 值，由当前实例内部维护。
   */
  movingUI: string;
  /**
   * extensions 列表，由当前实例内部维护。
   */
  extensions: string;
  /**
   * instruct 值，由当前实例内部维护。
   */
  instruct: string;
  /**
   * context 值，由当前实例内部维护。
   */
  context: string;
  /**
   * quickreplies 列表，由当前实例内部维护。
   */
  quickreplies: string;
  /**
   * assets 列表，由当前实例内部维护。
   */
  assets: string;
  /**
   * comfy Workflows 列表，由当前实例内部维护。
   */
  comfyWorkflows: string;
  /**
   * 文件存储适配器。
   */
  files: string;
  /**
   * vectors 列表，由当前实例内部维护。
   */
  vectors: string;
  /**
   * backups 列表，由当前实例内部维护。
   */
  backups: string;
  /**
   * sysprompt 值，由当前实例内部维护。
   */
  sysprompt: string;
  /**
   * reasoning 值，由当前实例内部维护。
   */
  reasoning: string;
}

/**
 * 描述用户和会话持久化或内存索引中的一条记录。
 */
export interface UserSessionRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * handle 值，由当前实例内部维护。
   */
  handle: string;
  /**
   * account Version 值，由当前实例内部维护。
   */
  accountVersion: number;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述用户和会话操作完成后返回给调用方的结果。
 */
export interface UserLoginResult {
  /**
   * user 值，由当前实例内部维护。
   */
  user: UserViewModel;
  /**
   * session 值，由当前实例内部维护。
   */
  session: UserSessionRecord;
}

/**
 * 描述用户和会话事件发布时携带的数据结构。
 */
export interface UserEventPayload {
  /**
   * user 值，由当前实例内部维护。
   */
  user: UserViewModel;
}

/**
 * 描述用户和会话事件发布时携带的数据结构。
 */
export interface UserDeletedPayload {
  /**
   * handle 值，由当前实例内部维护。
   */
  handle: string;
  /**
   * purge 值，由当前实例内部维护。
   */
  purge: boolean;
}

/**
 * 描述用户和会话事件发布时携带的数据结构。
 */
export interface UserSessionPayload {
  /**
   * session 值，由当前实例内部维护。
   */
  session: UserSessionRecord;
  /**
   * user 值，由当前实例内部维护。
   */
  user: UserViewModel;
}
