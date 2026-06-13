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

/**
 * 提供向量检索相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class VectorRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * collections 列表，由当前实例内部维护。
   */
  private collections: Map<string, VectorCollectionRecord> = new Map<string, VectorCollectionRecord>();
  /**
   * vectors By Collection 值，由当前实例内部维护。
   */
  private vectorsByCollection: Map<string, Array<VectorRecord>> = new Map<string, Array<VectorRecord>>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/vectors/collections';

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 创建新的集合记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 创建或写入向量，完成持久化后返回可供调用方使用的结果。
   * @param collectionId 目标集合标识。
   * @param input 待处理的输入对象。
   */
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

  /**
   * 读取Vectors列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param collectionId 目标集合标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async listVectors(collectionId: string): Promise<Array<VectorRecord>> {
    const records = this.requireVectors(collectionId);
    return this.copyVectors(records);
  }

  /**
   * 执行 query 的内部处理步骤，供当前模块复用。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  query(params: VectorQueryParams): VectorQueryResult {
    const hits = new Array<VectorHit>();
    for (let collectionIndex = 0; collectionIndex < params.collectionIds.length; collectionIndex += 1) {
      // collection 标识。
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

  /**
   * 删除指定文档，并清理相关索引或资源引用。
   * @param collectionId 目标集合标识。
   * @param documentId 目标文档标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async deleteByDocument(collectionId: string, documentId: string): Promise<Array<string>> {
    return this.deleteWhere(collectionId, documentId, 'document');
  }

  /**
   * 删除指定ByScope，并清理相关索引或资源引用。
   * @param collectionId 目标集合标识。
   * @param scope 绑定或查询使用的作用域。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async deleteByScope(collectionId: string, scope: string): Promise<Array<string>> {
    return this.deleteWhere(collectionId, scope, 'scope');
  }

  /**
   * 删除指定Where，并清理相关索引或资源引用。
   * @param collectionId 目标集合标识。
   * @param value 要保存或比较的字段值。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 读取必须存在的Collection 值，缺失时抛出错误。
   * @param collectionId 目标集合标识。
   */
  private requireCollection(collectionId: string): VectorCollectionRecord {
    const collection = this.collections.get(collectionId);
    if (collection === undefined) {
      throw new Error(`Vector collection not found: ${collectionId}`);
    }
    return collection;
  }

  /**
   * 读取必须存在的Vectors 列表，缺失时抛出错误。
   * @param collectionId 目标集合标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 在当前集合中查找Vector Index 值，未命中时返回空值或默认位置。
   * @param records 记录副本列表。
   * @param vectorId 目标向量标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 生成Vectors输出，供请求发送、导出或界面展示使用。
   * @param records 记录副本列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 复制Collection 值，避免外部修改内部状态。
   */
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

  /**
   * 复制Vectors 列表，避免外部修改内部状态。
   * @param records 记录副本列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyVectors(records: Array<VectorRecord>): Array<VectorRecord> {
    const result = new Array<VectorRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.copyVector(records[index]));
    }
    return result;
  }

  /**
   * 复制Vector 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
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

  /**
   * 复制Hit 值，避免外部修改内部状态。
   */
  private copyHit(hit: VectorHit): VectorHit {
    return {
      collectionId: hit.collectionId,
      vector: this.copyVector(hit.vector),
      score: hit.score,
    };
  }
}
