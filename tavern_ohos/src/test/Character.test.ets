import { describe, it, expect } from '@ohos/hypium';
import {
  CharacterRuntime,
  EventBus,
  InMemoryFileStore,
  type CharacterCreateParams,
  type CharacterRecord,
  type CharacterUpdateParams,
  type RuntimeEvent,
  type TavernFileStore,
} from '../../Index';

/**
 * 描述单元测试事件发布时携带的数据结构。
 */
interface CharacterEventPayload {
  /**
   * 角色数据。
   */
  character: CharacterRecord;
}

export default function characterUnitTest() {
  describe('character runtime', () => {
    it('creates, indexes, updates, duplicates, and deletes characters', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new CharacterRuntime(files, bus, 'tavern-data', 'default');
      const events = new Array<string>();
      bus.subscribe<CharacterEventPayload>('character.updated', (event: RuntimeEvent<CharacterEventPayload>) => {
        events.push(event.payload.character.id);
      });
      const createParams: CharacterCreateParams = {
        name: 'Alice',
        description: 'A test character',
        personality: 'Curious',
        scenario: 'A lab',
        firstMessage: 'Hello',
        exampleDialogue: '<START>',
        tags: ['test', 'agent'],
      };
      const created = await runtime.createCharacter(createParams);
      const updateParams: CharacterUpdateParams = {
        name: 'Alice Prime',
        description: 'A test character',
        personality: 'Curious and precise',
        scenario: 'A lab',
        firstMessage: 'Hello',
        exampleDialogue: '<START>',
        tags: ['test', 'favorite'],
        favorite: true,
      };
      const updated = await runtime.updateCharacter(created.id, updateParams);
      const duplicate = await runtime.duplicateCharacter(created.id, 'Alice Copy');
      const listAfterDuplicate = await runtime.listCharacters();
      await files.writeText('tavern-data/users/default/characters/char-1/avatar.png', 'avatar', false);
      await files.writeText('tavern-data/users/default/characters/char-1/sprites/joy.png', 'sprite', false);
      await runtime.deleteCharacter(created.id);
      const listAfterDelete = await runtime.listCharacters();

      expect(created.id).assertEqual('char-1');
      expect(updated.name).assertEqual('Alice Prime');
      expect(updated.favorite).assertTrue();
      expect(duplicate.id).assertEqual('char-2');
      expect(duplicate.name).assertEqual('Alice Copy');
      expect(listAfterDuplicate.length).assertEqual(2);
      expect(listAfterDelete.length).assertEqual(1);
      expect(listAfterDelete[0].id).assertEqual('char-2');
      expect(await files.exists('tavern-data/users/default/characters/char-1/character.json')).assertFalse();
      expect(await files.exists('tavern-data/users/default/characters/char-1/avatar.png')).assertFalse();
      expect(await files.exists('tavern-data/users/default/characters/char-1/sprites/joy.png')).assertFalse();
      expect(events.length).assertEqual(1);
      expect(events[0]).assertEqual('char-1');
    });

    it('不会暴露可污染持久化角色的事件或返回对象', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new CharacterRuntime(files, bus, 'tavern-data', 'default');
      bus.subscribe<CharacterEventPayload>('character.created', (event: RuntimeEvent<CharacterEventPayload>) => {
        event.payload.character.name = 'event-mutated';
        event.payload.character.tags.push('event');
      });
      const createParams: CharacterCreateParams = {
        name: 'Copy Safe',
        description: '',
        personality: '',
        scenario: '',
        firstMessage: '',
        exampleDialogue: '',
        tags: ['safe'],
      };
      const created = await runtime.createCharacter(createParams);
      expect(created.name).assertEqual('Copy Safe');
      expect(created.tags.length).assertEqual(1);
      created.name = 'external-mutated';
      created.tags.push('external');
      const loaded = await runtime.getCharacter(created.id);

      expect(loaded.name).assertEqual('Copy Safe');
      expect(loaded.tags.length).assertEqual(1);
      expect(loaded.tags[0]).assertEqual('safe');
    });

    it('imports and exports SillyTavern V2 JSON cards with source JSON preserved', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new CharacterRuntime(files, bus, 'tavern-data', 'default');
      // card JSON 字符串。
      const cardJson = '{"spec":"chara_card_v2","spec_version":"2.0","data":{"name":"Bob","description":"Imported","personality":"Kind","scenario":"Workshop","first_mes":"Hi","mes_example":"<START>","tags":["imported"],"extensions":{"fav":true,"world":"test-world"}},"vendorExtra":"keep-me"}';
      const imported = await runtime.importCharacterJson(cardJson);
      const exported = await runtime.exportCharacterJson(imported.id);
      const loaded = await runtime.getCharacter(imported.id);

      expect(imported.name).assertEqual('Bob');
      expect(imported.sourceFormat).assertEqual('character_card_v2_json');
      expect(loaded.favorite).assertTrue();
      expect(loaded.world).assertEqual('test-world');
      expect(exported).assertEqual(cardJson);
    });

    it('读取、更新、复制或删除不存在的角色时抛错', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new CharacterRuntime(files, bus, 'tavern-data', 'default');
      const updateParams: CharacterUpdateParams = {
        name: 'Missing',
        description: '',
        personality: '',
        scenario: '',
        firstMessage: '',
        exampleDialogue: '',
        tags: new Array<string>(),
        favorite: false,
      };
      let getFailed = false;
      try {
        await runtime.getCharacter('missing-character');
      } catch (error) {
        getFailed = true;
      }
      let updateFailed = false;
      try {
        await runtime.updateCharacter('missing-character', updateParams);
      } catch (error) {
        updateFailed = true;
      }
      let duplicateFailed = false;
      try {
        await runtime.duplicateCharacter('missing-character', 'Copy');
      } catch (error) {
        duplicateFailed = true;
      }
      let deleteFailed = false;
      try {
        await runtime.deleteCharacter('missing-character');
      } catch (error) {
        deleteFailed = true;
      }

      expect(getFailed).assertTrue();
      expect(updateFailed).assertTrue();
      expect(duplicateFailed).assertTrue();
      expect(deleteFailed).assertTrue();
    });

    it('拒绝通过路径穿越别名读取已有角色', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new CharacterRuntime(files, new EventBus(), 'tavern-data', 'default');
      const createParams: CharacterCreateParams = {
        name: 'Alice',
        description: '',
        personality: '',
        scenario: '',
        firstMessage: '',
        exampleDialogue: '',
        tags: new Array<string>(),
      };
      await runtime.createCharacter(createParams);
      let aliasFailed = false;
      try {
        await runtime.getCharacter('../characters/char-1');
      } catch (error) {
        aliasFailed = true;
      }

      expect(aliasFailed).assertTrue();
    });
  });
}
