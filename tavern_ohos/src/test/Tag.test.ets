import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
} from '../../Index';
import {
  TagRuntime,
  type TagImportResult,
  type TagRecord,
} from '../main/ets/tag/Index';

export default function tagUnitTest() {
  describe('tag runtime', () => {
    it('creates tags, assigns entity tag maps, and renames entity keys', 0, () => {
      const runtime = new TagRuntime(new EventBus());
      const lore: TagRecord = runtime.createTag({
        name: 'Lore',
        color: '#223344',
      });
      const favorite: TagRecord = runtime.createTag({
        name: 'Favorite',
        folderType: 'OPEN',
      });

      runtime.addTagToEntity('char-a.png', lore.id);
      runtime.addTagToEntity('char-a.png', favorite.id);
      runtime.renameTagKey('char-a.png', 'char-b.png');
      const tags: Array<TagRecord> = runtime.getTagsList('char-b.png', 'manual');

      expect(tags.length).assertEqual(2);
      expect(tags[0].name).assertEqual('Lore');
      expect(runtime.isFolderTag(favorite.id)).assertTrue();
      expect(runtime.getTagsList('char-a.png', 'manual').length).assertEqual(0);
    });

    it('imports tags with upstream import settings and removes tag map entries', 0, () => {
      const runtime = new TagRuntime(new EventBus());
      const existing: TagRecord = runtime.createTag({ name: 'Existing' });

      const onlyExisting: TagImportResult = runtime.importTagsFromNames('char-a.png', [
        'Existing',
        'New Tag',
        'ROOT',
      ], 'only_existing');
      const all: TagImportResult = runtime.importTagsFromNames('char-b.png', [
        'Existing',
        'New Tag',
        'TAVERN',
      ], 'all');

      runtime.removeTagFromMap(existing.id);

      expect(onlyExisting.imported.length).assertEqual(1);
      expect(onlyExisting.imported[0].name).assertEqual('Existing');
      expect(all.imported.length).assertEqual(2);
      expect(runtime.getTagsList('char-a.png', 'manual').length).assertEqual(0);
      expect(runtime.getTagsList('char-b.png', 'manual').length).assertEqual(1);
    });

    it('sorts tags manually, alphabetically, and by entity usage', 0, () => {
      const runtime = new TagRuntime(new EventBus());
      const zed = runtime.createTag({ name: 'Zed', sortOrder: 1 });
      const alpha = runtime.createTag({ name: 'Alpha', sortOrder: 2 });

      runtime.addTagToEntity('char-a.png', alpha.id);
      runtime.addTagToEntity('char-b.png', alpha.id);
      runtime.addTagToEntity('char-c.png', zed.id);

      const manual: Array<TagRecord> = runtime.listTags('manual');
      const alphabetical: Array<TagRecord> = runtime.listTags('alphabetical');
      const byEntries: Array<TagRecord> = runtime.listTags('by_entries');

      expect(manual[0].name).assertEqual('Zed');
      expect(alphabetical[0].name).assertEqual('Alpha');
      expect(byEntries[0].name).assertEqual('Alpha');
    });
  });
}
