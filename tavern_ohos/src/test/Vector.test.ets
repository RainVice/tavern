import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  InMemoryFileStore,
  VectorRuntime,
  type RuntimeEvent,
  type TavernFileStore,
  type VectorCollectionCreateParams,
  type VectorCollectionRecord,
  type VectorDeletedPayload,
  type VectorQueryParams,
  type VectorQueryResult,
  type VectorRecord,
  type VectorUpsertPayload,
} from '../../Index';

export default function vectorUnitTest() {
  describe('vector runtime', () => {
    it('creates collection metadata and writes vector records', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const runtime = new VectorRuntime(files, bus);
      const events = new Array<string>();
      bus.subscribe<VectorUpsertPayload>('vector.upserted', (event: RuntimeEvent<VectorUpsertPayload>) => {
        events.push(`${event.payload.collectionId}:${event.payload.vector.id}`);
      });

      const collection: VectorCollectionRecord = await runtime.createCollection(makeCollection('kb', 3));
      const vector: VectorRecord = await runtime.upsertVector('kb', makeVector('chunk-1', 'doc-1', 'global', [1, 0, 0], 'world lore'));
      const metadata = await files.readText('tavern-data/users/default/vectors/collections/kb/metadata.json');
      const vectors = await files.readText('tavern-data/users/default/vectors/collections/kb/vectors.jsonl');

      expect(collection.id).assertEqual('kb');
      expect(vector.id).assertEqual('chunk-1');
      expect(metadata.indexOf('openai') >= 0).assertTrue();
      expect(vectors.indexOf('world lore') >= 0).assertTrue();
      expect(events[0]).assertEqual('kb:chunk-1');
    });

    it('queries by cosine score topK threshold and scope filter', 0, async () => {
      const runtime = new VectorRuntime(new InMemoryFileStore(), new EventBus());
      await runtime.createCollection(makeCollection('kb', 3));
      await runtime.upsertVector('kb', makeVector('chunk-1', 'doc-1', 'global', [1, 0, 0], 'alpha'));
      await runtime.upsertVector('kb', makeVector('chunk-2', 'doc-2', 'global', [0.8, 0.2, 0], 'beta'));
      await runtime.upsertVector('kb', makeVector('chunk-3', 'doc-3', 'chat:1', [0, 1, 0], 'chat'));

      const query: VectorQueryParams = {
        collectionIds: ['kb'],
        embedding: [1, 0, 0],
        topK: 2,
        scoreThreshold: 0.75,
        scope: 'global',
      };
      const result: VectorQueryResult = runtime.query(query);

      expect(result.hits.length).assertEqual(2);
      expect(result.hits[0].vector.id).assertEqual('chunk-1');
      expect(result.hits[1].vector.id).assertEqual('chunk-2');
      expect(result.hits[0].score >= result.hits[1].score).assertTrue();
    });

    it('deletes vectors by document and scope', 0, async () => {
      const bus = new EventBus();
      const runtime = new VectorRuntime(new InMemoryFileStore(), bus);
      const deleted = new Array<string>();
      bus.subscribe<VectorDeletedPayload>('vector.deleted', (event: RuntimeEvent<VectorDeletedPayload>) => {
        deleted.push(`${event.payload.collectionId}:${event.payload.deletedIds.length}`);
      });
      await runtime.createCollection(makeCollection('kb', 3));
      await runtime.upsertVector('kb', makeVector('chunk-1', 'doc-1', 'global', [1, 0, 0], 'alpha'));
      await runtime.upsertVector('kb', makeVector('chunk-2', 'doc-1', 'global', [0.9, 0.1, 0], 'beta'));
      await runtime.upsertVector('kb', makeVector('chunk-3', 'doc-2', 'chat:1', [0, 1, 0], 'chat'));

      const byDocument = await runtime.deleteByDocument('kb', 'doc-1');
      const byScope = await runtime.deleteByScope('kb', 'chat:1');
      const remaining = await runtime.listVectors('kb');

      expect(byDocument.length).assertEqual(2);
      expect(byScope.length).assertEqual(1);
      expect(remaining.length).assertEqual(0);
      expect(deleted[0]).assertEqual('kb:2');
      expect(deleted[1]).assertEqual('kb:1');
    });

    it('拒绝用不同维度覆盖已有 collection', 0, async () => {
      const runtime = new VectorRuntime(new InMemoryFileStore(), new EventBus());
      await runtime.createCollection(makeCollection('kb', 3));

      let failed = false;
      try {
        await runtime.createCollection(makeCollection('kb', 4));
      } catch (error) {
        failed = true;
      }

      expect(failed).assertTrue();
    });

    it('净化 collection 路径段避免越过 collections 目录', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const runtime = new VectorRuntime(files, new EventBus());

      const collection = await runtime.createCollection(makeCollection('../escape', 3));
      const safeMetadata = await files.readText('tavern-data/users/default/vectors/collections/..~2fescape/metadata.json');
      const escapedExists = await files.exists('tavern-data/users/default/vectors/escape/metadata.json');

      expect(collection.id).assertEqual('../escape');
      expect(collection.path).assertEqual('tavern-data/users/default/vectors/collections/..~2fescape');
      expect(safeMetadata.indexOf('../escape') >= 0).assertTrue();
      expect(escapedExists).assertFalse();
    });
  });
}

function makeCollection(id: string, dimension: number): VectorCollectionCreateParams {
  return {
    id: id,
    provider: 'openai',
    model: 'text-embedding-3-small',
    dimension: dimension,
    metadataJson: '{"source":"test"}',
  };
}

function makeVector(id: string, documentId: string, scope: string, embedding: Array<number>, text: string): VectorRecord {
  return {
    id: id,
    documentId: documentId,
    scope: scope,
    text: text,
    embedding: embedding,
    metadataJson: '{}',
    createdAt: 1,
    updatedAt: 1,
  };
}
