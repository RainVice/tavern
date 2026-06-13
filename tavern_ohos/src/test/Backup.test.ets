import { describe, it, expect } from '@ohos/hypium';
import {
  BackupRuntime,
  EventBus,
  InMemoryFileStore,
  type BackupArchive,
  type BackupCompletedPayload,
  type BackupManifestEntry,
  type BackupRestoreResult,
  type BackupValidationResult,
  type RuntimeEvent,
  type TavernFileStore,
} from '../../Index';

export default function backupUnitTest() {
  describe('backup runtime', () => {
    it('creates full user data backups with manifest and validation', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new BackupRuntime(files, bus);
      const completed = new Array<string>();
      bus.subscribe<BackupCompletedPayload>('backup.completed', (event: RuntimeEvent<BackupCompletedPayload>) => {
        completed.push(`${event.payload.backupId}:${event.payload.path}:${event.payload.archive.id}`);
      });
      await seedUserData(files);
      const archive: BackupArchive = await runtime.createBackup('tavern-data/users/default', 'backups/full-1.json', 'full');
      const validation: BackupValidationResult = runtime.validateArchive(archive);
      const firstEntry: BackupManifestEntry = archive.entries[0];
      const saved = await files.readText('backups/full-1.json');

      expect(archive.id).assertEqual('backup-1');
      expect(archive.kind).assertEqual('full');
      expect(archive.entries.length).assertEqual(4);
      expect(firstEntry.path).assertEqual('characters/alice.json');
      expect(validation.valid).assertTrue();
      expect(saved.indexOf('characters/alice.json') >= 0).assertTrue();
      expect(completed.length).assertEqual(1);
      expect(completed[0]).assertEqual('backup-1:backups/full-1.json:backup-1');
    });

    it('restores backup archives and reports restored paths', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new BackupRuntime(files, new EventBus());
      await seedUserData(files);
      const archive = await runtime.createBackup('tavern-data/users/default', 'backups/full-1.json', 'full');
      await files.writeText('tavern-data/users/default/characters/alice.json', '{"name":"changed"}', false);
      await files.delete('tavern-data/users/default/chats/alice/messages.jsonl');
      const result: BackupRestoreResult = await runtime.restoreBackup(archive, 'tavern-data/users/default');
      const restoredCharacter = await files.readText('tavern-data/users/default/characters/alice.json');
      const restoredChat = await files.readText('tavern-data/users/default/chats/alice/messages.jsonl');

      expect(result.restoredPaths.length).assertEqual(4);
      expect(restoredCharacter).assertEqual('{"name":"Alice"}');
      expect(restoredChat.indexOf('"hello"') >= 0).assertTrue();
    });

    it('creates migration backups and rejects corrupted archives', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new BackupRuntime(files, new EventBus());
      await seedUserData(files);
      const migrationBackup = await runtime.createMigrationBackup('tavern-data/users/default', 'schema-v2');
      const badEntry: BackupManifestEntry = {
        path: 'characters/bad.json',
        content: 'bad',
        checksum: 'wrong',
        size: 3,
      };
      const corrupted: BackupArchive = {
        id: 'bad',
        kind: 'full',
        rootPath: 'tavern-data/users/default',
        reason: 'corrupt',
        createdAt: 1,
        entries: [badEntry],
      };
      const validation = runtime.validateArchive(corrupted);

      expect(migrationBackup.kind).assertEqual('migration');
      expect(migrationBackup.reason).assertEqual('schema-v2');
      expect(validation.valid).assertFalse();
      expect(validation.errors.length).assertEqual(1);
    });

    it('rejects backup archives with unsafe relative paths', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new BackupRuntime(files, new EventBus());
      const unsafeEntry: BackupManifestEntry = {
        path: '../outside.json',
        content: '{}',
        checksum: '2:248',
        size: 2,
      };
      const archive: BackupArchive = {
        id: 'unsafe',
        kind: 'full',
        rootPath: 'tavern-data/users/default',
        reason: 'unsafe',
        createdAt: 1,
        entries: [unsafeEntry],
      };
      const validation = runtime.validateArchive(archive);
      let restoreFailed = false;
      try {
        await runtime.restoreBackup(archive, 'tavern-data/users/default');
      } catch (error) {
        restoreFailed = true;
      }

      expect(validation.valid).assertFalse();
      expect(validation.errors[0]).assertContain('Unsafe path');
      expect(restoreFailed).assertTrue();
    });
  });
}

async function seedUserData(files: TavernFileStore): Promise<void> {
  await files.writeText('tavern-data/users/default/characters/alice.json', '{"name":"Alice"}', false);
  await files.writeText('tavern-data/users/default/chats/alice/messages.jsonl', '{"text":"hello"}\n', false);
  await files.writeText('tavern-data/users/default/worldbooks/main.json', '{"entries":[]}', false);
  await files.writeText('tavern-data/users/default/presets/generation/default.json', '{"temperature":1}', false);
}
