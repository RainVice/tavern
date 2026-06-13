import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  type RuntimeEvent,
} from '../../Index';
import {
  UserRuntime,
  type UserDirectoryList,
  type UserEventPayload,
  type UserLoginResult,
  type UserRecord,
  type UserViewModel,
} from '../main/ets/user/Index';

export default function userUnitTest() {
  describe('user runtime', () => {
    it('creates users, view models, and scoped directories', 0, () => {
      // 运行时实例。
      const runtime = new UserRuntime(new EventBus());
      const admin: UserRecord = runtime.createUser({
        handle: 'Admin User',
        name: 'Admin',
        password: 'root',
        admin: true,
      });
      const member: UserRecord = runtime.createUser({
        handle: 'Alice Smith!',
        name: 'Alice',
        password: '',
        admin: false,
      });
      const publicUsers: Array<UserViewModel> = runtime.listPublicUsers(false);
      const directories: UserDirectoryList = runtime.getUserDirectories(member.handle);

      expect(admin.handle).assertEqual('admin-user');
      expect(member.handle).assertEqual('alice-smith');
      expect(publicUsers.length).assertEqual(2);
      expect(publicUsers[1].handle).assertEqual('alice-smith');
      expect(publicUsers[1].password).assertFalse();
      expect(directories.root).assertEqual('users/alice-smith');
      expect(directories.characters).assertEqual('users/alice-smith/characters');
      expect(runtime.listPublicUsers(true).length).assertEqual(0);
    });

    it('applies admin user operations and publishes account events', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new UserRuntime(bus);
      const events = new Array<string>();
      bus.subscribe<UserEventPayload>('user.updated', (event: RuntimeEvent<UserEventPayload>) => {
        events.push(event.payload.user.handle);
      });

      runtime.createUser({
        handle: 'admin',
        name: 'Admin',
        password: 'root',
        admin: true,
      });
      runtime.createUser({
        handle: 'guest',
        name: 'Guest',
        password: '',
        admin: false,
      });

      runtime.promoteUser('admin', 'guest');
      runtime.changeName('guest', 'guest', 'Guest Renamed');
      runtime.changeAvatar('admin', 'guest', 'data:image/png;base64,AAAA');
      runtime.disableUser('admin', 'guest');
      const guest: UserViewModel = runtime.getViewModel('guest', true);

      expect(guest.admin).assertTrue();
      expect(guest.enabled).assertFalse();
      expect(guest.name).assertEqual('Guest Renamed');
      expect(guest.avatar).assertEqual('data:image/png;base64,AAAA');
      expect(events.length >= 3).assertTrue();
    });

    it('logs in, validates sessions, changes passwords, and logs out', 0, () => {
      // 运行时实例。
      const runtime = new UserRuntime(new EventBus());
      runtime.createUser({
        handle: 'admin',
        name: 'Admin',
        password: 'root',
        admin: true,
      });
      const login: UserLoginResult = runtime.login('admin', 'root');
      const validated: UserViewModel = runtime.validateSession(login.session.id);
      runtime.changePassword('admin', 'admin', 'root', 'new-root');
      runtime.logout(login.session.id);
      const secondLogin: UserLoginResult = runtime.login('admin', 'new-root');

      expect(login.user.handle).assertEqual('admin');
      expect(validated.handle).assertEqual('admin');
      expect(runtime.listSessions().length).assertEqual(1);
      expect(secondLogin.user.password).assertTrue();
    });

    it('normalizes handles for self protection deletion and passwordless login', 0, () => {
      // 运行时实例。
      const runtime = new UserRuntime(new EventBus());
      runtime.createUser({
        handle: 'Admin User',
        name: 'Admin',
        password: 'root',
        admin: true,
      });
      runtime.createUser({
        handle: 'Guest User',
        name: 'Guest',
        password: '',
        admin: false,
      });
      const guestLogin = runtime.login('guest-user', '');
      let passwordlessFailed = false;
      try {
        runtime.login('guest-user', 'not-empty');
      } catch (error) {
        passwordlessFailed = true;
      }
      let selfDisableFailed = false;
      try {
        runtime.disableUser('Admin User', 'admin-user');
      } catch (error) {
        selfDisableFailed = true;
      }

      runtime.deleteUser('Admin User', 'Guest User', true);
      const sessions = runtime.listSessions();

      expect(guestLogin.user.handle).assertEqual('guest-user');
      expect(passwordlessFailed).assertTrue();
      expect(selfDisableFailed).assertTrue();
      expect(sessions.length).assertEqual(0);
      expect(runtime.listUsers(true).length).assertEqual(1);
    });
  });
}
