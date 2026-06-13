import { describe, it, expect } from '@ohos/hypium';
import {
  AvatarRuntime,
  EventBus,
  InMemoryFileStore,
  type AvatarCrop,
  type AvatarDeletedPayload,
  type AvatarRecord,
  type AvatarUploadedPayload,
  type RuntimeEvent,
  type TavernFileStore,
} from '../../Index';

export default function avatarUnitTest() {
  describe('avatar runtime', () => {
    it('uploads character avatars with crop metadata and persists an index', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const runtime = new AvatarRuntime(files, bus);
      const uploaded = new Array<string>();
      bus.subscribe<AvatarUploadedPayload>('avatar.uploaded', (event: RuntimeEvent<AvatarUploadedPayload>) => {
        uploaded.push(`${event.payload.avatar.targetType}:${event.payload.avatar.targetId}`);
      });
      const crop: AvatarCrop = {
        x: 1,
        y: 2,
        width: 128,
        height: 128,
      };

      const record: AvatarRecord = await runtime.uploadAvatar('character', 'alice', 'avatar.png', 'image/png', 'png-data', crop);
      const content = await files.readText('tavern-data/users/default/characters/alice/avatar.png');
      const index = await files.readText('tavern-data/users/default/avatars/index.json');

      expect(record.targetType).assertEqual('character');
      expect(record.path).assertEqual('tavern-data/users/default/characters/alice/avatar.png');
      expect(record.crop.width).assertEqual(128);
      expect(content).assertEqual('png-data');
      expect(index.indexOf('alice') >= 0).assertTrue();
      expect(uploaded[0]).assertEqual('character:alice');
    });

    it('lists persona avatars and resolves active avatar content', 0, async () => {
      const runtime = new AvatarRuntime(new InMemoryFileStore(), new EventBus());
      await runtime.uploadAvatar('persona', 'hero.png', 'hero.png', 'image/png', 'persona-png', emptyCrop());
      await runtime.uploadAvatar('persona', 'mage.png', 'mage.png', 'image/png', 'mage-png', emptyCrop());

      const personas = await runtime.listByTargetType('persona');
      const hero = await runtime.getAvatar('persona', 'hero.png');
      const content = await runtime.readAvatarContent('persona', 'hero.png');

      expect(personas.length).assertEqual(2);
      expect(hero === undefined).assertFalse();
      expect(hero!.fileName).assertEqual('hero.png');
      expect(content).assertEqual('persona-png');
    });

    it('deletes avatars and emits deletion events', 0, async () => {
      const bus = new EventBus();
      const runtime = new AvatarRuntime(new InMemoryFileStore(), bus);
      const deleted = new Array<string>();
      bus.subscribe<AvatarDeletedPayload>('avatar.deleted', (event: RuntimeEvent<AvatarDeletedPayload>) => {
        deleted.push(`${event.payload.targetType}:${event.payload.targetId}`);
      });
      await runtime.uploadAvatar('character', 'alice', 'avatar.png', 'image/png', 'png-data', emptyCrop());

      await runtime.deleteAvatar('character', 'alice');
      const records = await runtime.listByTargetType('character');

      expect(records.length).assertEqual(0);
      expect(deleted[0]).assertEqual('character:alice');
    });

    it('sanitizes avatar target and file path segments', 0, async () => {
      const runtime = new AvatarRuntime(new InMemoryFileStore(), new EventBus());

      const character = await runtime.uploadAvatar('character', '../alice', '../avatar.png', 'image/png', 'png', emptyCrop());
      const persona = await runtime.uploadAvatar('persona', '../hero.png', 'hero.png', 'image/png', 'png', emptyCrop());
      const custom = await runtime.uploadAvatar('../custom', 'target', '../face.png', 'image/png', 'png', emptyCrop());

      expect(character.path).assertEqual('tavern-data/users/default/characters/..~2falice/avatar.png');
      expect(character.fileName).assertEqual('..~2favatar.png');
      expect(persona.path).assertEqual('tavern-data/users/default/personas/..~2fhero.png');
      expect(custom.path).assertEqual('tavern-data/users/default/assets/..~2fcustom/..~2fface.png');
    });
  });
}

function emptyCrop(): AvatarCrop {
  return {
    x: 0,
    y: 0,
    width: 0,
    height: 0,
  };
}
