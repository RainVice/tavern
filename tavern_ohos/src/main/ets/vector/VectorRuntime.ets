import { EventBus } from '../runtime/EventBus';
import type { TavernScope } from '../contracts/PublicContracts';
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

type VectorDeleteMode = 'document' | 'scope';

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
   * 向量集合记录映射表，以 collectionId 为键维护所有已创建集合的内存索引。
   */
  private collections: Map<string, VectorCollectionRecord> = new Map<string, VectorCollectionRecord>();
  /**
   * 各集合的向量记录列表，以 collectionId 为键，值为该集合的所有向量记录。
   */
  private vectorsByCollection: Map<string, Array<VectorRecord>> = new Map<string, Array<VectorRecord>>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/vectors/collections';

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器，用于集合和向量的持久化。
   * @param events 事件总线，用于发布 upsert/deleted 事件。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 创建新的集合记录，写入存储并返回副本。若集合已存在且维度不一致则抛出错误。
   * @param params 集合创建参数。
   * @returns 创建或更新后的集合记录副本。
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
   * 在指定集合中写入或更新向量记录，完成持久化后发布 vector.upserted 事件。
   * @param collectionId 目标集合标识。
   * @param input 待写入或更新的向量记录。
   * @returns 写入后的向量记录副本。
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
   * 读取指定集合中的向量记录列表，返回副本。
   * @param collectionId 目标集合标识。
   * @returns 向量记录列表的深拷贝副本。
   */
  async listVectors(collectionId: string): Promise<Array<VectorRecord>> {
    const records = this.requireVectors(collectionId);
    return this.copyVectors(records);
  }

  /**
   * 执行向量检索（余弦相似度），按分数降序排序并截断至 topK 条。
   * @param params 查询参数，包含目标集合、向量、topK、阈值和作用域。
   * @returns 排序和截断后的匹配结果集。
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
   * 按文档标识删除指定集合中的所有向量记录，并发布 vector.deleted 事件。
   * @param collectionId 目标集合标识。
   * @param documentId 目标文档标识。
   * @returns 被删除的向量记录标识列表。
   */
  async deleteByDocument(collectionId: string, documentId: string): Promise<Array<string>> {
    return this.deleteWhere(collectionId, documentId, 'document');
  }

  /**
   * 按作用域删除指定集合中的所有向量记录，并发布 vector.deleted 事件。
   * @param collectionId 目标集合标识。
   * @param scope 查询过滤使用的作用域。
   * @returns 被删除的向量记录标识列表。
   */
  async deleteByScope(collectionId: string, scope: TavernScope): Promise<Array<string>> {
    return this.deleteWhere(collectionId, scope, 'scope');
  }

  /**
   * 按文档标识或作用域删除向量记录的内部实现。
   * @param collectionId 目标集合标识。
   * @param value 按文档模式时为 documentId，按作用域模式时为 scope 值。
   * @param mode 'document' 按 documentId 匹配，'scope' 按 scope 匹配。
   * @returns 被删除的向量记录标识列表。
   */
  private async deleteWhere(collectionId: string, value: string, mode: VectorDeleteMode): Promise<Array<string>> {
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
   * 获取指定集合，不存在时抛出错误。
   * @param collectionId 目标集合标识。
   * @returns 集合记录。
   */
  private requireCollection(collectionId: string): VectorCollectionRecord {
    const collection = this.collections.get(collectionId);
    if (collection === undefined) {
      throw new Error(`Vector collection not found: ${collectionId}`);
    }
    return collection;
  }

  /**
   * 获取指定集合的向量列表，集合不存在时抛出错误。
   * @param collectionId 目标集合标识。
   * @returns 向量记录列表。
   */
  private requireVectors(collectionId: string): Array<VectorRecord> {
    const records = this.vectorsByCollection.get(collectionId);
    if (records === undefined) {
      throw new Error(`Vector collection not found: ${collectionId}`);
    }
    return records;
  }
  /**
   * 校验向量维度与集合声明的维度是否一致，不一致则抛出错误。
   */
  private assertDimension(collection: VectorCollectionRecord, embedding: Array<number>): void {
    if (embedding.length !== collection.dimension) {
      throw new Error(`Vector dimension mismatch: expected ${collection.dimension}, got ${embedding.length}`);
    }
  }

  /**
   * 计算两个向量的余弦相似度。
   * @param left 左侧向量。
   * @param right 右侧向量。
   * @returns 余弦相似度值（-1 到 1），任一向量为零向量时返回 0。
   */
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
   * 在当前集合的向量列表中查找指定标识的索引位置。
   * @param records 向量记录列表。
   * @param vectorId 目标向量标识。
   * @returns 找到时返回索引，未找到返回 -1。
   */
  private findVectorIndex(records: Array<VectorRecord>, vectorId: string): number {
    for (let index = 0; index < records.length; index += 1) {
      if (records[index].id === vectorId) {
        return index;
      }
    }
    return -1;
  }
  /**
   * 将集合元数据和向量数据持久化到文件存储。
   * @param collectionId 目标集合标识。
   */
  private async persistCollection(collectionId: string): Promise<void> {
    const collection = this.requireCollection(collectionId);
    const records = this.requireVectors(collectionId);
    await this.files.ensureDirectory(collection.path);
    await this.files.writeText(`${collection.path}/metadata.json`, JSON.stringify(collection), true);
    await this.files.writeText(`${collection.path}/vectors.jsonl`, this.serializeVectors(records), true);
  }

  /**
   * 将向量记录序列化为 JSONL 格式文本，每行一条 JSON 记录。
   * @param records 向量记录列表。
   * @returns JSONL 格式的字符串。
   */
  private serializeVectors(records: Array<VectorRecord>): string {
    let output = '';
    for (let index = 0; index < records.length; index += 1) {
      output += JSON.stringify(records[index]);
      output += '\n';
    }
    return output;
  }

  /**
   * 根据集合标识生成持久化存储路径。
   * @param collectionId 集合标识。
   * @returns 集合数据的存储路径字符串。
   */
  private collectionPath(collectionId: string): string {

  /**
   * 复制集合记录，避免外部修改内部状态。
   * @param collection 要复制的集合记录。
   * @returns 集合记录的深拷贝。
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
   * 复制向量记录列表，避免外部修改内部状态。
   * @param records 要复制的向量记录列表。
   * @returns 向量记录列表的深拷贝。
   */
  private copyVectors(records: Array<VectorRecord>): Array<VectorRecord> {
    const result = new Array<VectorRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.copyVector(records[index]));
    }
    return result;
  }

  /**
   * 复制单条向量记录（含 embedding 深拷贝），避免外部修改内部状态。
   * @param record 要复制的向量记录。
   * @returns 向量记录的深拷贝。
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
   * 复制单条命中结果（含向量记录的深拷贝），避免外部修改内部状态。
   * @param hit 要复制的命中结果。
   * @returns 命中结果的深拷贝。
   */
  private copyHit(hit: VectorHit): VectorHit {
    return {
      collectionId: hit.collectionId,
      vector: this.copyVector(hit.vector),
      score: hit.score,
    };
  }
}
