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
   * 按句柄索引的所有用户记录。
   */
  private users: Map<string, UserRecord> = new Map<string, UserRecord>();
  /**
   * 按会话 ID 索引的所有活跃会话记录。
   */
  private sessions: Map<string, UserSessionRecord> = new Map<string, UserSessionRecord>();
  /**
   * 用户密码盐值的自增计数器。
   */
  private saltCounter: number = 0;
  /**
   * 会话 ID 的自增计数器。
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
   * 创建新的用户记录，写入存储并返回副本。
   * @param params 创建用户的参数（handle、name、password、admin、enabled）。
   * @returns 新创建的用户记录副本。
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
   * 获取用户列表，可选择仅返回已启用的用户。
   * @param includeDisabled 是否包含已禁用的用户，默认 true。
   * @returns 用户记录副本数组，按创建时间升序排列。
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
   * 获取对外公开的用户视图模型列表（不含管理字段），用于登录页面展示可选用户。
   * @param discreetLogin 为 true 时不返回任何用户（模糊登录模式）。
   * @returns 用户视图模型数组。
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
   * 获取管理后台所需的完整用户视图模型列表（包含管理字段）。
   * @param adminHandle 发起请求的管理员句柄，用于鉴权。
   * @returns 用户视图模型数组。
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
   * 根据句柄获取指定用户记录的副本。
   * @param handle 用户句柄。
   * @returns 用户记录副本。
   */
  getUser(handle: string): UserRecord {
    return this.cloneUser(this.requireUser(handle));
  }

  /**
   * 获取指定用户的对外视图模型。
   * @param handle 用户句柄。
   * @param includeAdminFields 是否包含 admin、enabled 等管理字段。
   * @returns 用户视图模型。
   */
  getViewModel(handle: string, includeAdminFields: boolean = true): UserViewModel {
    return this.toViewModel(this.requireUser(handle), includeAdminFields);
  }

  /**
   * 启用指定用户。
   * @param adminHandle 发起操作的管理员句柄。
   * @param handle 目标用户句柄。
   * @returns 更新后的用户记录副本。
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
   * 禁用指定用户，同时吊销该用户的所有活跃会话。
   * @param adminHandle 发起操作的管理员句柄。
   * @param handle 目标用户句柄。
   * @returns 更新后的用户记录副本。
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
   * 将指定用户提升为管理员。
   * @param adminHandle 发起操作的管理员句柄。
   * @param handle 目标用户句柄。
   * @returns 更新后的用户记录副本。
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
   * 撤销指定用户的管理员权限。
   * @param adminHandle 发起操作的管理员句柄。
   * @param handle 目标用户句柄。
   * @returns 更新后的用户记录副本。
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
   * 删除指定用户及其关联的所有活跃会话。禁止删除 default-user 或删除自己。
   * @param adminHandle 发起操作的管理员句柄。
   * @param handle 目标用户句柄。
   * @param purge 是否同时清除用户的持久化数据。
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
   * 修改指定用户的显示名称。
   * @param actorHandle 发起操作的用户句柄（需为本人或管理员）。
   * @param handle 目标用户句柄。
   * @param name 新的显示名称。
   * @returns 更新后的用户记录副本。
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
   * 修改指定用户的头像。
   * @param actorHandle 发起操作的用户句柄（需为本人或管理员）。
   * @param handle 目标用户句柄。
   * @param avatar 头像的 base64 数据 URL（格式 "data:image/..."）。
   * @returns 更新后的用户记录副本。
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
   * 修改指定用户的登录密码。
   * @param actorHandle 发起操作的用户句柄。
   * @param handle 目标用户句柄。
   * @param oldPassword 旧密码（管理员可为空跳过校验）。
   * @param newPassword 新密码（为空表示清除密码）。
   * @returns 更新后的用户记录副本。
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
   * 用户登录。验证凭据后创建会话记录并发布 user.logged_in 事件。
   * @param handle 用户句柄。
   * @param password 登录密码。
   * @returns 包含用户视图模型和会话记录的登录结果。
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
   * 用户登出。删除指定会话记录并发布 user.logged_out 事件。
   * @param sessionId 待销毁的会话 ID。
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
   * 校验指定会话是否仍然有效。如用户被禁用或账号版本变更，则标记会话过期并抛出错误。
   * @param sessionId 待校验的会话 ID。
   * @returns 关联用户的视图模型。
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
   * 获取所有活跃会话的副本列表。
   * @returns 会话记录副本数组。
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
   * 获取指定用户的目录结构映射，每个字段对应用户文件系统下的子目录路径。
   * @param handle 用户句柄。
   * @returns 目录路径映射表。
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
   * 将文本转换为 URL 友好的句柄（小写字母、数字、连字符）。
   * @param text 原始文本。
   * @returns 规范化后的句柄字符串。
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
   * 校验发起操作的用户是否为目标用户本人或管理员，否则抛出错误。
   * @param actorHandle 发起操作的用户句柄。
   * @param handle 目标用户句柄。
   */
  private requireOwnerOrAdmin(actorHandle: string, handle: string): void {
    const actor = this.requireUser(actorHandle);
    if (actor.handle !== this.slugify(handle) && !actor.admin) {
      throw new Error('Unauthorized');
    }
  }

  /**
   * 校验指定用户是否为活跃的管理员，否则抛出错误。
   * @param handle 用户句柄。
   * @returns 用户记录引用。
   */
  private requireAdmin(handle: string): UserRecord {
    const user = this.requireUser(handle);
    if (!user.admin || !user.enabled) {
      throw new Error('Admin user required');
    }
    return user;
  }

  /**
   * 按句柄获取用户记录，不存在时抛出错误。
   * @param handle 用户句柄。
   * @returns 内部存储的用户记录引用。
   */
  private requireUser(handle: string): UserRecord {
    const user = this.users.get(this.slugify(handle));
    if (user === undefined) {
      throw new Error(`User not found: ${handle}`);
    }
    return user;
  }

  /**
   * 校验用户密码是否匹配。
   * @param user 用户记录。
   * @param password 待验证的明文密码。
   * @returns 密码匹配返回 true，否则 false。
   */
  private verifyPassword(user: UserRecord, password: string): boolean {
    if (user.passwordHash.length === 0) {
      return password.length === 0;
    }
    return user.passwordHash === this.hashPassword(password, user.salt);
  }

  /**
   * 使用 FNV-1a 哈希算法计算密码的哈希值，格式为 "salt:hash"。
   * @param password 明文密码。
   * @param salt 盐值。
   * @returns 密码哈希字符串。
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
   * 将用户内部记录转换为对外暴露的视图模型。
   * @param user 用户记录。
   * @param includeAdminFields 是否包含管理字段（admin、enabled 等）。
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
   * 深拷贝用户记录，避免外部修改内部状态。
   * @param user 原始用户记录。
   * @returns 独立副本。
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
   * 深拷贝会话记录，避免外部修改内部状态。
   * @param session 原始会话记录。
   * @returns 独立副本。
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
   * 发布用户相关事件，将状态变化通知给宿主或其他 Runtime 模块。
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
