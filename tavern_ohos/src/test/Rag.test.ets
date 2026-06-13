import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  InMemoryFileStore,
  RagRuntime,
  VectorRuntime,
  type RagChatMessage,
  type RagRetrievedPayload,
  type RagRetrievalInput,
  type RagRetrievalResult,
  type RuntimeEvent,
  type VectorCollectionCreateParams,
  type VectorRecord,
} from '../../Index';

export default function ragUnitTest() {
  describe('rag runtime', () => {
    it('retrieves vector chunks and builds prompt injection text', 0, async () => {
      const bus = new EventBus();
      const vectors = new VectorRuntime(new InMemoryFileStore(), bus);
      const runtime = new RagRuntime(vectors, bus);
      const events = new Array<string>();
      bus.subscribe<RagRetrievedPayload>('rag.retrieved', (event: RuntimeEvent<RagRetrievedPayload>) => {
        events.push(`${event.payload.query}:${event.payload.chunks.length}:${event.payload.scores.length}`);
      });
      await seedVectors(vectors);

      const input: RagRetrievalInput = {
        query: 'Where is the tavern?',
        queryEmbedding: [1, 0, 0],
        collectionIds: ['kb'],
        topK: 2,
        scoreThreshold: 0.7,
        scope: 'global',
        promptTemplate: 'Context:\n${text}',
      };
      const result: RagRetrievalResult = runtime.retrieve(input);

      expect(result.query).assertEqual('Where is the tavern?');
      expect(result.chunks.length).assertEqual(2);
      expect(result.promptText.indexOf('Context:') >= 0).assertTrue();
      expect(result.promptText.indexOf('old tavern north road') >= 0).assertTrue();
      expect(result.debugTrace.indexOf('kb:chunk-1') >= 0).assertTrue();
      expect(events[0]).assertEqual('Where is the tavern?:2:2');
    });

    it('替换模板中的所有文本占位符', 0, async () => {
      const bus = new EventBus();
      const vectors = new VectorRuntime(new InMemoryFileStore(), bus);
      const runtime = new RagRuntime(vectors, bus);
      await seedVectors(vectors);
      const input: RagRetrievalInput = {
        query: 'Where is the tavern?',
        queryEmbedding: [1, 0, 0],
        collectionIds: ['kb'],
        topK: 1,
        scoreThreshold: 0.7,
        scope: 'global',
        promptTemplate: 'A:${text}\nB:${text}',
      };

      const result = runtime.retrieve(input);

      expect(result.promptText).assertContain('A:old tavern north road');
      expect(result.promptText).assertContain('B:old tavern north road');
    });

    it('builds query from last user message and recent chat window', 0, () => {
      const runtime = new RagRuntime(new VectorRuntime(new InMemoryFileStore(), new EventBus()), new EventBus());
      const messages = new Array<RagChatMessage>();
      messages.push(makeMessage('system', 'rules'));
      messages.push(makeMessage('user', 'first question'));
      messages.push(makeMessage('assistant', 'answer'));
      messages.push(makeMessage('user', 'latest location question'));

      const lastUser = runtime.buildQueryFromLastUserMessage(messages);
      const recent = runtime.buildQueryFromRecentChatWindow(messages, 3);

      expect(lastUser).assertEqual('latest location question');
      expect(recent).assertEqual('first question\nanswer\nlatest location question');
    });
  });
}

async function seedVectors(vectors: VectorRuntime): Promise<void> {
  const collection: VectorCollectionCreateParams = {
    id: 'kb',
    provider: 'openai',
    model: 'text-embedding-3-small',
    dimension: 3,
    metadataJson: '{}',
  };
  await vectors.createCollection(collection);
  await vectors.upsertVector('kb', makeVector('chunk-1', 'doc-1', 'global', [1, 0, 0], 'old tavern north road'));
  await vectors.upsertVector('kb', makeVector('chunk-2', 'doc-2', 'global', [0.8, 0.2, 0], 'stable behind tavern'));
  await vectors.upsertVector('kb', makeVector('chunk-3', 'doc-3', 'chat:1', [0, 1, 0], 'private chat note'));
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

function makeMessage(role: string, content: string): RagChatMessage {
  return {
    role: role,
    content: content,
  };
}
