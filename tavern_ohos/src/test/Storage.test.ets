import { describe, it, expect } from '@ohos/hypium';
import {
  InMemoryFileStore,
  JsonlStore,
  JsonStore,
  type TavernFileStore,
} from '../../Index';

interface DemoSettings {
  schemaVersion: number;
  name: string;
  extra: DemoSettingsExtra;
}

interface DemoSettingsExtra {
  upstream: string;
  host: string;
}

interface DemoMessage {
  id: string;
  role: string;
  text: string;
}

export default function storageUnitTest() {
  describe('storage foundation', () => {
    it('creates required tavern data directories', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();

      await files.ensureTavernDataLayout('tavern-data');

      expect(await files.exists('tavern-data/app')).assertTrue();
      expect(await files.exists('tavern-data/app/manifest.json')).assertTrue();
      expect(await files.exists('tavern-data/app/settings.json')).assertTrue();
      expect(await files.exists('tavern-data/app/runtime-state.json')).assertTrue();
      expect(await files.exists('tavern-data/users/default/profile.json')).assertTrue();
      expect(await files.exists('tavern-data/users/default/settings.json')).assertTrue();
      expect(await files.exists('tavern-data/users/default/chats')).assertTrue();
      expect(await files.exists('tavern-data/users/default/characters')).assertTrue();
      expect(await files.exists('tavern-data/users/default/worldbooks')).assertTrue();
      expect(await files.exists('tavern-data/users/default/assets/thumbnails')).assertTrue();
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
