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
 * 在对话流程中由外部模块调用以索引文档（upsertDocument）、全文搜索（search / searchText）和标签匹配筛选（filterEntities）。
 */
export class SearchRuntime {
  private events: EventBus;
  private documents: Map<string, SearchDocument> = new Map<string, SearchDocument>();

  /**
   * 初始化当前运行时实例，绑定事件总线用于在文档索引/移除/搜索完成时发布事件。
   * @param events 事件总线实例，用于发布 "search.indexed"、"search.removed"、"search.result" 事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 写入或更新一个搜索文档到内部索引，覆盖已有 ID 的文档并发布索引事件。
   * 由外部模块（如人物保存、聊天记录保存时）调用，将新文档或更新后的文档推送到搜索索引中。
   * @param document 待索引的文档对象，如果该 ID 已存在则覆盖更新。
   * @returns 已存储的文档对象副本。
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
   * 从索引中移除指定文档，并发布移除事件。
   * 由外部模块（如人物删除、聊天记录删除时）调用，清理搜索索引中的对应条目。
   * @param documentId 要移除的文档标识，对应 upsertDocument 时使用的 id。
   * @returns 文档存在并被成功移除时返回 true，否则返回 false。
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
   * 按文本内容搜索文档，返回匹配的搜索结果列表。
   * 由 UI 层或 ProviderRuntime 在用户输入搜索关键字时调用，快速查询索引中的全部文档。
   * @param text 搜索关键字文本，用于与文档标题、正文、标签等进行模糊匹配（权重体系：标题5分/标签3分/正文2分/路径1分/元数据1分）。
   * @returns 匹配到的搜索结果列表副本，按相关性降序排列，默认最多返回50条。
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
   * 判断两个过滤状态值是否相等（规范化后比较）。
   * 由 UI 层在检查过滤条件是否发生变化时调用，避免不必要的 UI 刷新。
   * @param left 左侧过滤状态值。
   * @param right 右侧过滤状态值。
   * @returns 规范化后相等返回 true，否则返回 false。
   */
  isFilterState(left: string, right: string): boolean {
    return this.normalizeFilterState(left) === this.normalizeFilterState(right);
  }

  /**
   * 判断过滤输入条件中是否含有任何有效的筛选条件。
   * 由 UI 层在判断是否启用过滤模式时调用，辅助决定是否显示筛选结果视图。
   * @param filter 用户提供的过滤输入条件，来自 UI 搜索/筛选控件的当前状态。
   * @returns 只要有任一筛选条件（搜索文本、选中/排除标签、收藏/群组/文件夹限定）有效则返回 true。
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
   * 根据过滤条件筛选实体列表，匹配的实体按相关度降序排列。
   * 由 UI 层在用户调整筛选控件（搜索框、标签选择器、收藏/群组/文件夹开关）时调用，
   * 对传入的实体列表进行多条件综合过滤和评分排序。
   * @param entities 待筛选的实体列表，通常来自人物或聊天列表的数据源。
   * @param filter 过滤条件，来自 UI 筛选控件的当前状态，包含关键字、标签和类型限定。
   * @returns 匹配的实体副本列表，按评分降序、标题字母序排列。
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
   * 按标签搜索文档，返回所有匹配的搜索结果。
   * 由外部模块在需要查找特定标签下所有文档时调用（如点击标签后列出该标签关联的所有文档）。
   * @param tag 要搜索的标签名称，在 matchesTags 中作为文档必须包含的条件。
   * @returns 匹配的搜索结果列表副本，默认最多返回50条。
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
   * 按元数据键值对搜索文档，返回所有匹配的搜索结果。
   * 由外部模块在需要根据文档的附加属性（如源文件路径、作者等）搜索时调用。
   * @param key 元数据的键名，与文档 metadata 数组中的 key 字段进行精确匹配。
   * @param value 元数据的值，与文档 metadata 数组中的 value 字段进行精确匹配。
   * @returns 匹配的搜索结果列表副本，默认最多返回50条。
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
   * 按查询条件搜索文档，对每个文档计算匹配分数，返回排序后的结果。
   * 核心搜索方法，由 searchText、searchByTag、searchMetadata 内部调用，也可被外部模块直接调用。
   * 搜索时依次对文档执行领域过滤、标签过滤、元数据过滤、评分，最后按分数排序截断。
   * @param query 搜索查询条件，包含文本、领域、标签、元数据等限定和结果数量上限。
   * @returns 匹配的搜索结果列表副本，按分数降序排列，受 query.limit 限制。
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
   * 返回索引中所有文档的列表，按 ID 字母序排列。
   * 由外部模块在需要迭代所有已索引文档时调用（如全量备份、数据迁移、展示文档列表）。
   * @returns 所有文档的副本列表。
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
   * 检查文档的领域是否包含在给定的领域列表中（空列表表示不限制）。
   * @param document 待检查的文档。
   * @param domains 限定的领域列表。
   * @returns 领域匹配或 domains 为空时返回 true。
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
   * 检查实体是否满足筛选条件：收藏状态、群组/文件夹类型、标签匹配、文本搜索。
   * @param entity 待检查的实体。
   * @param filter 用户提供的过滤条件。
   * @returns 完全匹配所有条件时返回 true。
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
   * 深拷贝实体过滤对象，防止外部修改内部状态。
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
   * 将过滤状态值规范化为大写形式，用于统一比较。
   * @param value 原始过滤状态值（如 "selected"、"excluded"、"undefined"）。
   * @returns 规范化后的大写字符串。
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
   * 检查文档是否包含指定列表中的所有标签（空列表表示不限制）。
   * @param document 待检查的文档。
   * @param tags 必须包含的标签列表。
   * @returns 文档包含所有标签时返回 true。
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
   * 检查文档是否包含指定键值对的元数据（空 key 表示不限制）。
   * @param document 待检查的文档。
   * @param key 元数据键名。
   * @param value 元数据值，为空时只匹配键名。
   * @returns 元数据匹配时返回 true。
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
   * 检查文档是否包含指定标签。
   * @param document 待检查的文档。
   * @param tag 要检查的标签名。
   * @returns 包含该标签时返回 true。
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
   * 将文档和得分转换为对外暴露的搜索结果结构。
   * @param document 匹配到的原始文档。
   * @param score 计算得到的匹配分数。
   * @param queryText 原始搜索文本，用于截取摘要片段。
   * @returns 包装后的 SearchHit 对象。
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
   * 深拷贝搜索结果列表。
   * @param hits 待拷贝的搜索结果列表。
   * @returns 新的搜索结果列表副本。
   */
  private copyHits(hits: Array<SearchHit>): Array<SearchHit> {
    const result = new Array<SearchHit>();
    for (let index = 0; index < hits.length; index += 1) {
      result.push(this.copyHit(hits[index]));
    }
    return result;
  }

  /**
   * 深拷贝单个搜索结果对象。
   * @param hit 待拷贝的搜索结果。
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
   * 深拷贝搜索查询对象。
   * @param query 待拷贝的查询条件。
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
   * 深拷贝文档对象。
   * @param document 待拷贝的文档。
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
   * 深拷贝元数据条目列表。
   * @param metadata 待拷贝的元数据列表。
   * @returns 新的元数据列表副本。
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
   * 深拷贝字符串数组。
   * @param values 待拷贝的字符串数组。
   * @returns 新的字符串数组副本。
   */
  private copyStrings(values: Array<string>): Array<string> {
    const result = new Array<string>();
    for (let index = 0; index < values.length; index += 1) {
      result.push(values[index]);
    }
    return result;
  }
}
