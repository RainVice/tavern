import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  VectorCollectionCreateParams,
  VectorCollectionRecord,
  VectorDeletedPayload,
  VectorHit,
  VectorQueryParams,
  VectorQueryResult,
  VectorRecord,
  VectorUpsertPayload,
} from './VectorModels';

export class VectorRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private collections: Map<string, VectorCollectionRecord> = new Map<string, VectorCollectionRecord>();
  private vectorsByCollection: Map<string, Array<VectorRecord>> = new Map<string, Array<VectorRecord>>();
  private rootPath: string = 'tavern-data/users/default/vectors/collections';

  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  async createCollection(params: VectorCollectionCreateParams): Promise<VectorCollectionRecord> {
    const now = Date.now();
    const existing = this.collections.get(params.id);
    if (existing !== undefined && existing.dimension !== params.dimension) {
      throw new Error(`Vector collection dimension mismatch: ${params.id}`);
    }
    const collection: VectorCollectionRecord = {
      schemaVersion: 1,
      id: params.id,
      provider: params.provider,
      model: params.model,
      dimension: params.dimension,
      path: this.collectionPath(params.id),
      metadataJson: params.metadataJson,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.collections.set(collection.id, this.copyCollection(collection));
    if (this.vectorsByCollection.get(collection.id) === undefined) {
      this.vectorsByCollection.set(collection.id, new Array<VectorRecord>());
    }
    await this.persistCollection(collection.id);
    return this.copyCollection(collection);
  }

  async upsertVector(collectionId: string, input: VectorRecord): Promise<VectorRecord> {
    const collection = this.requireCollection(collectionId);
    this.assertDimension(collection, input.embedding);

    const now = Date.now();
    const records = this.requireVectors(collectionId);
    const existingIndex = this.findVectorIndex(records, input.id);
    const existing = existingIndex < 0 ? undefined : records[existingIndex];
    const record: VectorRecord = {
      id: input.id,
      documentId: input.documentId,
      scope: input.scope,
      text: input.text,
      embedding: input.embedding.slice(),
      metadataJson: input.metadataJson,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };

    if (existingIndex < 0) {
      records.push(this.copyVector(record));
    } else {
      records[existingIndex] = this.copyVector(record);
    }
    await this.persistCollection(collectionId);

    const payload: VectorUpsertPayload = {
      collectionId: collectionId,
      vector: this.copyVector(record),
    };
    this.events.publish<VectorUpsertPayload>('vector.upserted', payload);
    return this.copyVector(record);
  }

  async listVectors(collectionId: string): Promise<Array<VectorRecord>> {
    const records = this.requireVectors(collectionId);
    return this.copyVectors(records);
  }

  query(params: VectorQueryParams): VectorQueryResult {
    const hits = new Array<VectorHit>();
    for (let collectionIndex = 0; collectionIndex < params.collectionIds.length; collectionIndex += 1) {
      const collectionId = params.collectionIds[collectionIndex];
      const collection = this.collections.get(collectionId);
      if (collection === undefined) {
        continue;
      }
      this.assertDimension(collection, params.embedding);
      const records = this.requireVectors(collectionId);
      for (let vectorIndex = 0; vectorIndex < records.length; vectorIndex += 1) {
        const record = records[vectorIndex];
        if (params.scope.length > 0 && record.scope !== params.scope) {
          continue;
        }
        const score = this.cosineSimilarity(params.embedding, record.embedding);
        if (score >= params.scoreThreshold) {
          const hit: VectorHit = {
            collectionId: collectionId,
            vector: this.copyVector(record),
            score: score,
          };
          hits.push(hit);
        }
      }
    }

    hits.sort((left: VectorHit, right: VectorHit) => right.score - left.score);
    const limited = new Array<VectorHit>();
    const limit = params.topK < hits.length ? params.topK : hits.length;
    for (let index = 0; index < limit; index += 1) {
      limited.push(this.copyHit(hits[index]));
    }
    return {
      hits: limited,
    };
  }

  async deleteByDocument(collectionId: string, documentId: string): Promise<Array<string>> {
    return this.deleteWhere(collectionId, documentId, 'document');
  }

  async deleteByScope(collectionId: string, scope: string): Promise<Array<string>> {
    return this.deleteWhere(collectionId, scope, 'scope');
  }

  private async deleteWhere(collectionId: string, value: string, mode: string): Promise<Array<string>> {
    const records = this.requireVectors(collectionId);
    const kept = new Array<VectorRecord>();
    const deletedIds = new Array<string>();
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      const shouldDelete = mode === 'document' ? record.documentId === value : record.scope === value;
      if (shouldDelete) {
        deletedIds.push(record.id);
      } else {
        kept.push(this.copyVector(record));
      }
    }
    this.vectorsByCollection.set(collectionId, kept);
    await this.persistCollection(collectionId);
    if (deletedIds.length > 0) {
      const payload: VectorDeletedPayload = {
        collectionId: collectionId,
        deletedIds: deletedIds.slice(),
      };
      this.events.publish<VectorDeletedPayload>('vector.deleted', payload);
    }
    return deletedIds;
  }

  private requireCollection(collectionId: string): VectorCollectionRecord {
    const collection = this.collections.get(collectionId);
    if (collection === undefined) {
      throw new Error(`Vector collection not found: ${collectionId}`);
    }
    return collection;
  }

  private requireVectors(collectionId: string): Array<VectorRecord> {
    const records = this.vectorsByCollection.get(collectionId);
    if (records === undefined) {
      throw new Error(`Vector collection not found: ${collectionId}`);
    }
    return records;
  }

  private assertDimension(collection: VectorCollectionRecord, embedding: Array<number>): void {
    if (embedding.length !== collection.dimension) {
      throw new Error(`Vector dimension mismatch: expected ${collection.dimension}, got ${embedding.length}`);
    }
  }

  private cosineSimilarity(left: Array<number>, right: Array<number>): number {
    let dot = 0;
    let leftNorm = 0;
    let rightNorm = 0;
    for (let index = 0; index < left.length; index += 1) {
      dot += left[index] * right[index];
      leftNorm += left[index] * left[index];
      rightNorm += right[index] * right[index];
    }
    if (leftNorm === 0 || rightNorm === 0) {
      return 0;
    }
    return dot / (Math.sqrt(leftNorm) * Math.sqrt(rightNorm));
  }

  private findVectorIndex(records: Array<VectorRecord>, vectorId: string): number {
    for (let index = 0; index < records.length; index += 1) {
      if (records[index].id === vectorId) {
        return index;
      }
    }
    return -1;
  }

  private async persistCollection(collectionId: string): Promise<void> {
    const collection = this.requireCollection(collectionId);
    const records = this.requireVectors(collectionId);
    await this.files.ensureDirectory(collection.path);
    await this.files.writeText(`${collection.path}/metadata.json`, JSON.stringify(collection), true);
    await this.files.writeText(`${collection.path}/vectors.jsonl`, this.serializeVectors(records), true);
  }

  private serializeVectors(records: Array<VectorRecord>): string {
    let output = '';
    for (let index = 0; index < records.length; index += 1) {
      output += JSON.stringify(records[index]);
      output += '\n';
    }
    return output;
  }

  private collectionPath(collectionId: string): string {
    return `${this.rootPath}/${safePathSegment(collectionId, 'collection')}`;
  }

  private copyCollection(collection: VectorCollectionRecord): VectorCollectionRecord {
    return {
      schemaVersion: collection.schemaVersion,
      id: collection.id,
      provider: collection.provider,
      model: collection.model,
      dimension: collection.dimension,
      path: collection.path,
      metadataJson: collection.metadataJson,
      createdAt: collection.createdAt,
      updatedAt: collection.updatedAt,
    };
  }

  private copyVectors(records: Array<VectorRecord>): Array<VectorRecord> {
    const result = new Array<VectorRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.copyVector(records[index]));
    }
    return result;
  }

  private copyVector(record: VectorRecord): VectorRecord {
    return {
      id: record.id,
      documentId: record.documentId,
      scope: record.scope,
      text: record.text,
      embedding: record.embedding.slice(),
      metadataJson: record.metadataJson,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  private copyHit(hit: VectorHit): VectorHit {
    return {
      collectionId: hit.collectionId,
      vector: this.copyVector(hit.vector),
      score: hit.score,
    };
  }
}
