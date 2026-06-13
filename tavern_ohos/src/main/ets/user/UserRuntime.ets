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

export class UserRuntime {
  private events: EventBus;
  private users: Map<string, UserRecord> = new Map<string, UserRecord>();
  private sessions: Map<string, UserSessionRecord> = new Map<string, UserSessionRecord>();
  private saltCounter: number = 0;
  private sessionCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

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

  listAdminUsers(adminHandle: string): Array<UserViewModel> {
    this.requireAdmin(adminHandle);
    const records = this.listUsers(true);
    const result = new Array<UserViewModel>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.toViewModel(records[index], true));
    }
    return result;
  }

  getUser(handle: string): UserRecord {
    return this.cloneUser(this.requireUser(handle));
  }

  getViewModel(handle: string, includeAdminFields: boolean = true): UserViewModel {
    return this.toViewModel(this.requireUser(handle), includeAdminFields);
  }

  enableUser(adminHandle: string, handle: string): UserRecord {
    this.requireAdmin(adminHandle);
    const user = this.requireUser(handle);
    user.enabled = true;
    this.bump(user);
    this.publishUser('user.enabled', user);
    return this.cloneUser(user);
  }

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

  promoteUser(adminHandle: string, handle: string): UserRecord {
    this.requireAdmin(adminHandle);
    const user = this.requireUser(handle);
    user.admin = true;
    this.bump(user);
    this.publishUser('user.updated', user);
    return this.cloneUser(user);
  }

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

  listSessions(): Array<UserSessionRecord> {
    const records = Array.from(this.sessions.values());
    const result = new Array<UserSessionRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.cloneSession(records[index]));
    }
    return result;
  }

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

  private requireOwnerOrAdmin(actorHandle: string, handle: string): void {
    const actor = this.requireUser(actorHandle);
    if (actor.handle !== this.slugify(handle) && !actor.admin) {
      throw new Error('Unauthorized');
    }
  }

  private requireAdmin(handle: string): UserRecord {
    const user = this.requireUser(handle);
    if (!user.admin || !user.enabled) {
      throw new Error('Admin user required');
    }
    return user;
  }

  private requireUser(handle: string): UserRecord {
    const user = this.users.get(this.slugify(handle));
    if (user === undefined) {
      throw new Error(`User not found: ${handle}`);
    }
    return user;
  }

  private verifyPassword(user: UserRecord, password: string): boolean {
    if (user.passwordHash.length === 0) {
      return password.length === 0;
    }
    return user.passwordHash === this.hashPassword(password, user.salt);
  }

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

  private cloneSession(session: UserSessionRecord): UserSessionRecord {
    return {
      id: session.id,
      handle: session.handle,
      accountVersion: session.accountVersion,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    };
  }

  private publishUser(eventName: string, user: UserRecord): void {
    const payload: UserEventPayload = {
      user: this.toViewModel(user, true),
    };
    this.events.publish<UserEventPayload>(eventName, payload);
  }
}
