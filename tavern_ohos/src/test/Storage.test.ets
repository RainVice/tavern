import { describe, it, expect } from '@ohos/hypium';
import {
  InMemoryFileStore,
  JsonlStore,
  JsonStore,
  type TavernFileStore,
} from '../../Index';

/**
 * 描述单元测试模块在运行时交换的数据结构。
 */
interface DemoSettings {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 名称。
   */
  name: string;
  /**
   * extra 值，由当前实例内部维护。
   */
  extra: DemoSettingsExtra;
}

/**
 * 描述单元测试模块在运行时交换的数据结构。
 */
interface DemoSettingsExtra {
  /**
   * upstream 值，由当前实例内部维护。
   */
  upstream: string;
  /**
   * host 值，由当前实例内部维护。
   */
  host: string;
}

/**
 * 描述单元测试模块在运行时交换的数据结构。
 */
interface DemoMessage {
  /**
   * 标识。
   */
  id: string;
  /**
   * role 值，由当前实例内部维护。
   */
  role: string;
  /**
   * 文本内容。
   */
  text: string;
}

export default function storageUnitTest() {
  describe('storage foundation', () => {
    it('按实际写入路径创建父目录', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();

      await files.writeText('tavern-data/users/default/chats/chat-1/messages.jsonl', '{"text":"hello"}', false);

      expect(await files.exists('tavern-data')).assertTrue();
      expect(await files.exists('tavern-data/users')).assertTrue();
      expect(await files.exists('tavern-data/users/default')).assertTrue();
      expect(await files.exists('tavern-data/users/default/chats')).assertTrue();
      expect(await files.exists('tavern-data/users/default/chats/chat-1')).assertTrue();
      expect(await files.exists('tavern-data/users/default/chats/chat-1/messages.jsonl')).assertTrue();
      expect(await files.exists('tavern-data/users/default/worldbooks')).assertFalse();
      expect(await files.exists('tavern-data/users/default/assets/thumbnails')).assertFalse();
    });

    it('重复写入同一路径时复用已存在父目录', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const path = 'tavern-data/users/default/connection-profiles/index.json';

      await files.writeText(path, '{"schemaVersion":1}', true);
      await files.writeText(path, '{"schemaVersion":2}', true);

      expect(await files.readText(path)).assertEqual('{"schemaVersion":2}');
      expect(await files.exists('tavern-data/users/default/connection-profiles')).assertTrue();
    });

    it('列出文件路径时返回空列表', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const path = 'tavern-data/users/default/characters/char-1/avatar.png';

      await files.writeText(path, 'avatar', false);
      const children = await files.list(path);

      expect(children.length).assertEqual(0);
    });

    it('reads a JSON default and preserves explicit fields after write', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const store = new JsonStore<DemoSettings>(files, 'tavern-data/app/settings.json');
      const defaultSettings: DemoSettings = {
        schemaVersion: 1,
        name: 'default',
        extra: {
          upstream: 'kept',
          host: '',
        },
      };
      const missing = await store.read(defaultSettings);
      const settingsToWrite: DemoSettings = {
        schemaVersion: 2,
        name: 'custom',
        extra: {
          upstream: missing.extra.upstream,
          host: 'ohos',
        },
      };
      await store.write(settingsToWrite);
      const saved = await store.read(defaultSettings);

      expect(saved.schemaVersion).assertEqual(2);
      expect(saved.name).assertEqual('custom');
      expect(saved.extra.upstream).assertEqual('kept');
      expect(saved.extra.host).assertEqual('ohos');
      expect(await files.exists('tavern-data/app/settings.json.bak')).assertTrue();
    });

    it('appends JSONL records, reads ranges, and compacts existing records', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const store = new JsonlStore<DemoMessage>(files, 'tavern-data/users/default/chats/chat-1/messages.jsonl');
      const message1: DemoMessage = { id: 'm1', role: 'user', text: 'hello' };
      const message2: DemoMessage = { id: 'm2', role: 'assistant', text: 'hi' };
      const message3: DemoMessage = { id: 'm3', role: 'user', text: 'continue' };
      const compactedMessage1: DemoMessage = { id: 'm1', role: 'user', text: 'hello edited' };
      const compactedMessage3: DemoMessage = { id: 'm3', role: 'user', text: 'continue' };

      await store.append(message1);
      await store.append(message2);
      await store.append(message3);
      const page = await store.readRange(1, 2);
      await store.compact([compactedMessage1, compactedMessage3]);
      const compacted = await store.readAll();

      expect(page.length).assertEqual(2);
      expect(page[0].id).assertEqual('m2');
      expect(page[1].id).assertEqual('m3');
      expect(compacted.length).assertEqual(2);
      expect(compacted[0].text).assertEqual('hello edited');
      expect(compacted[1].id).assertEqual('m3');
      expect(await files.exists('tavern-data/users/default/chats/chat-1/messages.jsonl.bak')).assertTrue();
    });

    it('不会把前置路径穿越别名折叠到已有文件', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();

      await files.writeText('tavern-data/users/default/profile.json', '{"user":"default"}', false);
      const directExists = await files.exists('tavern-data/users/default/profile.json');
      const aliasExists = await files.exists('../../tavern-data/users/default/profile.json');

      expect(directExists).assertTrue();
      expect(aliasExists).assertFalse();
    });
  });
}
