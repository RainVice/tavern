import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  WorldBook,
  WorldBookIndex,
  WorldBookIndexEntry,
  WorldInfoActivation,
  WorldInfoActivationPayload,
  WorldInfoEntry,
  WorldInfoEntryCreateParams,
  WorldInfoEntryUpdateParams,
  WorldInfoEventPayload,
  WorldInfoImportData,
  WorldInfoMatch,
} from './WorldInfoModels';

/**
 * 描述世界书模块在运行时交换的数据结构。
 */
interface WorldInfoActivationCandidate {
  /**
   * 本轮激活命中的世界书条目。
   */
  entry: WorldInfoEntry;
  /**
   * 条目命中的关键词和来源信息。
   */
  match: WorldInfoMatch;
}

/**
 * 提供世界书相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class WorldInfoRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 数据根路径。
   */
  private rootPath: string;
  /**
   * 用户标识。
   */
  private userId: string;

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   * @param rootPath 数据根路径。
   * @param userId 用户标识。
   */
  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 创建新的世界书记录，写入存储并返回副本。
   * @param name 显示名称或注册名称。
   * @returns 更新或读取后的记录副本。
   */
  async createWorldBook(name: string): Promise<WorldBook> {
    const index = await this.readIndex();
    const id = `worldbook-${index.nextId}`;
    index.nextId += 1;
    const now = Date.now();
    const book: WorldBook = {
      schemaVersion: 1,
      id: id,
      name: name,
      nextEntryId: 1,
      entries: new Array<WorldInfoEntry>(),
      createdAt: now,
      updatedAt: now,
    };
    await this.writeWorldBook(book);
    index.items.push(this.toIndexEntry(book));
    await this.writeIndex(index);
    this.publishWorldBookEvent('worldinfo.created', book);
    return this.copyBook(book);
  }

  /**
   * 读取世界书索引列表，用于世界书管理页快速展示。
   * @returns 世界书索引项副本列表。
   */
  async listWorldBooks(): Promise<Array<WorldBookIndexEntry>> {
    const index = await this.readIndex();
    return this.copyIndexEntries(index.items);
  }

  /**
   * 读取指定世界书，不存在时抛出错误。
   * @param worldBookId 世界书标识。
   * @returns 更新或读取后的记录副本。
   */
  async getWorldBook(worldBookId: string): Promise<WorldBook> {
    const exists = await this.files.exists(this.worldBookPath(worldBookId));
    if (!exists) {
      throw new Error(`WorldBook not found: ${worldBookId}`);
    }
    const store = new JsonStore<WorldBook>(this.files, this.worldBookPath(worldBookId));
    return this.copyBook(await store.read(this.defaultWorldBook(worldBookId)));
  }

  /**
   * 删除指定世界书文件，并从世界书索引中移除该记录。
   * @param worldBookId 世界书标识。
   */
  async deleteWorldBook(worldBookId: string): Promise<void> {
    const book = await this.getWorldBook(worldBookId);
    await this.files.delete(this.worldBookPath(worldBookId));
    const index = await this.readIndex();
    const remaining = new Array<WorldBookIndexEntry>();
    for (let itemIndex = 0; itemIndex < index.items.length; itemIndex += 1) {
      if (index.items[itemIndex].id !== worldBookId) {
        remaining.push(index.items[itemIndex]);
      }
    }
    index.items = remaining;
    await this.writeIndex(index);
    this.publishWorldBookEvent('worldinfo.deleted', book);
  }

  /**
   * 在指定世界书中创建条目，并发布 worldinfo.updated 事件。
   * @param worldBookId 世界书标识。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 新建条目的副本。
   */
  async createEntry(worldBookId: string, params: WorldInfoEntryCreateParams): Promise<WorldInfoEntry> {
    const book = await this.getWorldBook(worldBookId);
    const now = Date.now();
    const entry: WorldInfoEntry = {
      id: `entry-${book.nextEntryId}`,
      uid: book.nextEntryId,
      comment: params.comment,
      keys: params.keys.slice(),
      secondaryKeys: params.secondaryKeys.slice(),
      content: params.content,
      constant: params.constant,
      selective: params.selective,
      enabled: params.enabled,
      insertionOrder: params.insertionOrder,
      position: params.position,
      caseSensitive: params.caseSensitive,
      createdAt: now,
      updatedAt: now,
    };
    book.nextEntryId += 1;
    book.entries.push(this.copyEntry(entry));
    book.updatedAt = now;
    await this.writeWorldBook(book);
    await this.replaceIndexEntry(book);
    this.publishWorldBookEvent('worldinfo.updated', book);
    return this.copyEntry(entry);
  }

  /**
   * 更新指定条目，写回存储并按需发布变更事件。
   * @param worldBookId 世界书标识。
   * @param entryId 条目标识。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  async updateEntry(worldBookId: string, entryId: string, params: WorldInfoEntryUpdateParams): Promise<WorldInfoEntry> {
    const book = await this.getWorldBook(worldBookId);
    let updated: WorldInfoEntry | undefined = undefined;
    for (let index = 0; index < book.entries.length; index += 1) {
      if (book.entries[index].id === entryId) {
        const entry = book.entries[index];
        entry.comment = params.comment;
        entry.keys = params.keys.slice();
        entry.secondaryKeys = params.secondaryKeys.slice();
        entry.content = params.content;
        entry.constant = params.constant;
        entry.selective = params.selective;
        entry.enabled = params.enabled;
        entry.insertionOrder = params.insertionOrder;
        entry.position = params.position;
        entry.caseSensitive = params.caseSensitive;
        entry.updatedAt = Date.now();
        updated = entry;
      }
    }
    if (updated === undefined) {
      throw new Error(`WorldInfo entry not found: ${worldBookId}/${entryId}`);
    }
    book.updatedAt = Date.now();
    await this.writeWorldBook(book);
    await this.replaceIndexEntry(book);
    this.publishWorldBookEvent('worldinfo.updated', book);
    return this.copyEntry(updated);
  }

  /**
   * 删除指定世界书条目，并更新世界书索引里的条目数量。
   * @param worldBookId 世界书标识。
   * @param entryId 条目标识。
   */
  async deleteEntry(worldBookId: string, entryId: string): Promise<void> {
    const book = await this.getWorldBook(worldBookId);
    const remaining = new Array<WorldInfoEntry>();
    let removed = false;
    for (let index = 0; index < book.entries.length; index += 1) {
      if (book.entries[index].id !== entryId) {
        remaining.push(book.entries[index]);
      } else {
        removed = true;
      }
    }
    if (!removed) {
      throw new Error(`WorldInfo entry not found: ${worldBookId}/${entryId}`);
    }
    book.entries = remaining;
    book.updatedAt = Date.now();
    await this.writeWorldBook(book);
    await this.replaceIndexEntry(book);
    this.publishWorldBookEvent('worldinfo.updated', book);
  }

  /**
   * 导出世界书 JSON 字符串，用于备份、迁移或与 SillyTavern 数据互通。
   * @param worldBookId 世界书标识。
   * @returns 可持久化或可传输的导出内容。
   */
  async exportWorldBookJson(worldBookId: string): Promise<string> {
    const book = await this.getWorldBook(worldBookId);
    return JSON.stringify(book);
  }

  /**
   * 从外部数据导入World Book JSON 字符串，转换为当前运行时的数据结构。
   * @param json 外部传入的 JSON 字符串。
   * @param name 显示名称或注册名称。
   * @returns 更新或读取后的记录副本。
   */
  async importWorldBookJson(json: string, name: string): Promise<WorldBook> {
    const imported = JSON.parse(json) as WorldInfoImportData;
    const index = await this.readIndex();
    const id = `worldbook-${index.nextId}`;
    index.nextId += 1;
    const now = Date.now();
    const entries = this.copyEntries(imported.entries);
    const book: WorldBook = {
      schemaVersion: 1,
      id: id,
      name: name,
      nextEntryId: this.nextEntryIdAfterImport(imported.nextEntryId, entries),
      entries: entries,
      createdAt: now,
      updatedAt: now,
    };
    await this.writeWorldBook(book);
    index.items.push(this.toIndexEntry(book));
    await this.writeIndex(index);
    this.publishWorldBookEvent('worldinfo.imported', book);
    return this.copyBook(book);
  }

  /**
   * 更新条目状态，必要时写回存储并发布对应事件。
   * @param worldBookIds 目标世界书标识列表。
   * @param messages 消息列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async activateEntries(worldBookIds: Array<string>, messages: Array<string>): Promise<WorldInfoActivation> {
    const buffer = messages.join('\n');
    const candidates = new Array<WorldInfoActivationCandidate>();
    for (let bookIndex = 0; bookIndex < worldBookIds.length; bookIndex += 1) {
      const book = await this.getWorldBook(worldBookIds[bookIndex]);
      for (let entryIndex = 0; entryIndex < book.entries.length; entryIndex += 1) {
        const entry = book.entries[entryIndex];
        const match = this.matchEntry(book.id, entry, buffer);
        if (match.entryId.length > 0) {
          candidates.push({
            entry: this.copyEntry(entry),
            match: this.copyMatch(match),
          });
        }
      }
    }
    candidates.sort((left: WorldInfoActivationCandidate, right: WorldInfoActivationCandidate) => {
      return left.entry.insertionOrder - right.entry.insertionOrder;
    });
    const activated = new Array<WorldInfoEntry>();
    const matches = new Array<WorldInfoMatch>();
    for (let index = 0; index < candidates.length; index += 1) {
      activated.push(this.copyEntry(candidates[index].entry));
      matches.push(this.copyMatch(candidates[index].match));
    }
    const activation: WorldInfoActivation = {
      entries: this.copyEntries(activated),
      matches: this.copyMatches(matches),
      promptText: this.buildPromptText(activated),
    };
    const payload: WorldInfoActivationPayload = {
      worldBookIds: worldBookIds.slice(),
      entries: this.copyEntries(activated),
      matches: this.copyMatches(matches),
    };
    this.events.publish<WorldInfoActivationPayload>('worldinfo.activated', payload);
    return activation;
  }
  private matchEntry(worldBookId: string, entry: WorldInfoEntry, buffer: string): WorldInfoMatch {
    if (!entry.enabled) {
      return this.emptyMatch();
    }
    if (entry.constant) {
      return {
        worldBookId: worldBookId,
        entryId: entry.id,
        key: '',
      };
    }
    const primaryKey = this.findFirstMatch(entry.keys, buffer, entry.caseSensitive);
    if (primaryKey.length === 0) {
      return this.emptyMatch();
    }
    if (entry.selective) {
      const secondaryKey = this.findFirstMatch(entry.secondaryKeys, buffer, entry.caseSensitive);
      if (secondaryKey.length === 0) {
        return this.emptyMatch();
      }
    }

    return {
      worldBookId: worldBookId,
      entryId: entry.id,
      key: primaryKey,
    };
  }

  /**
   * 在当前集合中查找First Match 值，未命中时返回空值或默认位置。



   * @returns 条件命中时返回 true，否则返回 false。
   */
  private findFirstMatch(keys: Array<string>, buffer: string, caseSensitive: boolean): string {
    const haystack = caseSensitive ? buffer : buffer.toLowerCase();
    for (let index = 0; index < keys.length; index += 1) {
      // 键名。
      const key = keys[index];
      const needle = caseSensitive ? key : key.toLowerCase();
      if (needle.length > 0 && haystack.indexOf(needle) >= 0) {
        return key;
      }
    }
    return '';
  }

  /**
   * 根据入参构建Prompt Text 值，仅生成数据结构，不直接执行外部请求。
   * @param entries 条目列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private buildPromptText(entries: Array<WorldInfoEntry>): string {
    const chunks = new Array<string>();
    for (let index = 0; index < entries.length; index += 1) {
      chunks.push(entries[index].content);
    }
    return chunks.join('\n');
  }
  private emptyMatch(): WorldInfoMatch {
    return {
      worldBookId: '',
      entryId: '',
      key: '',
    };
  }
  private async replaceIndexEntry(book: WorldBook): Promise<void> {
    const index = await this.readIndex();
    const entry = this.toIndexEntry(book);
    let replaced = false;
    for (let itemIndex = 0; itemIndex < index.items.length; itemIndex += 1) {
      if (index.items[itemIndex].id === book.id) {
        index.items[itemIndex] = entry;
        replaced = true;
      }
    }
    if (!replaced) {
      index.items.push(entry);
    }
    await this.writeIndex(index);
  }

  /**
   * 发布世界书事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。

   */
  private publishWorldBookEvent(eventName: string, book: WorldBook): void {
    const payload: WorldInfoEventPayload = {
      worldBook: this.copyBook(book),
    };
    this.events.publish<WorldInfoEventPayload>(eventName, payload);
  }

  /**
   * 读取Index 值，并转换为运行时使用的数据结构。
   */
  private async readIndex(): Promise<WorldBookIndex> {
    const store = new JsonStore<WorldBookIndex>(this.files, this.indexPath());
    return store.read(this.defaultIndex());
  }

  /**
   * 写入Index 值，持久化当前运行时状态。
   * @param index 索引数据或循环位置。
   */
  private async writeIndex(index: WorldBookIndex): Promise<void> {
    const store = new JsonStore<WorldBookIndex>(this.files, this.indexPath());
    await store.write(index);
  }

  /**
   * 写入World Book 值，持久化当前运行时状态。

   */
  private async writeWorldBook(book: WorldBook): Promise<void> {
    await this.files.ensureDirectory(this.worldBooksRoot());
    const store = new JsonStore<WorldBook>(this.files, this.worldBookPath(book.id));
    await store.write(book);
  }

  /**
   * 把世界书完整记录转换为列表索引项。
   */
  private toIndexEntry(book: WorldBook): WorldBookIndexEntry {
    return {
      id: book.id,
      name: book.name,
      entryCount: book.entries.length,
      createdAt: book.createdAt,
      updatedAt: book.updatedAt,
    };
  }
  private defaultIndex(): WorldBookIndex {
    return {
      schemaVersion: 1,
      nextId: 1,
      items: new Array<WorldBookIndexEntry>(),
    };
  }
  private defaultWorldBook(worldBookId: string): WorldBook {
    return {
      schemaVersion: 1,
      id: worldBookId,
      name: '',
      nextEntryId: 1,
      entries: new Array<WorldInfoEntry>(),
      createdAt: 0,
      updatedAt: 0,
    };
  }
  private indexPath(): string {
    return `${this.worldBooksRoot()}/index.json`;
  }
  private worldBookPath(worldBookId: string): string {
    return `${this.worldBooksRoot()}/${safePathSegment(worldBookId, 'worldbook')}.json`;
  }
  private worldBooksRoot(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/worldbooks`;
  }
  /**
   * 更新条目Recursive状态，必要时写回存储并发布对应事件。
   * @param worldBookIds 目标世界书标识列表。
   * @param messages 消息列表。

   * @param maxTokens token 数量或 token 内容。
   */
  async activateEntriesRecursive(
    worldBookIds: Array<string>,
    messages: Array<string>,
    maxDepth: number,
    maxTokens: number,
  ): Promise<WorldInfoActivation> {
    const activation = await this.activateEntries(worldBookIds, messages);
    // 递归扫描：第一轮激活的条目内容加入后续轮次扫描
    if (maxDepth <= 1) { return activation; }
    let extendedMessages = messages.slice();
    for (let ei = 0; ei < activation.entries.length; ei += 1) { const entry = activation.entries[ei];
      extendedMessages.push(entry.content);
    }
    const deep = await this.activateEntriesRecursive(worldBookIds, extendedMessages, maxDepth - 1, maxTokens);
    // 合并结果，去重
    const seen = new Set<string>();
    const merged = new Array<WorldInfoEntry>();
    const mergedMatches = new Array<WorldInfoMatch>();
    for (let ei = 0; ei < activation.entries.length; ei += 1) {
      const e = activation.entries[ei];
      const match = activation.matches[ei];
      seen.add(this.entryActivationKey(match.worldBookId, e.id));
      merged.push(this.copyEntry(e));
      mergedMatches.push(this.copyMatch(match));
    }
    for (let ei = 0; ei < deep.entries.length; ei += 1) { const e = deep.entries[ei];
      const match = deep.matches[ei];
      // 键名。
      const key = this.entryActivationKey(match.worldBookId, e.id);
      if (!seen.has(key)) { seen.add(key); merged.push(this.copyEntry(e)); mergedMatches.push(this.copyMatch(match)); }
    }
    return {
      entries: this.copyEntries(merged),
      matches: this.copyMatches(mergedMatches),
      promptText: this.buildPromptText(merged).substring(0, maxTokens * 3),
    };
  }
  private nextEntryIdAfterImport(importedNextEntryId: number, entries: Array<WorldInfoEntry>): number {
    // next Entry 标识。
    let nextEntryId = importedNextEntryId > 0 ? importedNextEntryId : 1;
    for (let index = 0; index < entries.length; index += 1) {
      nextEntryId = Math.max(nextEntryId, entries[index].uid + 1);
      if (entries[index].id.startsWith('entry-')) {
        const parsed = Number(entries[index].id.substring(6));
        if (parsed > 0) {
          nextEntryId = Math.max(nextEntryId, parsed + 1);
        }
      }
    }
    return nextEntryId;
  }
  private entryActivationKey(worldBookId: string, entryId: string): string {
    return `${worldBookId}:${entryId}`;
  }

  /**
   * 复制Book 值，避免外部修改内部状态。
   */
  private copyBook(book: WorldBook): WorldBook {
    return {
      schemaVersion: book.schemaVersion,
      id: book.id,
      name: book.name,
      nextEntryId: book.nextEntryId,
      entries: this.copyEntries(book.entries),
      createdAt: book.createdAt,
      updatedAt: book.updatedAt,
    };
  }

  /**
   * 复制Entries 列表，避免外部修改内部状态。
   * @param entries 条目列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyEntries(entries: Array<WorldInfoEntry>): Array<WorldInfoEntry> {
    const result = new Array<WorldInfoEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      result.push(this.copyEntry(entries[index]));
    }
    return result;
  }

  /**
   * 复制Entry 值，避免外部修改内部状态。
   * @param entry 条目记录。
   */
  private copyEntry(entry: WorldInfoEntry): WorldInfoEntry {
    return {
      id: entry.id,
      uid: entry.uid,
      comment: entry.comment,
      keys: entry.keys.slice(),
      secondaryKeys: entry.secondaryKeys.slice(),
      content: entry.content,
      constant: entry.constant,
      selective: entry.selective,
      enabled: entry.enabled,
      insertionOrder: entry.insertionOrder,
      position: entry.position,
      caseSensitive: entry.caseSensitive,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    };
  }

  /**
   * 复制Matches 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyMatches(matches: Array<WorldInfoMatch>): Array<WorldInfoMatch> {
    const result = new Array<WorldInfoMatch>();
    for (let index = 0; index < matches.length; index += 1) {
      result.push(this.copyMatch(matches[index]));
    }
    return result;
  }

  /**
   * 复制Match 值，避免外部修改内部状态。
   */
  private copyMatch(match: WorldInfoMatch): WorldInfoMatch {
    return {
      worldBookId: match.worldBookId,
      entryId: match.entryId,
      key: match.key,
    };
  }

  /**
   * 复制Index Entries 列表，避免外部修改内部状态。
   * @param entries 条目列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyIndexEntries(entries: Array<WorldBookIndexEntry>): Array<WorldBookIndexEntry> {
    const result = new Array<WorldBookIndexEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      result.push({
        id: entries[index].id,
        name: entries[index].name,
        entryCount: entries[index].entryCount,
        createdAt: entries[index].createdAt,
        updatedAt: entries[index].updatedAt,
      });
    }
    return result;
  }

}
