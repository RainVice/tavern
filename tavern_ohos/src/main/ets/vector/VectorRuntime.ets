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
   * 所有向量集合的映射表，key 为集合 ID。
   */
  private collections: Map<string, VectorCollectionRecord> = new Map<string, VectorCollectionRecord>();
  /**
   * 每个集合下的向量记录映射表，key 为集合 ID。
   */
  private vectorsByCollection: Map<string, Array<VectorRecord>> = new Map<string, Array<VectorRecord>>();
  /**
   * 向量数据在文件系统中的根路径。
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
   * 创建新的向量集合，包含元数据和向量维度信息。如果集合已存在则跳过新建。在初始化 RAG 或语义搜索功能时调用。
   * @param params 创建集合所需的参数，包含 ID、provider、model 和 dimension，用于构造完整的集合记录。
   * @returns 新建或已有集合记录的深拷贝，供后续插入向量使用。
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
   * 插入或更新向量记录。如果 ID 已存在则更新，否则新建。在语义索引构建和更新流程中调用。
   * @param collectionId 目标集合标识，指定要写入的集合。
   * @param input 待写入的向量数据，包含文本、嵌入向量和元数据。
   * @returns 插入或更新后的向量记录深拷贝，用于确认写入结果。
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
   * 列出指定集合中的所有向量记录。在集合内容查看或调试时调用。
   * @param collectionId 目标集合标识，指定要列出向量的集合。
   * @returns 向量记录深拷贝列表，供遍历或展示使用。
   */
  async listVectors(collectionId: string): Promise<Array<VectorRecord>> {
    const records = this.requireVectors(collectionId);
    return this.copyVectors(records);
  }

  /**
   * 在多集合中执行向量相似性查询，按余弦相似度排序并取 top-k 结果。在 RAG 检索和语义搜索流程中调用。
   * @param params 查询参数，包含集合列表、查询向量、topK 和得分阈值，用于控制查询范围和过滤条件。
   * @returns 查询结果，包含命中的向量列表，供后续用于上下文构建或提示词增强。
   */
  query(params: VectorQueryParams): VectorQueryResult {
    const hits = new Array<VectorHit>();
    for (let collectionIndex = 0; collectionIndex < params.collectionIds.length; collectionIndex += 1) {
      // 遍历每个查询集合。
      const collectionId = params.collectionIds[collectionIndex];
      const collection = this.collections.get(collectionId);
      if (collection === undefined) {
        continue;
      }
      this.assertDimension(collection, params.embedding);
      const records = this.requireVectors(collectionId);
      for (let vectorIndex = 0; vectorIndex < records.length; vectorIndex += 1) {
        const record = records[vectorIndex];
        // 按作用域过滤。
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
   * 根据文档 ID 删除指定集合中的向量记录。在文档更新或删除时调用，清理旧向量数据。
   * @param collectionId 目标集合标识，指定要删除向量的集合。
   * @param documentId 文档标识，匹配所有关联该文档的向量并删除。
   * @returns 被删除的向量 ID 列表，供调用方确认删除结果。
   */
  async deleteByDocument(collectionId: string, documentId: string): Promise<Array<string>> {
    return this.deleteWhere(collectionId, documentId, 'document');
  }

  /**
   * 根据作用域删除指定集合中的向量记录。在作用域生命周期结束（如删除角色或聊天）时调用，清理相关向量。
   * @param collectionId 目标集合标识，指定要删除向量的集合。
   * @param scope 作用域名称，匹配所有属于该作用域的向量并删除。
   * @returns 被删除的向量 ID 列表，供调用方确认删除结果。
   */
  async deleteByScope(collectionId: string, scope: string): Promise<Array<string>> {
    return this.deleteWhere(collectionId, scope, 'scope');
  }

  /**
   * 根据条件（文档 ID 或作用域）删除向量记录，并持久化更新。
   * @param collectionId 目标集合标识。
   * @param value 匹配值（文档 ID 或作用域名）。
   * @param mode 匹配模式："document" 按文档 ID 匹配，"scope" 按作用域匹配。
   * @returns 被删除的向量 ID 列表。
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
   * 根据集合 ID 查找集合，不存在时抛出异常。
   * @param collectionId 集合标识。
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
   * 根据集合 ID 获取其向量列表，不存在时抛出异常。
   * @param collectionId 集合标识。
   * @returns 向量记录数组。
   */
  private requireVectors(collectionId: string): Array<VectorRecord> {
    const records = this.vectorsByCollection.get(collectionId);
    if (records === undefined) {
      throw new Error(`Vector collection not found: ${collectionId}`);
    }
    return records;
  }

  /**
   * 校验向量的维度是否与集合定义一致。
   * @param collection 集合记录。
   * @param embedding 待校验的向量数据。
   */
  private assertDimension(collection: VectorCollectionRecord, embedding: Array<number>): void {
    if (embedding.length !== collection.dimension) {
      throw new Error(`Vector dimension mismatch: expected ${collection.dimension}, got ${embedding.length}`);
    }
  }

  /**
   * 计算两个向量之间的余弦相似度。
   * @param left 左侧向量。
   * @param right 右侧向量。
   * @returns 余弦相似度得分（0-1 之间）。
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
   * 在向量列表中查找指定 ID 的索引位置。
   * @param records 向量记录列表。
   * @param vectorId 要查找的向量 ID。
   * @returns 索引位置，未找到时返回 -1。
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
   * 将集合元数据和向量数据持久化到文件系统。
   * @param collectionId 集合标识。
   */
  private async persistCollection(collectionId: string): Promise<void> {
    const collection = this.requireCollection(collectionId);
    const records = this.requireVectors(collectionId);
    await this.files.ensureDirectory(collection.path);
    await this.files.writeText(`${collection.path}/metadata.json`, JSON.stringify(collection), true);
    await this.files.writeText(`${collection.path}/vectors.jsonl`, this.serializeVectors(records), true);
  }

  /**
   * 将向量记录列表序列化为 JSONL 格式字符串。
   * @param records 向量记录列表。
   * @returns JSONL 格式的字符串，每条记录一行。
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
   * 生成集合在文件系统中的存储路径。
   * @param collectionId 集合标识。
   * @returns 文件系统路径。
   */
  private collectionPath(collectionId: string): string {
    return `${this.rootPath}/${safePathSegment(collectionId, 'collection')}`;
  }

  /**
   * 深拷贝集合记录，防止外部修改内部状态。
   * @param collection 集合记录。
   * @returns 集合记录深拷贝。
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
   * 深拷贝向量记录列表。
   * @param records 向量记录列表。
   * @returns 向量记录深拷贝列表。
   */
  private copyVectors(records: Array<VectorRecord>): Array<VectorRecord> {
    const result = new Array<VectorRecord>();
    for (let index = 0; index < records.length; index += 1) {
      result.push(this.copyVector(records[index]));
    }
    return result;
  }

  /**
   * 深拷贝向量记录，防止外部修改内部状态。
   * @param record 向量记录。
   * @returns 向量记录深拷贝。
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
   * 深拷贝命中结果，防止外部修改内部状态。
   * @param hit 命中记录。
   * @returns 命中记录深拷贝。
   */
  private copyHit(hit: VectorHit): VectorHit {
    return {
      collectionId: hit.collectionId,
      vector: this.copyVector(hit.vector),
      score: hit.score,
    };
  }
}
