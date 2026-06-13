import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  SearchRuntime,
  type RuntimeEvent,
  type SearchDocument,
  type SearchDocumentMetadata,
  type SearchIndexedPayload,
  type SearchQuery,
  type SearchResult,
} from '../../Index';
import {
  type SearchFilterEntity,
  type SearchFilterInput,
} from '../main/ets/search/Index';

export default function searchUnitTest() {
  describe('search runtime', () => {
    it('indexes characters, chats, messages, files, and settings for full text search', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SearchRuntime(bus);
      const indexed = new Array<string>();
      bus.subscribe<SearchIndexedPayload>('search.indexed', (event: RuntimeEvent<SearchIndexedPayload>) => {
        indexed.push(event.payload.document.id);
      });

      runtime.upsertDocument(makeDocument('character', 'char-a', 'Alice', 'curious mage friend', ['mage'], 'characters/alice.json'));
      runtime.upsertDocument(makeDocument('chat', 'chat-a', 'Alice chat', 'first meeting in tavern', ['alice'], 'chats/alice.jsonl'));
      runtime.upsertDocument(makeDocument('message', 'msg-a', 'Greeting', 'hello from user', ['chat-a'], 'chats/alice.jsonl'));
      runtime.upsertDocument(makeDocument('file', 'file-a', 'lore note', 'tavern map attachment', ['map'], 'databank/map.txt'));
      runtime.upsertDocument(makeDocument('setting', 'setting-a', 'temperature', 'generation sampler value', ['sampler'], 'settings.json'));
      // 查询条件。
      const query: SearchQuery = {
        text: 'tavern',
        domains: new Array<string>(),
        tags: new Array<string>(),
        metadataKey: '',
        metadataValue: '',
        limit: 10,
      };
      const results = runtime.search(query);

      expect(indexed.length).assertEqual(5);
      expect(results.length).assertEqual(2);
      expect(results[0].documentId).assertEqual('chat-a');
      expect(results[0].score > 0).assertTrue();
      expect(results[1].documentId).assertEqual('file-a');
    });

    it('filters by domain, tag, and metadata', 0, () => {
      // 运行时实例。
      const runtime = new SearchRuntime(new EventBus());
      const document = makeDocument('worldinfo', 'wi-a', 'Dragon lore', 'ancient dragon keyword', ['lore', 'dragon'], 'worldbooks/main.json');
      document.metadata.push({ key: 'book', value: 'main' });
      runtime.upsertDocument(document);
      runtime.upsertDocument(makeDocument('attachment', 'att-a', 'dragon image', 'image attachment', ['image'], 'assets/dragon.png'));
      const domainResults = runtime.search({
        text: 'dragon',
        domains: ['worldinfo'],
        tags: new Array<string>(),
        metadataKey: '',
        metadataValue: '',
        limit: 5,
      });
      const tagResults = runtime.searchByTag('dragon');
      const metadataResults = runtime.searchMetadata('book', 'main');

      expect(domainResults.length).assertEqual(1);
      expect(domainResults[0].domain).assertEqual('worldinfo');
      expect(tagResults.length).assertEqual(1);
      expect(tagResults[0].documentId).assertEqual('wi-a');
      expect(metadataResults.length).assertEqual(1);
      expect(metadataResults[0].documentId).assertEqual('wi-a');
    });

    it('removes indexed documents and emits search results', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SearchRuntime(bus);
      const resultCounts = new Array<number>();
      bus.subscribe<SearchResult>('search.result', (event: RuntimeEvent<SearchResult>) => {
        resultCounts.push(event.payload.total);
      });

      runtime.upsertDocument(makeDocument('preset', 'preset-a', 'Creative preset', 'high temperature profile', ['creative'], 'presets/creative.json'));
      const before = runtime.searchText('temperature');
      runtime.removeDocument('preset-a');
      const after = runtime.searchText('temperature');

      expect(before.length).assertEqual(1);
      expect(after.length).assertEqual(0);
      expect(resultCounts.length).assertEqual(2);
      expect(resultCounts[0]).assertEqual(1);
      expect(resultCounts[1]).assertEqual(0);
    });

    it('publishes total hits before applying result limits', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SearchRuntime(bus);
      const totals = new Array<number>();
      const hitCounts = new Array<number>();
      bus.subscribe<SearchResult>('search.result', (event: RuntimeEvent<SearchResult>) => {
        totals.push(event.payload.total);
        hitCounts.push(event.payload.hits.length);
      });
      runtime.upsertDocument(makeDocument('message', 'msg-1', 'A', 'shared word one', ['chat'], 'a.jsonl'));
      runtime.upsertDocument(makeDocument('message', 'msg-2', 'B', 'shared word two', ['chat'], 'b.jsonl'));
      const results = runtime.search({
        text: 'shared',
        domains: new Array<string>(),
        tags: new Array<string>(),
        metadataKey: '',
        metadataValue: '',
        limit: 1,
      });

      expect(results.length).assertEqual(1);
      expect(totals[0]).assertEqual(2);
      expect(hitCounts[0]).assertEqual(1);
    });

    it('applies frontend filter helper search, tag, favorite, group, and folder filters', 0, () => {
      // 运行时实例。
      const runtime = new SearchRuntime(new EventBus());
      const entities: Array<SearchFilterEntity> = [
        makeEntity('char-a', 'character', 'Alice Mage', 'curious lore keeper', ['lore'], true, false, false),
        makeEntity('group-a', 'group', 'Adventuring Party', 'group chat', ['party'], false, true, false),
        makeEntity('folder-a', 'tag', 'Lore Folder', 'folder', ['lore'], false, false, true),
        makeEntity('char-b', 'character', 'Bob', 'plain character', ['plain'], false, false, false),
      ];
      const filter: SearchFilterInput = {
        search: 'lore',
        selectedTags: ['lore'],
        excludedTags: new Array<string>(),
        favoriteOnly: false,
        groupOnly: false,
        folderOnly: false,
      };
      const loreResults = runtime.filterEntities(entities, filter);
      filter.favoriteOnly = true;
      const favoriteResults = runtime.filterEntities(entities, filter);
      filter.favoriteOnly = false;
      filter.folderOnly = true;
      const folderResults = runtime.filterEntities(entities, filter);
      filter.folderOnly = false;
      filter.groupOnly = true;
      filter.search = '';
      filter.selectedTags = new Array<string>();
      const groupResults = runtime.filterEntities(entities, filter);

      expect(runtime.isFilterState('SELECTED', 'SELECTED')).assertTrue();
      expect(runtime.hasAnyFilter(filter)).assertTrue();
      expect(loreResults.length).assertEqual(2);
      expect(favoriteResults.length).assertEqual(1);
      expect(favoriteResults[0].id).assertEqual('char-a');
      expect(folderResults.length).assertEqual(1);
      expect(folderResults[0].id).assertEqual('folder-a');
      expect(groupResults.length).assertEqual(1);
      expect(groupResults[0].id).assertEqual('group-a');
    });
  });
}

/**
 * 封装单元测试中的 makeDocument 步骤，供公开方法复用。

 * @param id 唯一标识。
 * @param title 标题。


 * @param path 目标文件或目录路径。
 * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
 */
function makeDocument(domain: string, id: string, title: string, body: string, tags: Array<string>, path: string): SearchDocument {
  return {
    id: id,
    domain: domain,
    title: title,
    body: body,
    tags: tags,
    path: path,
    metadata: new Array<SearchDocumentMetadata>(),
    updatedAt: 0,
  };
}

/**
 * 封装单元测试中的 makeEntity 步骤，供公开方法复用。
 * @param id 唯一标识。

 * @param title 标题。





 * @returns 条件命中时返回 true，否则返回 false。
 */
function makeEntity(id: string, type: string, title: string, body: string, tags: Array<string>, favorite: boolean, group: boolean, folder: boolean): SearchFilterEntity {
  return {
    id: id,
    type: type,
    title: title,
    body: body,
    tags: tags,
    favorite: favorite,
    group: group,
    folder: folder,
  };
}
