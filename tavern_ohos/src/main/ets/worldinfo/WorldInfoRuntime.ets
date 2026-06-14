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
 * 世界书激活过程中的内部中转结构，将匹配的条目与匹配详情配对。
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
   * 创建一个新的世界书，写入存储并返回副本，同时发布 worldinfo.created 事件。
   * @param name 世界书的显示名称。
   * @returns 新创建的世界书记录副本。
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
   * 读取所有世界书的索引列表，返回副本列表。
   * @returns 世界书索引摘要项副本列表，用于列表页快速展示。
   */
  async listWorldBooks(): Promise<Array<WorldBookIndexEntry>> {
    const index = await this.readIndex();
    return this.copyIndexEntries(index.items);
  }

  /**
   * 读取指定世界书的完整数据，不存在时抛出错误。
   * @param worldBookId 世界书标识。
   * @returns 完整世界书记录的副本。
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
   * 删除指定世界书及其所有条目数据，并从索引中移除该记录。
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
   * 在指定世界书中创建条目，新增条目设为递增 uid，发布 worldinfo.updated 事件。
   * @param worldBookId 世界书标识。
   * @param params 条目创建参数。
   * @returns 新建条目的深拷贝副本。
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
   * 更新指定世界书条目的所有参数，写回存储并按需发布 worldinfo.updated 事件。
   * @param worldBookId 世界书标识。
   * @param entryId 条目标识。
   * @param params 条目更新参数。
   * @returns 更新后条目的深拷贝副本。
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
   * 删除指定世界书中的条目，更新世界书最后更新时间，并按需更新索引中的条目计数。
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
   * 将世界书导出为 JSON 字符串，用于备份或与 SillyTavern 数据互通。
   * @param worldBookId 世界书标识。
   * @returns 序列化后的 JSON 字符串。
   */
  async exportWorldBookJson(worldBookId: string): Promise<string> {
    const book = await this.getWorldBook(worldBookId);
    return JSON.stringify(book);
  }

  /**
   * 从外部 JSON 数据导入世界书，为运行时重新生成标识和时间戳，并发布 worldinfo.imported 事件。
   * @param json 外部传入的世界书 JSON 字符串。
   * @param name 导入后的世界书显示名称。
   * @returns 导入后的世界书记录副本。
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
   * 对给定的消息文本执行世界书条目匹配激活，返回匹配的条目和拼接后的提示词文本。
   * @param worldBookIds 要参与激活的世界书标识列表。
   * @param messages 用于关键词匹配的消息文本列表。
   * @returns 激活结果，包含命中的条目、匹配详情和提示词文本。
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
  /**
   * 将条目与消息缓冲区进行关键词匹配，返回匹配结果。
   * @param worldBookId 世界书标识。
   * @param entry 待匹配的条目。
   * @param buffer 文本缓冲区。
   * @returns 匹配结果；未匹配时返回空值匹配。
   */
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
   * 在缓冲区文本中查找第一个命中的关键词。
   * @param keys 待匹配的关键词列表。
   * @param buffer 要搜索的文本缓冲区。
   * @param caseSensitive 是否区分大小写。
   * @returns 第一个命中的关键词原文；未命中则返回空字符串。
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
   * 将所有激活条目的内容以换行符拼接为提示词文本。
   * @param entries 已激活的条目列表。
   * @returns 拼接后的提示词文本字符串。
   */
  private buildPromptText(entries: Array<WorldInfoEntry>): string {
    const chunks = new Array<string>();
    for (let index = 0; index < entries.length; index += 1) {
      chunks.push(entries[index].content);
    }
    return chunks.join('\n');
  }
  /**
   * 返回一个空的匹配结果，表示未命中任何关键词。
   * @returns 所有字段为空字符串的匹配结果。
   */
  private emptyMatch(): WorldInfoMatch {
    return {
      worldBookId: '',
      entryId: '',
      key: '',
    };
  }
  /**
   * 更新世界书在索引中的摘要信息，若不存在则新增。
   * @param book 更新后的世界书记录。
   */
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
   * 发布世界书变更事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要发布的事件名称。
   * @param book 变更后的世界书记录。
   */
  private publishWorldBookEvent(eventName: string, book: WorldBook): void {
    const payload: WorldInfoEventPayload = {
      worldBook: this.copyBook(book),
    };
    this.events.publish<WorldInfoEventPayload>(eventName, payload);
  }

  /**
   * 读取世界书索引文件，若文件不存在则使用默认索引。
   * @returns 解析后的世界书索引对象。
   */
  private async readIndex(): Promise<WorldBookIndex> {
    const store = new JsonStore<WorldBookIndex>(this.files, this.indexPath());
    return store.read(this.defaultIndex());
  }

  /**
   * 将世界书索引对象写回持久化文件。
   * @param index 要持久化的索引对象。
   */
  private async writeIndex(index: WorldBookIndex): Promise<void> {
    const store = new JsonStore<WorldBookIndex>(this.files, this.indexPath());
    await store.write(index);
  }

  /**
   * 将世界书记录写回持久化文件。
   * @param book 要持久化的世界书籍对象。
   */
  private async writeWorldBook(book: WorldBook): Promise<void> {
    await this.files.ensureDirectory(this.worldBooksRoot());
    const store = new JsonStore<WorldBook>(this.files, this.worldBookPath(book.id));
    await store.write(book);
  }

  /**
   * 将世界书完整记录转换为索引列表中的摘要项。
   * @param book 世界书记录。
   * @returns 索引摘要项。
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
  /**
   * 生成默认的世界书索引结构，包含 schemaVersion 为 1、nextId 为 1、空条目列表。
   * @returns 默认的世界书索引对象。
   */
  private defaultIndex(): WorldBookIndex {
    return {
      schemaVersion: 1,
      nextId: 1,
      items: new Array<WorldBookIndexEntry>(),
    };
  }
  /**
   * 生成指定标识的默认世界书结构（空条目）。
   * @param worldBookId 世界书标识。
   * @returns 默认世界书对象。
   */
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
  /**
   * 生成世界书索引文件的存储路径。
   * @returns 索引文件路径字符串。
   */
  private indexPath(): string {
    return `${this.worldBooksRoot()}/index.json`;
  }

  /**
   * 根据世界书标识生成对应的存储文件路径。
   * @param worldBookId 世界书标识。
   * @returns 世界书 JSON 文件路径字符串。
   */
  private worldBookPath(worldBookId: string): string {
    return `${this.worldBooksRoot()}/${safePathSegment(worldBookId, 'worldbook')}.json`;
  }

  /**
   * 生成世界书数据的根目录路径。
   * @returns 世界书根目录路径字符串。
   */
  private worldBooksRoot(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/worldbooks`;
  }
  /**
   * 递归执行世界书条目激活扫描：每轮激活后将匹配条目内容加入下一轮扫描缓冲区，
   * 支持多轮深度匹配，最终去重合并所有轮次的结果。
   * @param worldBookIds 目标世界书标识列表。
   * @param messages 消息列表，作为关键词匹配的文本缓冲区。
   * @param maxDepth 递归扫描的最大深度。
   * @param maxTokens 提示词文本的最大字符数限制（近似值，按 token 数 * 3 截断）。
   * @returns 合并去重后的激活结果。
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
  /**
   * 根据导入的 nextEntryId 和现有条目，计算导入后合理的下一条目序号。
   * @param importedNextEntryId 导入数据中的 nextEntryId。
   * @param entries 导入的条目列表。
   * @returns 合并后的下一条目序号。
   */
  private nextEntryIdAfterImport(importedNextEntryId: number, entries: Array<WorldInfoEntry>): number {
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
  /**
   * 生成条目去重标识键（格式："{worldBookId}:{entryId}"）。
   * @param worldBookId 世界书标识。
   * @param entryId 条目标识。
   * @returns 去重键字符串。
   */
  private entryActivationKey(worldBookId: string, entryId: string): string {
    return `${worldBookId}:${entryId}`;
  }

  /**
   * 复制完整世界书记录（含条目深拷贝），避免外部修改内部状态。
   * @param book 要复制的世界书。
   * @returns 世界书的深拷贝副本。
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
   * 复制条目列表（含每个条目的深拷贝），避免外部修改内部状态。
   * @param entries 要复制的条目列表。
   * @returns 条目列表的深拷贝副本。
   */
  private copyEntries(entries: Array<WorldInfoEntry>): Array<WorldInfoEntry> {
    const result = new Array<WorldInfoEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      result.push(this.copyEntry(entries[index]));
    }
    return result;
  }

  /**
   * 复制单条条目记录（含 keys 数组深拷贝），避免外部修改内部状态。
   * @param entry 要复制的条目记录。
   * @returns 条目记录的深拷贝副本。
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
   * 复制匹配结果列表（含每条匹配的深拷贝），避免外部修改内部状态。
   * @param matches 要复制的匹配结果列表。
   * @returns 匹配结果列表的深拷贝副本。
   */
  private copyMatches(matches: Array<WorldInfoMatch>): Array<WorldInfoMatch> {
    const result = new Array<WorldInfoMatch>();
    for (let index = 0; index < matches.length; index += 1) {
      result.push(this.copyMatch(matches[index]));
    }
    return result;
  }

  /**
   * 复制单条匹配结果，避免外部修改内部状态。
   * @param match 要复制的匹配结果。
   * @returns 匹配结果的深拷贝副本。
   */
  private copyMatch(match: WorldInfoMatch): WorldInfoMatch {
    return {
      worldBookId: match.worldBookId,
      entryId: match.entryId,
      key: match.key,
    };
  }

  /**
   * 复制索引摘要项列表（无需深拷贝条目字段），避免外部修改内部状态。
   * @param entries 要复制的索引摘要项列表。
   * @returns 索引摘要项列表的副本。
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
