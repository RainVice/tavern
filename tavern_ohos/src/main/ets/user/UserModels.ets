/**
 * 描述创建新用户时所需传入的参数。
 */
export interface UserCreateParams {
  /**
   * 用户句柄（唯一标识，会被规范化 slug）。
   */
  handle: string;
  /**
   * 显示名称。
   */
  name: string;
  /**
   * 登录密码（为空表示无密码登录）。
   */
  password?: string;
  /**
   * 是否为管理员。
   */
  admin?: boolean;
  /**
   * 是否启用该用户。
   */
  enabled?: boolean;
}

/**
 * 描述用户内部存储记录的完整数据结构，包含密码哈希等敏感字段。
 */
export interface UserRecord {
  /**
   * 用户句柄（规范化后的唯一标识）。
   */
  handle: string;
  /**
   * 显示名称。
   */
  name: string;
  /**
   * 用户账号创建时间戳。
   */
  created: number;
  /**
   * 密码的 FNV-1a 哈希值（格式为 "salt:hash"）。
   */
  passwordHash: string;
  /**
   * 密码加盐值。
   */
  salt: string;
  /**
   * 用户是否被启用。
   */
  enabled: boolean;
  /**
   * 用户是否拥有管理员权限。
   */
  admin: boolean;
  /**
   * 头像的 base64 数据 URL（格式 "data:image/..."）。
   */
  avatar: string;
  /**
   * 用户账号版本号（每次变更递增，用于会话失效校验）。
   */
  accountVersion: number;
  /**
   * 最近更新时间戳。
   */
  updatedAt: number;
}

/**
 * 描述用户信息对外暴露的视图模型，不包含密码哈希等敏感数据。
 */
export interface UserViewModel {
  /**
   * 用户句柄（唯一标识）。
   */
  handle: string;
  /**
   * 显示名称。
   */
  name: string;
  /**
   * 头像 URL 或 base64 数据。
   */
  avatar: string;
  /**
   * 是否为管理员（仅在管理上下文可见）。
   */
  admin: boolean;
  /**
   * 用户是否设置了密码（对外隐藏密码本身，仅表示有无）。
   */
  password: boolean;
  /**
   * 是否启用。
   */
  enabled: boolean;
  /**
   * 账号创建时间戳。
   */
  created: number;
}

/**
 * 描述用户目录结构的映射关系，每个字段对应用户在文件系统中的子目录路径。
 */
export interface UserDirectoryList {
  /**
   * 用户根目录路径，格式为 "users/{handle}"。
   */
  root: string;
  /**
   * 缩略图目录路径。
   */
  thumbnails: string;
  /**
   * 缩略图背景子目录路径。
   */
  thumbnailsBg: string;
  /**
   * 头像缩略图子目录路径。
   */
  thumbnailsAvatar: string;
  /**
   * 角色缩略图子目录路径。
   */
  thumbnailsPersona: string;
  /**
   * 世界书目录路径。
   */
  worlds: string;
  /**
   * 用户配置目录路径。
   */
  user: string;
  /**
   * 头像资源目录路径。
   */
  avatars: string;
  /**
   * 用户图片目录路径。
   */
  userImages: string;
  /**
   * 群组配置目录路径。
   */
  groups: string;
  /**
   * 群组聊天记录目录路径。
   */
  groupChats: string;
  /**
   * 聊天记录目录路径。
   */
  chats: string;
  /**
   * 角色卡片目录路径。
   */
  characters: string;
  /**
   * 聊天背景目录路径。
   */
  backgrounds: string;
  /**
   * NovelAI 设置文件路径。
   */
  novelAI_Settings: string;
  /**
   * KoboldAI 设置文件路径。
   */
  koboldAI_Settings: string;
  /**
   * OpenAI 设置文件路径。
   */
  openAI_Settings: string;
  /**
   * TextGen 设置文件路径。
   */
  textGen_Settings: string;
  /**
   * 主题配置目录路径。
   */
  themes: string;
  /**
   * 移动端 UI 布局配置目录路径。
   */
  movingUI: string;
  /**
   * 扩展插件配置目录路径。
   */
  extensions: string;
  /**
   * 指令配置目录路径。
   */
  instruct: string;
  /**
   * 上下文配置目录路径。
   */
  context: string;
  /**
   * 快捷回复配置目录路径。
   */
  quickreplies: string;
  /**
   * 静态资源目录路径。
   */
  assets: string;
  /**
   * ComfyUI 工作流配置目录路径。
   */
  comfyWorkflows: string;
  /**
   * 文件存储适配器目录路径。
   */
  files: string;
  /**
   * 向量存储目录路径。
   */
  vectors: string;
  /**
   * 备份目录路径。
   */
  backups: string;
  /**
   * 系统提示词配置文件路径。
   */
  sysprompt: string;
  /**
   * 推理设置配置文件路径。
   */
  reasoning: string;
}

/**
 * 描述用户登录会话的内部记录结构。
 */
export interface UserSessionRecord {
  /**
   * 会话唯一标识（如 "session-1"）。
   */
  id: string;
  /**
   * 关联的用户句柄。
   */
  handle: string;
  /**
   * 创建会话时的用户账号版本号，用于校验会话是否有效。
   */
  accountVersion: number;
  /**
   * 会话创建时间戳。
   */
  createdAt: number;
  /**
   * 会话最近活动时间戳。
   */
  updatedAt: number;
}

/**
 * 描述用户登录操作完成后返回给调用方的结果，包含用户信息和会话信息。
 */
export interface UserLoginResult {
  /**
   * 登录用户的视图模型。
   */
  user: UserViewModel;
  /**
   * 本次登录创建的会话记录。
   */
  session: UserSessionRecord;
}

/**
 * 描述用户创建、启用、禁用、更新等事件发布时携带的负载数据。
 */
export interface UserEventPayload {
  /**
   * 关联用户的视图模型。
   */
  user: UserViewModel;
}

/**
 * 描述用户被删除事件（如 user.deleted）发布时携带的负载数据。
 */
export interface UserDeletedPayload {
  /**
   * 被删除用户的句柄。
   */
  handle: string;
  /**
   * 是否同时清除用户的持久化数据。
   */
  purge: boolean;
}

/**
 * 描述用户登录或登出事件（如 user.logged_in、user.logged_out）发布时携带的负载数据。
 */
export interface UserSessionPayload {
  /**
   * 相关会话记录。
   */
  session: UserSessionRecord;
  /**
   * 关联用户的视图模型。
   */
  user: UserViewModel;
}
