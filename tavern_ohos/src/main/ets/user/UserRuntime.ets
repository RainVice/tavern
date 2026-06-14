import { EventBus } from '../runtime/EventBus';
import type {
  UserCreateParams,
  UserDeletedPayload,
  UserDirectoryList,
  UserEventPayload,
  UserLoginResult,
  UserRecord,
  UserSessionPayload,
  UserSessionRecord,
  UserViewModel,
} from './UserModels';

/**
 * 提供用户和会话相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class UserRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 所有已注册用户的映射表，key 为 slugify 后的 handle。
   */
  private users: Map<string, UserRecord> = new Map<string, UserRecord>();
  /**
   * 当前有效会话的映射表，key 为会话 ID。
   */
  private sessions: Map<string, UserSessionRecord> = new Map<string, UserSessionRecord>();
  /**
   * 盐值计数器，用于生成唯一的密码加盐字符串。
   */
  private saltCounter: number = 0;
  /**
   * 会话 ID 计数器，用于生成递增的会话编号。
   */
  private sessionCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的用户记录，写入存储并返回副本。在用户注册或管理员新增用户时调用。
   * @param params 创建用户所需的参数，包含 handle、name、password、admin、enabled 等信息，用于构造完整的 UserRecord。
   * @returns 新建用户记录的深拷贝，用于后续操作或返回给调用方。
   */
  createUser(params: UserCreateParams): UserRecord {
    const handle = this.slugify(params.handle);
    if (handle.length === 0) {
      throw new Error('Invalid user handle');
    }
    if (this.users.has(handle)) {
      throw new Error(`User already exists: ${handle}`);
    }
    const now = Date.now();
    const password = params.password === undefined ? '' : params.password;
    const salt = password.length === 0 ? '' : this.nextSalt();
    const record: UserRecord = {
      handle: handle,
      name: params.name.length === 0 ? 'Anonymous' : params.name,
      created: now,
      passwordHash: password.length === 0 ? '' : this.hashPassword(password, salt),
      salt: salt,
      enabled: params.enabled === undefined ? true : params.enabled,
      admin: params.admin === undefined ? false : params.admin,
      avatar: '',
      accountVersion: 1,
      updatedAt: now,
    };
    this.users.set(record.handle, record);
    this.publishUser('user.created', record);
    return this.cloneUser(record);
  }

  /**
   * 读取所有已注册用户列表，可选择是否包含已禁用的用户。在用户管理页面和管理员操作时调用。
   * @param includeDisabled 是否包含已禁用的用户，默认 true，用于控制管理视图 vs 公开视图的过滤范围。
   * @returns 符合条件的用户记录副本列表，按创建时间升序排列，供 UI 层遍历展示。
   */
  listUsers(includeDisabled: boolean = true): Array<UserRecord> {
    const records = Array.from(this.users.values());
    const result = new Array<UserRecord>();
    for (let index = 0; index < records.length; index += 1) {
      if (includeDisabled || records[index].enabled) {
        result.push(this.cloneUser(records[index]));
      }
    }
    result.sort((left: UserRecord, right: UserRecord) => left.created - right.created);
    return result;
  }

  /**
   * 读取公开用户列表（仅返回启用的用户，不含管理员敏感字段）。在登录页面选择用户时调用。
   * @param discreetLogin 是否启用隐蔽登录模式；为 true 时返回空列表，用于隐私场景下隐藏所有用户。
   * @returns 公开用户视图模型列表，不含密码状态和禁用标记，供登录页 UI 展示可选用户。
   */
  listPublicUsers(discreetLogin: boolean): Array<UserViewModel> {
    if (discreetLogin) {
      return new Array<UserViewModel>();
    }
    const records = this.listUsers(false);
    const result = new Array<UserViewModel>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.toViewModel(records[index], false));
    }
    return result;
  }

  /**
   * 读取包含管理员字段的完整用户列表，需验证调用者具有管理员权限。在管理员用户管理页面调用。
   * @param adminHandle 发起请求的管理员用户标识，用于权限校验。
   * @returns 所有用户的完整视图模型列表（含密码状态、启用标记等管理员字段），供管理界面展示。
   */
  listAdminUsers(adminHandle: string): Array<UserViewModel> {
    this.requireAdmin(adminHandle);
    const records = this.listUsers(true);
    const result = new Array<UserViewModel>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.toViewModel(records[index], true));
    }
    return result;
  }

  /**
   * 根据 handle 读取指定用户的完整记录。在需要获取用户全部字段（含敏感字段）的操作中调用。
   * @param handle 目标用户标识，供查询使用。
   * @returns 用户记录深拷贝，供后续修改或权限判断使用。
   */
  getUser(handle: string): UserRecord {
    return this.cloneUser(this.requireUser(handle));
  }

  /**
   * 根据 handle 获取指定用户的视图模型，可选择是否包含管理员敏感字段。在 UI 层展示用户信息时调用。
   * @param handle 目标用户标识，用于查询用户记录。
   * @param includeAdminFields 是否返回管理员字段（admin、enabled、password 状态），控制 API 响应中敏感信息的暴露范围。
   * @returns 用户视图模型，供 UI 层渲染用户卡片或列表。
   */
  getViewModel(handle: string, includeAdminFields: boolean = true): UserViewModel {
    return this.toViewModel(this.requireUser(handle), includeAdminFields);
  }

  /**
   * 启用指定用户账户，仅管理员可操作。在管理员用户管理页面点击启用时调用。
   * @param adminHandle 执行操作的管理员用户标识，用于权限校验。
   * @param handle 目标用户标识，指定要启用的用户。
   * @returns 更新后的用户记录深拷贝，用于刷新 UI。
   */
  enableUser(adminHandle: string, handle: string): UserRecord {
    this.requireAdmin(adminHandle);
    const user = this.requireUser(handle);
    user.enabled = true;
    this.bump(user);
    this.publishUser('user.enabled', user);
    return this.cloneUser(user);
  }

  /**
   * 禁用指定用户账户，同时吊销该用户的所有会话。不允许管理员禁用自己。在管理员用户管理页面点击禁用时调用。
   * @param adminHandle 执行操作的管理员用户标识，用于权限校验。
   * @param handle 目标用户标识，指定要禁用的用户。
   * @returns 更新后的用户记录深拷贝，用于刷新 UI。
   */
  disableUser(adminHandle: string, handle: string): UserRecord {
    this.requireAdmin(adminHandle);
    const normalizedHandle = this.slugify(handle);
    if (this.slugify(adminHandle) === normalizedHandle) {
      throw new Error('Cannot disable yourself');
    }
    const user = this.requireUser(normalizedHandle);
    user.enabled = false;
    this.bump(user);
    this.dropSessionsForUser(user.handle);
    this.publishUser('user.disabled', user);
    return this.cloneUser(user);
  }

  /**
   * 将指定用户提升为管理员，仅管理员可操作。在管理员用户管理页面授予管理员权限时调用。
   * @param adminHandle 执行操作的管理员用户标识，用于权限校验。
   * @param handle 目标用户标识，指定要提升的用户。
   * @returns 更新后的用户记录深拷贝，用于刷新 UI。
   */
  promoteUser(adminHandle: string, handle: string): UserRecord {
    this.requireAdmin(adminHandle);
    const user = this.requireUser(handle);
    user.admin = true;
    this.bump(user);
    this.publishUser('user.updated', user);
    return this.cloneUser(user);
  }

  /**
   * 取消指定用户的管理员权限。不允许管理员取消自己的权限。在管理员用户管理页面撤销管理员权限时调用。
   * @param adminHandle 执行操作的管理员用户标识，用于权限校验。
   * @param handle 目标用户标识，指定要降级的用户。
   * @returns 更新后的用户记录深拷贝，用于刷新 UI。
   */
  demoteUser(adminHandle: string, handle: string): UserRecord {
    this.requireAdmin(adminHandle);
    if (this.slugify(adminHandle) === this.slugify(handle)) {
      throw new Error('Cannot demote yourself');
    }
    const user = this.requireUser(handle);
    user.admin = false;
    this.bump(user);
    this.publishUser('user.updated', user);
    return this.cloneUser(user);
  }

  /**
   * 删除指定用户及其关联会话。不允许删除自己或 default-user。在管理员用户管理页面删除用户时调用。
   * @param adminHandle 执行操作的管理员用户标识，用于权限校验。
   * @param handle 目标用户标识，指定要删除的用户。
   * @param purge 是否同时清理关联的文件数据，控制是否清除磁盘上的用户数据目录。
   */
  deleteUser(adminHandle: string, handle: string, purge: boolean = false): void {
    this.requireAdmin(adminHandle);
    const normalizedHandle = this.slugify(handle);
    if (this.slugify(adminHandle) === normalizedHandle) {
      throw new Error('Cannot delete yourself');
    }
    if (normalizedHandle === 'default-user') {
      throw new Error('Cannot delete default user');
    }
    const user = this.requireUser(normalizedHandle);
    this.users.delete(user.handle);
    this.dropSessionsForUser(user.handle);
    const payload: UserDeletedPayload = {
      handle: user.handle,
      purge: purge,
    };
    this.events.publish<UserDeletedPayload>('user.deleted', payload);
  }

  /**
   * 修改指定用户的显示名称。操作者必须是用户本人或管理员。在用户资料编辑页面调用。
   * @param actorHandle 发起操作的用户标识，用于权限校验。
   * @param handle 目标用户标识，指定要修改名称的用户。
   * @param name 新的显示名称，用于更新用户显示的标签。
   * @returns 更新后的用户记录深拷贝，用于刷新 UI。
   */
  changeName(actorHandle: string, handle: string, name: string): UserRecord {
    this.requireOwnerOrAdmin(actorHandle, handle);
    if (name.length === 0) {
      throw new Error('Name is required');
    }
    const user = this.requireUser(handle);
    user.name = name;
    this.bump(user);
    this.publishUser('user.updated', user);
    return this.cloneUser(user);
  }

  /**
   * 修改指定用户的头像。操作者必须是用户本人或管理员。在用户资料编辑页面上传头像时调用。
   * @param actorHandle 发起操作的用户标识，用于权限校验。
   * @param handle 目标用户标识，指定要修改头像的用户。
   * @param avatar 新的头像 data URL，用于更新用户头像显示。
   * @returns 更新后的用户记录深拷贝，用于刷新 UI。
   */
  changeAvatar(actorHandle: string, handle: string, avatar: string): UserRecord {
    this.requireOwnerOrAdmin(actorHandle, handle);
    if (avatar.length > 0 && !avatar.startsWith('data:image/')) {
      throw new Error('Invalid avatar data URL');
    }
    const user = this.requireUser(handle);
    user.avatar = avatar;
    this.bump(user);
    this.publishUser('user.avatar.changed', user);
    this.publishUser('user.updated', user);
    return this.cloneUser(user);
  }

  /**
   * 修改指定用户的密码。操作者必须提供旧密码（除非是管理员代改）。在用户设置或管理员重置密码时调用。
   * @param actorHandle 发起操作的用户标识，用于权限校验。
   * @param handle 目标用户标识，指定要修改密码的用户。
   * @param oldPassword 旧密码（管理员代改时不需要匹配），用于验证操作者身份。
   * @param newPassword 新密码，为空字符串则清除密码，用于设置新的账户凭证。
   * @returns 更新后的用户记录深拷贝，用于刷新 UI。
   */
  changePassword(actorHandle: string, handle: string, oldPassword: string, newPassword: string): UserRecord {
    const actor = this.requireUser(actorHandle);
    const user = this.requireUser(handle);
    if (actor.handle !== user.handle && !actor.admin) {
      throw new Error('Unauthorized');
    }
    if (!actor.admin && !this.verifyPassword(user, oldPassword)) {
      throw new Error('Incorrect password');
    }
    if (newPassword.length === 0) {
      user.passwordHash = '';
      user.salt = '';
    } else {
      user.salt = this.nextSalt();
      user.passwordHash = this.hashPassword(newPassword, user.salt);
    }
    this.bump(user);
    this.publishUser('user.password.changed', user);
    this.publishUser('user.updated', user);
    return this.cloneUser(user);
  }

  /**
   * 用户登录：验证凭证后创建会话并返回登录结果。在用户登录页面提交登录表单时调用。
   * @param handle 用户标识，用于查找用户记录和验证身份。
   * @param password 用户密码，用于与存储的哈希值比对验证。
   * @returns 登录结果，包含用户视图模型和新创建的会话记录，供前端保存登录状态。
   */
  login(handle: string, password: string): UserLoginResult {
    const user = this.requireUser(handle);
    if (!user.enabled) {
      throw new Error('User is disabled');
    }
    if (!this.verifyPassword(user, password)) {
      throw new Error('Incorrect credentials');
    }
    this.sessionCounter += 1;
    const now = Date.now();
    const session: UserSessionRecord = {
      id: `session-${this.sessionCounter}`,
      handle: user.handle,
      accountVersion: user.accountVersion,
      createdAt: now,
      updatedAt: now,
    };
    this.sessions.set(session.id, session);
    const result: UserLoginResult = {
      user: this.toViewModel(user, true),
      session: this.cloneSession(session),
    };
    const payload: UserSessionPayload = {
      session: result.session,
      user: result.user,
    };
    this.events.publish<UserSessionPayload>('user.logged_in', payload);
    return result;
  }

  /**
   * 用户登出：销毁指定会话并发布登出事件。在用户退出登录时调用。
   * @param sessionId 目标会话标识，指定要销毁的会话。
   */
  logout(sessionId: string): void {
    const session = this.sessions.get(sessionId);
    if (session === undefined) {
      return;
    }
    const user = this.requireUser(session.handle);
    this.sessions.delete(sessionId);
    const payload: UserSessionPayload = {
      session: this.cloneSession(session),
      user: this.toViewModel(user, true),
    };
    this.events.publish<UserSessionPayload>('user.logged_out', payload);
  }

  /**
   * 校验会话是否有效：检查用户是否仍启用以及账户版本是否一致。在每次需要验证用户权限的 API 调用前执行。
   * @param sessionId 目标会话标识，用于查找会话和验证状态。
   * @returns 校验通过后的用户视图模型，供调用方确认用户身份和权限。
   */
  validateSession(sessionId: string): UserViewModel {
    const session = this.sessions.get(sessionId);
    if (session === undefined) {
      throw new Error(`Session not found: ${sessionId}`);
    }
    const user = this.requireUser(session.handle);
    if (!user.enabled || user.accountVersion !== session.accountVersion) {
      this.sessions.delete(sessionId);
      throw new Error('Session expired');
    }
    session.updatedAt = Date.now();
    return this.toViewModel(user, true);
  }

  /**
   * 读取当前所有有效会话的副本列表。在会话管理页面或监控接口中调用。
   * @returns 所有会话记录的深拷贝数组，供 UI 展示活跃会话列表。
   */
  listSessions(): Array<UserSessionRecord> {
    const records = Array.from(this.sessions.values());
    const result = new Array<UserSessionRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.cloneSession(records[index]));
    }
    return result;
  }

  /**
   * 获取指定用户的数据目录映射表，包含各类子目录的相对路径。在文件操作和存储初始化时调用。
   * @param handle 用户标识，用于生成以 handle 为基准的用户数据根路径。
   * @returns 用户目录结构描述，每个字段对应一种数据的存放路径，供文件存储适配器写入各类型数据。
   */
  getUserDirectories(handle: string): UserDirectoryList {
    const root = `users/${this.slugify(handle)}`;
    return {
      root: root,
      thumbnails: `${root}/thumbnails`,
      thumbnailsBg: `${root}/thumbnails/bg`,
      thumbnailsAvatar: `${root}/thumbnails/avatar`,
      thumbnailsPersona: `${root}/thumbnails/persona`,
      worlds: `${root}/worlds`,
      user: `${root}/user`,
      avatars: `${root}/avatars`,
      userImages: `${root}/images`,
      groups: `${root}/groups`,
      groupChats: `${root}/group-chats`,
      chats: `${root}/chats`,
      characters: `${root}/characters`,
      backgrounds: `${root}/backgrounds`,
      novelAI_Settings: `${root}/NovelAI Settings`,
      koboldAI_Settings: `${root}/KoboldAI Settings`,
      openAI_Settings: `${root}/OpenAI Settings`,
      textGen_Settings: `${root}/TextGen Settings`,
      themes: `${root}/themes`,
      movingUI: `${root}/moving-ui`,
      extensions: `${root}/extensions`,
      instruct: `${root}/instruct`,
      context: `${root}/context`,
      quickreplies: `${root}/quick-replies`,
      assets: `${root}/assets`,
      comfyWorkflows: `${root}/comfy-workflows`,
      files: `${root}/files`,
      vectors: `${root}/vectors`,
      backups: `${root}/backups`,
      sysprompt: `${root}/sysprompt`,
      reasoning: `${root}/reasoning`,
    };
  }

  /**
   * 将文本转换为 URL 友好的 slug 格式：只保留小写字母和数字，其余字符转换为连字符。在用户创建和 handle 规范化时调用。
   * @param text 原始文本，通常是用户输入的 handle 字符串。
   * @returns 规范化后的 slug 字符串，用作内部用户唯一标识。
   */
  slugify(text: string): string {
    const lower = text.toLowerCase().trim();
    let result = '';
    let previousDash = false;
    for (let index = 0; index < lower.length; index += 1) {
      const code = lower.charCodeAt(index);
      const valid = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
      if (valid) {
        result += lower[index];
        previousDash = false;
      } else if (!previousDash && result.length > 0) {
        result += '-';
        previousDash = true;
      }
    }
    if (result.endsWith('-')) {
      return result.substring(0, result.length - 1);
    }
    return result;
  }

  /**
   * 校验操作者是指定用户本人或管理员，否则抛出权限异常。
   * @param actorHandle 发起操作的用户标识。
   * @param handle 被操作的用户标识。
   */
  private requireOwnerOrAdmin(actorHandle: string, handle: string): void {
    const actor = this.requireUser(actorHandle);
    if (actor.handle !== this.slugify(handle) && !actor.admin) {
      throw new Error('Unauthorized');
    }
  }

  /**
   * 校验指定用户是否为已启用的管理员，否则抛出权限异常。
   * @param handle 用户标识。
   * @returns 用户记录。
   */
  private requireAdmin(handle: string): UserRecord {
    const user = this.requireUser(handle);
    if (!user.admin || !user.enabled) {
      throw new Error('Admin user required');
    }
    return user;
  }

  /**
   * 根据 handle 查找用户，不存在时抛出异常。
   * @param handle 用户标识。
   * @returns 用户记录（引用，非副本）。
   */
  private requireUser(handle: string): UserRecord {
    const user = this.users.get(this.slugify(handle));
    if (user === undefined) {
      throw new Error(`User not found: ${handle}`);
    }
    return user;
  }

  /**
   * 校验用户密码是否匹配存储的哈希值。
   * @param user 用户记录。
   * @param password 待验证的密码。
   * @returns 密码校验通过返回 true，否则返回 false。
   */
  private verifyPassword(user: UserRecord, password: string): boolean {
    if (user.passwordHash.length === 0) {
      return password.length === 0;
    }
    return user.passwordHash === this.hashPassword(password, user.salt);
  }

  /**
   * 使用 FNV-1a 哈希算法对密码加盐后计算哈希值。
   * @param password 原始密码。
   * @param salt 加盐字符串。
   * @returns 格式为 "salt:hash" 的哈希结果。
   */
  private hashPassword(password: string, salt: string): string {
    let hash = 2166136261;
    const value = `${salt}:${password}`;
    for (let index = 0; index < value.length; index += 1) {
      hash = (hash ^ value.charCodeAt(index)) * 16777619;
    }
    return `${salt}:${hash}`;
  }
  private nextSalt(): string {
    this.saltCounter += 1;
    return `salt-${this.saltCounter}`;
  }
  private bump(user: UserRecord): void {
    user.updatedAt = Date.now();
    user.accountVersion += 1;
  }

  /**
   * 吊销指定用户的所有会话，用于禁用或删除用户时清理。
   * @param handle 用户标识。
   */
  private dropSessionsForUser(handle: string): void {
    const keys = Array.from(this.sessions.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const session = this.sessions.get(keys[index]);
      if (session !== undefined && session.handle === handle) {
        this.sessions.delete(keys[index]);
      }
    }
  }

  /**
   * 把用户记录转换为界面可展示的视图模型，按权限控制敏感字段的暴露。
   * @param user 用户记录。
   * @param includeAdminFields 是否包含管理员敏感字段。
   * @returns 用户视图模型。
   */
  private toViewModel(user: UserRecord, includeAdminFields: boolean): UserViewModel {
    return {
      handle: user.handle,
      name: user.name,
      avatar: user.avatar.length === 0 ? '/img/default-user.png' : user.avatar,
      admin: includeAdminFields ? user.admin : false,
      password: user.passwordHash.length > 0,
      enabled: includeAdminFields ? user.enabled : true,
      created: user.created,
    };
  }

  /**
   * 深拷贝用户记录，防止外部修改内部状态。
   * @param user 用户记录。
   * @returns 用户记录深拷贝。
   */
  private cloneUser(user: UserRecord): UserRecord {
    return {
      handle: user.handle,
      name: user.name,
      created: user.created,
      passwordHash: user.passwordHash,
      salt: user.salt,
      enabled: user.enabled,
      admin: user.admin,
      avatar: user.avatar,
      accountVersion: user.accountVersion,
      updatedAt: user.updatedAt,
    };
  }

  /**
   * 深拷贝会话记录，防止外部修改内部状态。
   * @param session 会话记录。
   * @returns 会话记录深拷贝。
   */
  private cloneSession(session: UserSessionRecord): UserSessionRecord {
    return {
      id: session.id,
      handle: session.handle,
      accountVersion: session.accountVersion,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    };
  }

  /**
   * 发布用户和会话事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 事件名称。
   * @param user 关联的用户记录。
   */
  private publishUser(eventName: string, user: UserRecord): void {
    const payload: UserEventPayload = {
      user: this.toViewModel(user, true),
    };
    this.events.publish<UserEventPayload>(eventName, payload);
  }
}
