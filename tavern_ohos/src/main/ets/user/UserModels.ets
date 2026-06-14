/**
 * 描述调用用户和会话能力时需要传入的参数。
 */
export interface UserCreateParams {
  /**
   * 用户唯一标识，由 handle 字段经 slugify 转换得到，用于后续登录和权限校验的查询依据。
   */
  handle: string;
  /**
   * 名称，用于在用户管理界面和聊天中显示的用户标签。
   */
  name: string;
  /**
   * 用户登录密码，可选，为空时视为无密码账户，用于身份验证流程。
   */
  password?: string;
  /**
   * 是否为管理员用户，可选，默认 false，决定该用户是否拥有用户管理和系统配置的权限。
   */
  admin?: boolean;
  /**
   * 账户是否启用，可选，默认 true，控制该用户能否登录和执行操作。
   */
  enabled?: boolean;
}

/**
 * 描述用户和会话持久化或内存索引中的一条记录。
 */
export interface UserRecord {
  /**
   * 用户唯一标识，由创建时 handle 经 slugify 转换得到，用于用户查询、会话关联和权限校验。
   */
  handle: string;
  /**
   * 名称，用于在用户管理界面和聊天中显示的用户标签。
   */
  name: string;
  /**
   * 账户创建时间戳（毫秒），用于用户列表排序和账户生命周期统计。
   */
  created: number;
  /**
   * 经加盐哈希处理后的密码字符串，用于登录时密码验证的比对依据。
   */
  passwordHash: string;
  /**
   * 密码加盐值，用于哈希计算，防止彩虹表攻击的密码存储安全措施。
   */
  salt: string;
  /**
   * 账户是否启用，控制该用户能否登录系统，由管理员在用户管理流程中设置。
   */
  enabled: boolean;
  /**
   * 是否为管理员账户，决定该用户是否拥有用户管理和系统配置的权限。
   */
  admin: boolean;
  /**
   * 头像图片的 data URL 或空字符串，用于在用户信息和聊天界面显示用户头像。
   */
  avatar: string;
  /**
   * 账户版本号，每次更新递增，用于会话失效检测，确保账户信息变更后旧会话无法继续使用。
   */
  accountVersion: number;
  /**
   * 最后更新时间戳（毫秒），用于记录用户信息的最近修改时间。
   */
  updatedAt: number;
}

/**
 * 描述用户和会话模块在运行时交换的数据结构。
 */
export interface UserViewModel {
  /**
   * 用户唯一标识，用于前端用户卡片展示和后续 API 查询参数传递。
   */
  handle: string;
  /**
   * 名称，用于聊天界面和用户列表中的显示标签。
   */
  name: string;
  /**
   * 头像图片的 data URL 或默认路径，用于 UI 层显示用户头像。
   */
  avatar: string;
  /**
   * 是否为管理员（仅在管理员视野中为 true），用于控制管理功能入口的可见性。
   */
  admin: boolean;
  /**
   * 用户是否设置了密码，仅反映是否存在密码，用于前端展示账户安全状态。
   */
  password: boolean;
  /**
   * 账户是否启用（仅在管理员视野中暴露真实值），用于用户管理界面的状态标识。
   */
  enabled: boolean;
  /**
   * 账户创建时间戳（毫秒），用于用户列表创建时间排序和展示。
   */
  created: number;
}

/**
 * 描述用户和会话模块在运行时交换的数据结构。
 */
export interface UserDirectoryList {
  /**
   * 规范化后的用户数据根路径，所有其他目录以此为基准拼接，用于文件存储的统一挂载点。
   */
  root: string;
  /**
   * 缩略图目录路径，用于存储角色和用户头像的缩放版本。
   */
  thumbnails: string;
  /**
   * 背景图缩略图目录路径，用于存储聊天背景的缩略图。
   */
  thumbnailsBg: string;
  /**
   * 头像缩略图目录路径，用于存储用户头像的小尺寸预览。
   */
  thumbnailsAvatar: string;
  /**
   * 角色头像缩略图目录路径，用于存储角色头像的小尺寸预览。
   */
  thumbnailsPersona: string;
  /**
   * 世界书目录路径，用于存储该用户的世界书数据文件。
   */
  worlds: string;
  /**
   * 用户个人信息目录路径，用于存储用户的个人配置数据。
   */
  user: string;
  /**
   * 用户头像目录路径，用于存储用户上传的头像图片文件。
   */
  avatars: string;
  /**
   * 用户图片目录路径，用于存储用户上传的一般性图片文件。
   */
  userImages: string;
  /**
   * 群组目录路径，用于存储群组相关数据。
   */
  groups: string;
  /**
   * 群聊目录路径，用于存储群聊会话记录。
   */
  groupChats: string;
  /**
   * 聊天记录目录路径，用于存储用户参与的私聊或群聊历史。
   */
  chats: string;
  /**
   * 角色数据目录路径，用于存储用户创建或导入的角色卡片数据。
   */
  characters: string;
  /**
   * 聊天背景目录路径，用于存储用户上传的聊天背景图片。
   */
  backgrounds: string;
  /**
   * NovelAI 设置文件目录路径，用于存储 NovelAI 服务提供商的配置参数。
   */
  novelAI_Settings: string;
  /**
   * KoboldAI 设置文件目录路径，用于存储 KoboldAI 服务提供商的配置参数。
   */
  koboldAI_Settings: string;
  /**
   * OpenAI 设置文件目录路径，用于存储 OpenAI 兼容服务提供商的配置参数。
   */
  openAI_Settings: string;
  /**
   * TextGen 设置文件目录路径，用于存储 Text Generation WebUI 的配置参数。
   */
  textGen_Settings: string;
  /**
   * 主题配置文件目录路径，用于存储用户自定义的 UI 主题。
   */
  themes: string;
  /**
   * 自定义 UI 布局配置目录路径，用于存储用户自定义的界面布局。
   */
  movingUI: string;
  /**
   * 扩展插件目录路径，用于存储用户安装的插件数据。
   */
  extensions: string;
  /**
   * 指令配置文件目录路径，用于存储角色指令模板和系统行为配置。
   */
  instruct: string;
  /**
   * 上下文配置文件目录路径，用于存储上下文管理和提示词模板配置。
   */
  context: string;
  /**
   * 快捷回复配置目录路径，用于存储用户预设的快捷回复模板。
   */
  quickreplies: string;
  /**
   * 静态资源目录路径，用于存储应用运行所需的静态资源文件。
   */
  assets: string;
  /**
   * ComfyUI 工作流配置目录路径，用于存储 ComfyUI 图像生成工作流配置。
   */
  comfyWorkflows: string;
  /**
   * 文件存储适配器挂载点路径，用于文件系统的操作入口。
   */
  files: string;
  /**
   * 向量数据库目录路径，用于存储 RAG 和语义搜索的向量索引数据。
   */
  vectors: string;
  /**
   * 备份数据目录路径，用于存储用户数据的导出和备份文件。
   */
  backups: string;
  /**
   * 系统提示词配置目录路径，用于存储系统级别的提示词模板。
   */
  sysprompt: string;
  /**
   * 推理配置目录路径，用于存储模型推理相关的参数配置。
   */
  reasoning: string;
}

/**
 * 描述用户和会话持久化或内存索引中的一条记录。
 */
export interface UserSessionRecord {
  /**
   * 会话唯一标识，格式为 "session-N"，用于会话查询、校验和登出操作的依据。
   */
  id: string;
  /**
   * 会话关联的用户标识，用于确认会话归属和用户映射。
   */
  handle: string;
  /**
   * 登录时的账户版本快照，用于检测账户信息变更后会话失效，用户数据更新后旧会话将被吊销。
   */
  accountVersion: number;
  /**
   * 会话创建时间戳（毫秒），用于记录登录时间和会话生命周期统计。
   */
  createdAt: number;
  /**
   * 会话最后活动时间戳（毫秒），用于会话过期判断和活跃度追踪。
   */
  updatedAt: number;
}

/**
 * 描述用户和会话操作完成后返回给调用方的结果，由 login 方法生成并在后续认证流程中传递。
 */
export interface UserLoginResult {
  /**
   * 登录成功后的用户视图模型，用于 UI 层展示和权限判断。
   */
  user: UserViewModel;
  /**
   * 登录成功后的会话记录，用于后续 API 调用的身份凭证。
   */
  session: UserSessionRecord;
}

/**
 * 描述用户变更事件（创建、启用、禁用、更新、头像变更、密码变更）发布时携带的数据结构。
 */
export interface UserEventPayload {
  /**
   * 事件关联的用户视图模型，供订阅方在事件回调中获取用户变化后的最新状态。
   */
  user: UserViewModel;
}

/**
 * 描述用户删除事件发布时携带的数据结构，供订阅方在事件回调中执行后续清理操作。
 */
export interface UserDeletedPayload {
  /**
   * 被删除的用户标识，供订阅方识别被删除的目标用户。
   */
  handle: string;
  /**
   * 是否同时清理关联文件数据，订阅方根据此标记决定是否删除磁盘上的用户目录。
   */
  purge: boolean;
}

/**
 * 描述登录或登出事件发布时携带的数据结构，供订阅方在事件回调中获取会话状态变化。
 */
export interface UserSessionPayload {
  /**
   * 事件关联的会话记录，供订阅方获取会话的详细状态。
   */
  session: UserSessionRecord;
  /**
   * 事件关联的用户视图模型，供订阅方获取操作前后的用户信息。
   */
  user: UserViewModel;
}
