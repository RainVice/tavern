import { EventBus } from '../runtime/EventBus';
import type {
  SearchDocument,
  SearchDocumentMetadata,
  SearchFilterEntity,
  SearchFilterInput,
  SearchHit,
  SearchIndexedPayload,
  SearchQuery,
  SearchRemovedPayload,
  SearchResult,
} from './SearchModels';

/**
 * 提供搜索索引相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class SearchRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * documents 列表，由当前实例内部维护。
   */
  private documents: Map<string, SearchDocument> = new Map<string, SearchDocument>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建或写入文档，完成持久化后返回可供调用方使用的结果。
   */
  upsertDocument(document: SearchDocument): SearchDocument {
    const copy = this.copyDocument(document);
    this.documents.set(copy.id, copy);
    const payload: SearchIndexedPayload = {
      document: this.copyDocument(copy),
    };
    this.events.publish<SearchIndexedPayload>('search.indexed', payload);
    return this.copyDocument(copy);
  }

  /**
   * 移除文档，用于解除注册、绑定或索引关系。
   * @param documentId 目标文档标识。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  removeDocument(documentId: string): boolean {
    const removed = this.documents.delete(documentId);
    if (removed) {
      const payload: SearchRemovedPayload = {
        documentId: documentId,
      };
      this.events.publish<SearchRemovedPayload>('search.removed', payload);
    }
    return removed;
  }

  /**
   * 按查询条件检索搜索索引数据，并返回匹配结果。
   * @param text 文本内容。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  searchText(text: string): Array<SearchHit> {
    return this.search({
      text: text,
      domains: new Array<string>(),
      tags: new Array<string>(),
      metadataKey: '',
      metadataValue: '',
      limit: 50,
    });
  }

  /**
   * 判断Filter State 值是否满足条件。


   * @returns 条件命中时返回 true，否则返回 false。
   */
  isFilterState(left: string, right: string): boolean {
    return this.normalizeFilterState(left) === this.normalizeFilterState(right);
  }

  /**
   * 判断当前对象是否包含Any Filter 值。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  hasAnyFilter(filter: SearchFilterInput): boolean {
    return filter.search.length > 0 ||
      filter.selectedTags.length > 0 ||
      filter.excludedTags.length > 0 ||
      filter.favoriteOnly ||
      filter.groupOnly ||
      filter.folderOnly;
  }

  /**
   * 读取Entities列表，通常返回副本以避免调用方直接修改内部状态。


   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  filterEntities(entities: Array<SearchFilterEntity>, filter: SearchFilterInput): Array<SearchFilterEntity> {
    const result = new Array<SearchFilterEntity>();
    for (let index = 0; index < entities.length; index += 1) {
      if (this.matchesEntityFilter(entities[index], filter)) {
        result.push(this.copyFilterEntity(entities[index]));
      }
    }
    result.sort((left: SearchFilterEntity, right: SearchFilterEntity) => {
      const leftScore = this.scoreFilterEntity(left, filter.search);
      const rightScore = this.scoreFilterEntity(right, filter.search);
      if (leftScore !== rightScore) {
        return rightScore - leftScore;
      }
      return left.title.localeCompare(right.title);
    });
    return result;
  }

  /**
   * 按查询条件检索搜索索引数据，并返回匹配结果。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  searchByTag(tag: string): Array<SearchHit> {
    return this.search({
      text: '',
      domains: new Array<string>(),
      tags: [tag],
      metadataKey: '',
      metadataValue: '',
      limit: 50,
    });
  }

  /**
   * 按查询条件检索搜索索引数据，并返回匹配结果。
   * @param key 键名。
   * @param value 要保存或比较的字段值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  searchMetadata(key: string, value: string): Array<SearchHit> {
    return this.search({
      text: '',
      domains: new Array<string>(),
      tags: new Array<string>(),
      metadataKey: key,
      metadataValue: value,
      limit: 50,
    });
  }

  /**
   * 按查询条件检索搜索索引数据，并返回匹配结果。
   * @param query 检索条件。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  search(query: SearchQuery): Array<SearchHit> {
    const hits = new Array<SearchHit>();
    const values = Array.from(this.documents.values());
    for (let index = 0; index < values.length; index += 1) {
      const document = values[index];
      if (!this.matchesDomains(document, query.domains)) {
        continue;
      }
      if (!this.matchesTags(document, query.tags)) {
        continue;
      }
      if (!this.matchesMetadata(document, query.metadataKey, query.metadataValue)) {
        continue;
      }
      const score = this.scoreDocument(document, query.text, query.tags, query.metadataKey, query.metadataValue);
      if (score <= 0) {
        continue;
      }
      hits.push(this.toHit(document, score, query.text));
    }
    hits.sort((left: SearchHit, right: SearchHit) => {
      if (left.score !== right.score) {
        return right.score - left.score;
      }
      return left.documentId.localeCompare(right.documentId);
    });
    const limited = this.applyLimit(hits, query.limit);
    const result: SearchResult = {
      query: this.copyQuery(query),
      total: hits.length,
      hits: this.copyHits(limited),
    };
    this.events.publish<SearchResult>('search.result', result);
    return limited;
  }

  /**
   * 读取Documents列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listDocuments(): Array<SearchDocument> {
    const result = new Array<SearchDocument>();
    const values = Array.from(this.documents.values());
    values.sort((left: SearchDocument, right: SearchDocument) => left.id.localeCompare(right.id));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyDocument(values[index]));
    }
    return result;
  }

  /**
   * 检查Domains是否满足当前规则。


   * @returns 条件命中时返回 true，否则返回 false。
   */
  private matchesDomains(document: SearchDocument, domains: Array<string>): boolean {
    if (domains.length === 0) {
      return true;
    }
    for (let index = 0; index < domains.length; index += 1) {
      if (document.domain === domains[index]) {
        return true;
      }
    }
    return false;
  }

  /**
   * 检查EntityFilter是否满足当前规则。


   * @returns 条件命中时返回 true，否则返回 false。
   */
  private matchesEntityFilter(entity: SearchFilterEntity, filter: SearchFilterInput): boolean {
    if (filter.favoriteOnly && !entity.favorite) {
      return false;
    }
    if (filter.groupOnly && !entity.group) {
      return false;
    }
    if (filter.folderOnly && !entity.folder) {
      return false;
    }
    for (let index = 0; index < filter.excludedTags.length; index += 1) {
      if (this.entityHasTag(entity, filter.excludedTags[index])) {
        return false;
      }
    }
    for (let index = 0; index < filter.selectedTags.length; index += 1) {
      if (!this.entityHasTag(entity, filter.selectedTags[index])) {
        return false;
      }
    }
    if (filter.search.length === 0) {
      return true;
    }
    return this.scoreFilterEntity(entity, filter.search) > 0;
  }
  private entityHasTag(entity: SearchFilterEntity, tag: string): boolean {
    for (let index = 0; index < entity.tags.length; index += 1) {
      if (entity.tags[index] === tag) {
        return true;
      }
    }
    return false;
  }
  private scoreFilterEntity(entity: SearchFilterEntity, search: string): number {
    const needle = search.toLowerCase();
    if (needle.length === 0) {
      return 1;
    }
    let score = 0;
    if (entity.title.toLowerCase().indexOf(needle) >= 0) {
      score += 5;
    }
    if (entity.body.toLowerCase().indexOf(needle) >= 0) {
      score += 2;
    }
    for (let index = 0; index < entity.tags.length; index += 1) {
      if (entity.tags[index].toLowerCase().indexOf(needle) >= 0) {
        score += 3;
      }
    }
    return score;
  }

  /**
   * 复制Filter Entity 值，避免外部修改内部状态。
   */
  private copyFilterEntity(entity: SearchFilterEntity): SearchFilterEntity {
    return {
      id: entity.id,
      type: entity.type,
      title: entity.title,
      body: entity.body,
      tags: this.copyStrings(entity.tags),
      favorite: entity.favorite,
      group: entity.group,
      folder: entity.folder,
    };
  }

  /**
   * 规范化Filter State 值，保证后续比较和存储使用一致格式。
   * @param value 要保存或比较的字段值。
   */
  private normalizeFilterState(value: string): string {
    if (value === 'selected') {
      return 'SELECTED';
    }
    if (value === 'excluded') {
      return 'EXCLUDED';
    }
    if (value === 'undefined') {
      return 'UNDEFINED';
    }
    return value;
  }

  /**
   * 检查Tags是否满足当前规则。


   * @returns 条件命中时返回 true，否则返回 false。
   */
  private matchesTags(document: SearchDocument, tags: Array<string>): boolean {
    if (tags.length === 0) {
      return true;
    }
    for (let tagIndex = 0; tagIndex < tags.length; tagIndex += 1) {
      if (!this.hasTag(document, tags[tagIndex])) {
        return false;
      }
    }
    return true;
  }

  /**
   * 检查元数据是否满足当前规则。

   * @param key 键名。
   * @param value 要保存或比较的字段值。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  private matchesMetadata(document: SearchDocument, key: string, value: string): boolean {
    if (key.length === 0) {
      return true;
    }
    for (let index = 0; index < document.metadata.length; index += 1) {
      const item = document.metadata[index];
      if (item.key === key && (value.length === 0 || item.value === value)) {
        return true;
      }
    }
    return false;
  }
  private scoreDocument(
    document: SearchDocument,
    text: string,
    tags: Array<string>,
    metadataKey: string,
    metadataValue: string,
  ): number {
    let score = 0;
    const needle = text.toLowerCase();
    if (needle.length > 0) {
      // 标题。
      const title = document.title.toLowerCase();
      const body = document.body.toLowerCase();
      const path = document.path.toLowerCase();
      if (title.indexOf(needle) >= 0) {
        score += 5;
      }
      if (body.indexOf(needle) >= 0) {
        score += 2;
      }
      if (path.indexOf(needle) >= 0) {
        score += 1;
      }
      for (let index = 0; index < document.tags.length; index += 1) {
        if (document.tags[index].toLowerCase().indexOf(needle) >= 0) {
          score += 3;
        }
      }
      for (let index = 0; index < document.metadata.length; index += 1) {
        if (document.metadata[index].value.toLowerCase().indexOf(needle) >= 0) {
          score += 1;
        }
      }
    }
    if (tags.length > 0) {
      score += tags.length * 3;
    }
    if (metadataKey.length > 0) {
      score += metadataValue.length > 0 ? 2 : 1;
    }
    if (text.length === 0 && tags.length === 0 && metadataKey.length === 0) {
      score = 1;
    }
    return score;
  }

  /**
   * 判断当前对象是否包含Tag 值。


   * @returns 条件命中时返回 true，否则返回 false。
   */
  private hasTag(document: SearchDocument, tag: string): boolean {
    for (let index = 0; index < document.tags.length; index += 1) {
      if (document.tags[index] === tag) {
        return true;
      }
    }
    return false;
  }

  /**
   * 把内部搜索命中转换为对外返回的命中结构。


   * @param queryText 搜索或匹配用的查询文本。
   */
  private toHit(document: SearchDocument, score: number, queryText: string): SearchHit {
    return {
      documentId: document.id,
      domain: document.domain,
      title: document.title,
      snippet: this.makeSnippet(document, queryText),
      score: score,
      path: document.path,
      tags: this.copyStrings(document.tags),
      metadata: this.copyMetadata(document.metadata),
    };
  }
  private makeSnippet(document: SearchDocument, queryText: string): string {
    if (queryText.length === 0) {
      return document.body.length > 80 ? document.body.substring(0, 80) : document.body;
    }
    const lower = document.body.toLowerCase();
    const index = lower.indexOf(queryText.toLowerCase());
    if (index < 0) {
      return document.body.length > 80 ? document.body.substring(0, 80) : document.body;
    }
    const start = Math.max(0, index - 20);
    const end = Math.min(document.body.length, index + queryText.length + 40);
    return document.body.substring(start, end);
  }
  private applyLimit(hits: Array<SearchHit>, limit: number): Array<SearchHit> {
    const max = limit <= 0 ? hits.length : Math.min(limit, hits.length);
    const result = new Array<SearchHit>();
    for (let index = 0; index < max; index += 1) {
      result.push(this.copyHit(hits[index]));
    }
    return result;
  }

  /**
   * 复制Hits 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyHits(hits: Array<SearchHit>): Array<SearchHit> {
    const result = new Array<SearchHit>();
    for (let index = 0; index < hits.length; index += 1) {
      result.push(this.copyHit(hits[index]));
    }
    return result;
  }

  /**
   * 复制Hit 值，避免外部修改内部状态。
   */
  private copyHit(hit: SearchHit): SearchHit {
    return {
      documentId: hit.documentId,
      domain: hit.domain,
      title: hit.title,
      snippet: hit.snippet,
      score: hit.score,
      path: hit.path,
      tags: this.copyStrings(hit.tags),
      metadata: this.copyMetadata(hit.metadata),
    };
  }

  /**
   * 复制Query 值，避免外部修改内部状态。
   * @param query 检索条件。
   */
  private copyQuery(query: SearchQuery): SearchQuery {
    return {
      text: query.text,
      domains: this.copyStrings(query.domains),
      tags: this.copyStrings(query.tags),
      metadataKey: query.metadataKey,
      metadataValue: query.metadataValue,
      limit: query.limit,
    };
  }

  /**
   * 复制Document 值，避免外部修改内部状态。
   */
  private copyDocument(document: SearchDocument): SearchDocument {
    return {
      id: document.id,
      domain: document.domain,
      title: document.title,
      body: document.body,
      tags: this.copyStrings(document.tags),
      path: document.path,
      metadata: this.copyMetadata(document.metadata),
      updatedAt: document.updatedAt,
    };
  }

  /**
   * 复制Metadata 值，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyMetadata(metadata: Array<SearchDocumentMetadata>): Array<SearchDocumentMetadata> {
    const result = new Array<SearchDocumentMetadata>();
    for (let index = 0; index < metadata.length; index += 1) {
      result.push({
        key: metadata[index].key,
        value: metadata[index].value,
      });
    }
    return result;
  }

  /**
   * 复制Strings 列表，避免外部修改内部状态。
   * @param values 待处理的值列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyStrings(values: Array<string>): Array<string> {
    const result = new Array<string>();
    for (let index = 0; index < values.length; index += 1) {
      result.push(values[index]);
    }
    return result;
  }
}
