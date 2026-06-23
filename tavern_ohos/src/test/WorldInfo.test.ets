import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  InMemoryFileStore,
  WorldInfoRuntime,
  type RuntimeEvent,
  type TavernFileStore,
  type WorldInfoActivationPayload,
  type WorldInfoEntryCreateParams,
  type WorldInfoEntryUpdateParams,
  type WorldInfoEventPayload,
  type WorldInfoImportData,
} from '../../Index';

export default function worldInfoUnitTest() {
  describe('world info runtime', () => {
    it('creates worldbooks and activates constant, primary, and selective entries in order', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new WorldInfoRuntime(files, bus, 'tavern-data', 'default');
      const activatedCounts = new Array<number>();
      bus.subscribe<WorldInfoActivationPayload>('worldinfo.activated', (event: RuntimeEvent<WorldInfoActivationPayload>) => {
        activatedCounts.push(event.payload.entries.length);
      });
      const book = await runtime.createWorldBook('Lore');
      const constantParams: WorldInfoEntryCreateParams = {
        comment: 'Always',
        keys: new Array<string>(),
        secondaryKeys: new Array<string>(),
        content: 'Always active.',
        constant: true,
        selective: false,
        enabled: true,
        insertionOrder: 20,
        position: 'before',
        caseSensitive: false,
      };
      const primaryParams: WorldInfoEntryCreateParams = {
        comment: 'Dragon',
        keys: ['dragon'],
        secondaryKeys: new Array<string>(),
        content: 'Dragon lore.',
        constant: false,
        selective: false,
        enabled: true,
        insertionOrder: 10,
        position: 'before',
        caseSensitive: false,
      };
      const selectiveParams: WorldInfoEntryCreateParams = {
        comment: 'Castle dragon',
        keys: ['dragon'],
        secondaryKeys: ['castle'],
        content: 'Castle dragon lore.',
        constant: false,
        selective: true,
        enabled: true,
        insertionOrder: 30,
        position: 'after',
        caseSensitive: false,
      };

      await runtime.createEntry(book.id, constantParams);
      await runtime.createEntry(book.id, primaryParams);
      await runtime.createEntry(book.id, selectiveParams);
      const activation = await runtime.activateEntries([book.id], ['The DRAGON sleeps near the castle.']);

      expect(activation.entries.length).assertEqual(3);
      expect(activation.entries[0].comment).assertEqual('Dragon');
      expect(activation.entries[1].comment).assertEqual('Always');
      expect(activation.entries[2].comment).assertEqual('Castle dragon');
      expect(activation.promptText).assertContain('Dragon lore.');
      expect(activation.promptText).assertContain('Always active.');
      expect(activatedCounts.length).assertEqual(1);
      expect(activatedCounts[0]).assertEqual(3);
    });

    it('激活排序后保持 entries 和 matches 对齐', 0, async () => {
      // 运行时实例。
      const runtime = new WorldInfoRuntime(new InMemoryFileStore(), new EventBus(), 'tavern-data', 'default');
      const book = await runtime.createWorldBook('Sorted');
      const later = await runtime.createEntry(book.id, makeEntryParams('Later', ['later'], 'later content', 20));
      const earlier = await runtime.createEntry(book.id, makeEntryParams('Earlier', ['earlier'], 'earlier content', 10));
      const activation = await runtime.activateEntries([book.id], ['later earlier']);

      expect(activation.entries.length).assertEqual(2);
      expect(activation.matches.length).assertEqual(2);
      expect(activation.entries[0].id).assertEqual(earlier.id);
      expect(activation.matches[0].entryId).assertEqual(earlier.id);
      expect(activation.entries[1].id).assertEqual(later.id);
      expect(activation.matches[1].entryId).assertEqual(later.id);
    });

    it('updates, deletes, exports, and imports worldbooks', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new WorldInfoRuntime(files, bus, 'tavern-data', 'default');
      const book = await runtime.createWorldBook('Editable');
      const entryParams: WorldInfoEntryCreateParams = {
        comment: 'Old',
        keys: ['old'],
        secondaryKeys: new Array<string>(),
        content: 'Old content',
        constant: false,
        selective: false,
        enabled: true,
        insertionOrder: 1,
        position: 'before',
        caseSensitive: false,
      };
      // 条目记录。
      const entry = await runtime.createEntry(book.id, entryParams);
      const updateParams: WorldInfoEntryUpdateParams = {
        comment: 'New',
        keys: ['new'],
        secondaryKeys: ['gate'],
        content: 'New content',
        constant: false,
        selective: true,
        enabled: true,
        insertionOrder: 2,
        position: 'after',
        caseSensitive: true,
      };
      const updated = await runtime.updateEntry(book.id, entry.id, updateParams);
      const exported = await runtime.exportWorldBookJson(book.id);
      await runtime.deleteEntry(book.id, entry.id);
      const afterDelete = await runtime.getWorldBook(book.id);
      const importedData = JSON.parse(exported) as WorldInfoImportData;
      const imported = await runtime.importWorldBookJson(exported, 'Imported');

      expect(updated.comment).assertEqual('New');
      expect(afterDelete.entries.length).assertEqual(0);
      expect(importedData.entries.length).assertEqual(1);
      expect(imported.name).assertEqual('Imported');
      expect(imported.entries[0].content).assertEqual('New content');
    });

    it('更新或删除不存在的条目时抛错', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new WorldInfoRuntime(files, bus, 'tavern-data', 'default');
      const book = await runtime.createWorldBook('Strict');
      const updateParams: WorldInfoEntryUpdateParams = {
        comment: 'Missing',
        keys: ['missing'],
        secondaryKeys: new Array<string>(),
        content: 'Missing content',
        constant: false,
        selective: false,
        enabled: true,
        insertionOrder: 1,
        position: 'before',
        caseSensitive: false,
      };
      let updateFailed = false;
      try {
        await runtime.updateEntry(book.id, 'missing-entry', updateParams);
      } catch (error) {
        updateFailed = true;
      }
      let deleteFailed = false;
      try {
        await runtime.deleteEntry(book.id, 'missing-entry');
      } catch (error) {
        deleteFailed = true;
      }

      expect(updateFailed).assertTrue();
      expect(deleteFailed).assertTrue();
    });

    it('导入世界书后根据已有 entries 推进 nextEntryId', 0, async () => {
      // 运行时实例。
      const runtime = new WorldInfoRuntime(new InMemoryFileStore(), new EventBus(), 'tavern-data', 'default');
      const importedData: WorldInfoImportData = {
        schemaVersion: 1,
        id: 'old-book',
        name: 'Old',
        nextEntryId: 1,
        entries: [
          {
            id: 'entry-7',
            uid: 7,
            comment: 'Imported',
            keys: ['imported'],
            secondaryKeys: new Array<string>(),
            content: 'Imported content',
            constant: false,
            selective: false,
            enabled: true,
            insertionOrder: 1,
            position: 'before',
            caseSensitive: false,
            createdAt: 1,
            updatedAt: 1,
          },
        ],
        createdAt: 1,
        updatedAt: 1,
      };
      const imported = await runtime.importWorldBookJson(JSON.stringify(importedData), 'Imported');
      const created = await runtime.createEntry(imported.id, makeEntryParams('New', ['new'], 'New content', 2));
      const loaded = await runtime.getWorldBook(imported.id);

      expect(created.id).assertEqual('entry-8');
      expect(created.uid).assertEqual(8);
      expect(loaded.nextEntryId).assertEqual(9);
      expect(loaded.entries.length).assertEqual(2);
    });

    it('递归激活不会误合并不同世界书中的相同 entry id', 0, async () => {
      // 运行时实例。
      const runtime = new WorldInfoRuntime(new InMemoryFileStore(), new EventBus(), 'tavern-data', 'default');
      const firstBook = await runtime.createWorldBook('First');
      const secondBook = await runtime.createWorldBook('Second');
      await runtime.createEntry(firstBook.id, makeEntryParams('First entry', ['alpha'], 'beta', 1));
      await runtime.createEntry(secondBook.id, makeEntryParams('Second entry', ['beta'], 'second content', 2));
      const activation = await runtime.activateEntriesRecursive([firstBook.id, secondBook.id], ['alpha'], 2, 100);

      expect(activation.entries.length).assertEqual(2);
      expect(activation.matches.length).assertEqual(2);
      expect(activation.matches[0].worldBookId).assertEqual(firstBook.id);
      expect(activation.matches[1].worldBookId).assertEqual(secondBook.id);
      expect(activation.promptText).assertContain('second content');
    });

    it('不会暴露可污染世界书和激活结果的内部对象', 0, async () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new WorldInfoRuntime(new InMemoryFileStore(), bus, 'tavern-data', 'default');
      bus.subscribe<WorldInfoEventPayload>('worldinfo.created', (event: RuntimeEvent<WorldInfoEventPayload>) => {
        event.payload.worldBook.name = 'event-mutated';
      });
      bus.subscribe<WorldInfoActivationPayload>('worldinfo.activated', (event: RuntimeEvent<WorldInfoActivationPayload>) => {
        event.payload.entries[0].content = 'event-mutated';
        event.payload.matches[0].key = 'event';
      });
      const book = await runtime.createWorldBook('Safe');
      expect(book.name).assertEqual('Safe');
      // 条目记录。
      const entry = await runtime.createEntry(book.id, makeEntryParams('Safe entry', ['safe'], 'safe content', 1));
      entry.keys.push('external');
      const activation = await runtime.activateEntries([book.id], ['safe']);
      expect(activation.entries[0].content).assertEqual('safe content');
      expect(activation.matches[0].key).assertEqual('safe');
      activation.entries[0].content = 'external-mutated';
      const loaded = await runtime.getWorldBook(book.id);

      expect(activation.entries[0].content).assertEqual('external-mutated');
      expect(loaded.name).assertEqual('Safe');
      expect(loaded.entries[0].keys.length).assertEqual(1);
      expect(loaded.entries[0].content).assertEqual('safe content');
    });

    it('读取或删除不存在的世界书时抛错', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new WorldInfoRuntime(files, bus, 'tavern-data', 'default');
      let getFailed = false;
      try {
        await runtime.getWorldBook('missing-book');
      } catch (error) {
        getFailed = true;
      }
      let deleteFailed = false;
      try {
        await runtime.deleteWorldBook('missing-book');
      } catch (error) {
        deleteFailed = true;
      }

      expect(getFailed).assertTrue();
      expect(deleteFailed).assertTrue();
    });

    it('删除索引中残留但文件缺失的世界书', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new WorldInfoRuntime(files, new EventBus(), 'tavern-data', 'default');
      await files.writeText(
        'tavern-data/users/default/worldbooks/index.json',
        '{"schemaVersion":1,"nextId":2,"items":[{"id":"worldbook-1@37f59062","name":"残留世界书","entryCount":0,"createdAt":1,"updatedAt":1}]}',
        false,
      );

      const beforeDelete = await runtime.listWorldBooks();
      await runtime.deleteWorldBook('worldbook-1@37f59062');
      const afterDelete = await runtime.listWorldBooks();

      expect(beforeDelete.length).assertEqual(1);
      expect(afterDelete.length).assertEqual(0);
    });

    it('拒绝通过路径穿越别名读取已有世界书', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new WorldInfoRuntime(files, new EventBus(), 'tavern-data', 'default');
      await runtime.createWorldBook('Lore');
      let aliasFailed = false;
      try {
        await runtime.getWorldBook('../worldbooks/worldbook-1');
      } catch (error) {
        aliasFailed = true;
      }

      expect(aliasFailed).assertTrue();
    });
  });
}

/**
 * 封装单元测试中的 makeEntryParams 步骤，供公开方法复用。


 * @param content 要写入或追加的文本内容。

 * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
 */
function makeEntryParams(comment: string, keys: Array<string>, content: string, insertionOrder: number): WorldInfoEntryCreateParams {
  return {
    comment: comment,
    keys: keys,
    secondaryKeys: new Array<string>(),
    content: content,
    constant: false,
    selective: false,
    enabled: true,
    insertionOrder: insertionOrder,
    position: 'before',
    caseSensitive: false,
  };
}
