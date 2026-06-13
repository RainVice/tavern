import { describe, it, expect } from '@ohos/hypium';
import {
  DataBankRuntime,
  EventBus,
  InMemoryFileStore,
  type DataBankDocumentCreateParams,
  type DataBankDocumentRecord,
  type DataBankExportData,
  type DataBankUpdatedPayload,
  type RuntimeEvent,
  type TavernFileStore,
} from '../../Index';

export default function dataBankUnitTest() {
  describe('data bank runtime', () => {
    it('stores documents with scope tags metadata and readable content', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new DataBankRuntime(files, bus);
      const events = new Array<string>();
      bus.subscribe<DataBankUpdatedPayload>('databank.document.created', (event: RuntimeEvent<DataBankUpdatedPayload>) => {
        events.push(event.payload.documentId);
      });
      const document = await runtime.createDocument(makeDocument('doc-1', 'global', 'lore', 'world,lore'));
      const saved = await files.readText('tavern-data/users/default/databank/documents/doc-1.txt');
      const index = await files.readText('tavern-data/users/default/databank/index.json');

      expect(document.id).assertEqual('doc-1');
      expect(document.scope).assertEqual('global');
      expect(saved).assertEqual('world lore text');
      expect(index.indexOf('doc-1') >= 0).assertTrue();
      expect(events.length).assertEqual(1);
      expect(events[0]).assertEqual('doc-1');
    });

    it('filters by enabled state scope and tags', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new DataBankRuntime(files, new EventBus());
      await runtime.createDocument(makeDocument('doc-global', 'global', 'lore', 'world,lore'));
      await runtime.createDocument(makeDocument('doc-chat', 'chat:chat-1', 'chat', 'chat,summary'));

      await runtime.setDocumentEnabled('doc-chat', false);
      const active = await runtime.listDocuments(false);
      const all = await runtime.listDocuments(true);
      const chatDocs = await runtime.listByScope('chat:chat-1', true);
      const loreDocs = await runtime.listByTag('lore', false);

      expect(active.length).assertEqual(1);
      expect(all.length).assertEqual(2);
      expect(chatDocs.length).assertEqual(1);
      expect(chatDocs[0].enabled).assertFalse();
      expect(loreDocs.length).assertEqual(1);
      expect(loreDocs[0].id).assertEqual('doc-global');
    });

    it('exports and imports documents preserving content and metadata', 0, async () => {
      const sourceFiles: TavernFileStore = new InMemoryFileStore();
      // 来源类型。
      const source = new DataBankRuntime(sourceFiles, new EventBus());
      await source.createDocument(makeDocument('doc-1', 'character:alice', 'memo', 'character,memo'));
      await source.setDocumentEnabled('doc-1', false);
      const exported: DataBankExportData = await source.exportData(true);
      exported.documents[0].path = '../outside.txt';
      const targetFiles: TavernFileStore = new InMemoryFileStore();
      const target = new DataBankRuntime(targetFiles, new EventBus());
      await target.importData(exported, true);
      const imported: DataBankDocumentRecord | undefined = await target.getDocument('doc-1');
      const importedContent = await target.readDocumentContent('doc-1');

      expect(imported === undefined).assertFalse();
      expect(imported!.enabled).assertFalse();
      expect(imported!.path).assertEqual('tavern-data/users/default/databank/documents/doc-1.txt');
      expect(imported!.metadataJson).assertEqual('{"title":"memo"}');
      expect(importedContent).assertEqual('world lore text');
    });

    it('replace import removes stale document files', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new DataBankRuntime(files, new EventBus());
      await runtime.createDocument(makeDocument('old-doc', 'global', 'old', 'old'));
      const exported: DataBankExportData = {
        documents: [
          makeDocumentRecord('new-doc', 'new content'),
        ],
      };

      await runtime.importData(exported, true);
      const oldExists = await files.exists('tavern-data/users/default/databank/documents/old-doc.txt');
      const newContent = await runtime.readDocumentContent('new-doc');

      expect(oldExists).assertFalse();
      expect(newContent).assertEqual('new content');
    });

    it('keeps escaped document ids on distinct paths', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new DataBankRuntime(files, new EventBus());

      await runtime.createDocument(makeDocumentWithContent('a/b', 'global', 'slash content'));
      await runtime.createDocument(makeDocumentWithContent('a-b', 'global', 'dash content'));
      const slash = await runtime.getDocument('a/b');
      const dash = await runtime.getDocument('a-b');
      const slashContent = await runtime.readDocumentContent('a/b');
      const dashContent = await runtime.readDocumentContent('a-b');

      expect(slash!.path).assertEqual('tavern-data/users/default/databank/documents/a~2fb.txt');
      expect(dash!.path).assertEqual('tavern-data/users/default/databank/documents/a-b.txt');
      expect(slashContent).assertEqual('slash content');
      expect(dashContent).assertEqual('dash content');
    });


    it('derives safe document paths from document ids', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new DataBankRuntime(files, new EventBus());
      const document = await runtime.createDocument(makeDocument('../escape', 'global', 'memo', 'safe'));
      const content = await runtime.readDocumentContent('../escape');

      expect(document.id).assertEqual('../escape');
      expect(document.path).assertEqual('tavern-data/users/default/databank/documents/..~2fescape.txt');
      expect(content).assertEqual('world lore text');
    });
  });
}

/**
 * 封装单元测试中的 makeDocument 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param scope 绑定或查询使用的作用域。
 * @param fileName file 名称。
 */
function makeDocument(id: string, scope: string, fileName: string, tagCsv: string): DataBankDocumentCreateParams {
  return {
    id: id,
    scope: scope,
    sourceType: 'manual',
    fileName: fileName,
    mimeType: 'text/plain',
    content: 'world lore text',
    tags: tagCsv.split(','),
    metadataJson: '{"title":"memo"}',
    enabled: true,
  };
}

/**
 * 封装单元测试中的 makeDocumentWithContent 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param scope 绑定或查询使用的作用域。
 * @param content 要写入或追加的文本内容。
 */
function makeDocumentWithContent(id: string, scope: string, content: string): DataBankDocumentCreateParams {
  const params = makeDocument(id, scope, 'memo', 'safe');
  params.content = content;
  return params;
}

/**
 * 封装单元测试中的 makeDocumentRecord 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param content 要写入或追加的文本内容。
 */
function makeDocumentRecord(id: string, content: string): DataBankDocumentRecord {
  return {
    schemaVersion: 1,
    id: id,
    scope: 'global',
    sourceType: 'manual',
    fileName: `${id}.txt`,
    mimeType: 'text/plain',
    path: 'ignored',
    content: content,
    tags: ['import'],
    metadataJson: '{}',
    enabled: true,
    createdAt: 1,
    updatedAt: 1,
  };
}
