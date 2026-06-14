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
   * 世界书数据在文件系统中的根路径。
   */
  private rootPath: string;
  /**
   * 当前关联的用户标识。
   */
  private userId: string;

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   * @param rootPath 世界书数据根路径。
   * @param userId 当前用户标识。
   */
  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 创建新的世界书，自动分配 ID 并写入索引。在用户创建新世界书时调用。
   * @param name 世界书名称，用于在管理界面中标识世界书。
   * @returns 新建世界书的深拷贝，供后续添加条目使用。
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
   * 读取世界书索引列表，用于世界书管理页快速展示。在管理页加载世界书列表时调用。
   * @returns 世界书索引项副本列表，每个项包含世界书的概要信息，供 UI 列表渲染。
   */
  async listWorldBooks(): Promise<Array<WorldBookIndexEntry>> {
    const index = await this.readIndex();
    return this.copyIndexEntries(index.items);
  }

  /**
   * 根据 ID 读取指定世界书的完整数据。在编辑世界书或触发条目激活时调用。
   * @param worldBookId 世界书标识，用于定位要读取的世界书文件。
   * @returns 世界书深拷贝，包含条目列表和元数据等完整信息。
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
   * 删除指定世界书及其数据文件，并从索引中移除。在用户删除世界书时调用。
   * @param worldBookId 世界书标识，指定要删除的世界书。
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
   * 在指定世界书中创建新条目，自动分配 ID 并更新索引。在用户添加新条目时调用。
   * @param worldBookId 世界书标识，指定要添加条目的世界书。
   * @param params 创建条目所需的参数，包含关键词、内容、触发条件等完整配置。
   * @returns 新建条目的深拷贝，供 UI 层展示或后续编辑。
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
   * 更新指定世界书中的条目，写回存储并更新索引。在用户编辑已有条目时调用。
   * @param worldBookId 世界书标识，指定条目所属的世界书。
   * @param entryId 条目标识，指定要更新的条目。
   * @param params 更新所需的参数，包含要修改的字段新值。
   * @returns 更新后的条目深拷贝，用于刷新 UI。
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
   * 从指定世界书中删除条目，并更新条目计数。在用户删除条目时调用。
   * @param worldBookId 世界书标识，指定条目所属的世界书。
   * @param entryId 条目标识，指定要删除的条目。
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
   * 导出世界书为 JSON 字符串，用于备份、迁移或与 SillyTavern 数据互通。在用户导出世界书时调用。
   * @param worldBookId 世界书标识，指定要导出的世界书。
   * @returns JSON 格式的导出字符串，可直接保存为文件或传输给外部系统。
   */
  async exportWorldBookJson(worldBookId: string): Promise<string> {
    const book = await this.getWorldBook(worldBookId);
    return JSON.stringify(book);
  }

  /**
   * 从 JSON 字符串导入世界书，分配新 ID 并写入索引。在用户从外部文件导入世界书时调用。
   * @param json 外部传入的 JSON 字符串，包含世界书的完整数据。
   * @param name 导入后的世界书名称，可覆盖原始名称。
   * @returns 导入后的世界书深拷贝，供 UI 层展示或后续编辑。
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
   * 根据关键词在指定世界书中匹配并激活条目，返回激活结果。在提示词构建流程中，根据当前消息内容匹配世界书条目。
   * @param worldBookIds 要扫描的世界书 ID 列表，指定参与匹配的世界书范围。
   * @param messages 消息文本列表，将拼接后用于关键词匹配，通常为最近的聊天消息集合。
   * @returns 激活结果，包含匹配的条目、匹配信息和提示词文本，供注入到模型输入中。
   */
  async activateEntries(worldBookIds: Array<string>, messages: Array<string>): Promise<WorldInfoActivation> {
    const buffer = messages.join('\n');
    const candidates = new Array<WorldInfoActivationCandidate>();
    for (let bookIndex = 0; bookIndex < worldBookIds.length; bookIndex += 1) {
      const book = await this.getWorldBook(worldBookIds[bookIndex]);
      // 遍历当前世界书中的所有条目，逐一匹配关键词。
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
   * 对单个条目执行关键词匹配：检查是否启用、是否为常驻条目、主要和次要关键词是否命中。
   * @param worldBookId 世界书标识。
   * @param entry 待匹配的条目。
   * @param buffer 拼接后的消息文本，用于关键词匹配。
   * @returns 匹配结果，未命中时返回空 entryId。
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
   * 在关键词列表中查找第一个在文本中出现的匹配项。
   * @param keys 关键词列表。
   * @param buffer 待匹配的文本。
   * @param caseSensitive 是否区分大小写。
   * @returns 命中的关键词，未命中时返回空字符串。
   */
  private findFirstMatch(keys: Array<string>, buffer: string, caseSensitive: boolean): string {
    const haystack = caseSensitive ? buffer : buffer.toLowerCase();
    for (let index = 0; index < keys.length; index += 1) {
      // 对每个关键词执行子串匹配。
      const key = keys[index];
      const needle = caseSensitive ? key : key.toLowerCase();
      if (needle.length > 0 && haystack.indexOf(needle) >= 0) {
        return key;
      }
    }
    return '';
  }

  /**
   * 将所有激活条目的内容拼接为提示词文本，按 insertionOrder 排序。
   * @param entries 激活的条目列表。
   * @returns 拼接后的提示词文本。
   */
  private buildPromptText(entries: Array<WorldInfoEntry>): string {
    const chunks = new Array<string>();
    for (let index = 0; index < entries.length; index += 1) {
      chunks.push(entries[index].content);
    }
    return chunks.join('\n');
  }

  /**
   * 返回空匹配结果（未命中时使用）。
   * @returns 空的 WorldInfoMatch。
   */
  private emptyMatch(): WorldInfoMatch {
    return {
      worldBookId: '',
      entryId: '',
      key: '',
    };
  }

  /**
   * 更新或插入世界书在索引中的条目。
   * @param book 世界书数据。
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
   * 发布世界书事件，通知宿主或其他 Runtime。
   * @param eventName 事件名称。
   * @param book 关联的世界书数据。
   */
  private publishWorldBookEvent(eventName: string, book: WorldBook): void {
    const payload: WorldInfoEventPayload = {
      worldBook: this.copyBook(book),
    };
    this.events.publish<WorldInfoEventPayload>(eventName, payload);
  }

  /**
   * 从文件系统读取世界书索引。
   * @returns 世界书索引数据。
   */
  private async readIndex(): Promise<WorldBookIndex> {
    const store = new JsonStore<WorldBookIndex>(this.files, this.indexPath());
    return store.read(this.defaultIndex());
  }

  /**
   * 将世界书索引写入文件系统。
   * @param index 世界书索引数据。
   */
  private async writeIndex(index: WorldBookIndex): Promise<void> {
    const store = new JsonStore<WorldBookIndex>(this.files, this.indexPath());
    await store.write(index);
  }

  /**
   * 将世界书数据持久化到文件系统。
   * @param book 世界书数据。
   */
  private async writeWorldBook(book: WorldBook): Promise<void> {
    await this.files.ensureDirectory(this.worldBooksRoot());
    const store = new JsonStore<WorldBook>(this.files, this.worldBookPath(book.id));
    await store.write(book);
  }

  /**
   * 将世界书完整记录转换为列表索引项。
   * @param book 世界书数据。
   * @returns 索引条目。
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
   * 返回空的默认世界书索引。
   * @returns 默认的世界书索引。
   */
  private defaultIndex(): WorldBookIndex {
    return {
      schemaVersion: 1,
      nextId: 1,
      items: new Array<WorldBookIndexEntry>(),
    };
  }

  /**
   * 返回给定 ID 的默认世界书结构。
   * @param worldBookId 世界书 ID。
   * @returns 空的世界书数据。
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
   * 返回世界书索引文件的路径。
   * @returns 索引文件路径。
   */
  private indexPath(): string {
    return `${this.worldBooksRoot()}/index.json`;
  }

  /**
   * 返回指定世界书的数据文件路径。
   * @param worldBookId 世界书 ID。
   * @returns 世界书文件路径。
   */
  private worldBookPath(worldBookId: string): string {
    return `${this.worldBooksRoot()}/${safePathSegment(worldBookId, 'worldbook')}.json`;
  }

  /**
   * 返回世界书数据根目录路径。
   * @returns 根目录路径。
   */
  private worldBooksRoot(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/worldbooks`;
  }

  /**
   * 递归激活：将第一轮激活的条目内容加入后续消息，再次匹配，直到达到最大深度。用于处理世界书条目内容本身也会触发其他条目的链式匹配场景。
   * @param worldBookIds 要扫描的世界书 ID 列表。
   * @param messages 消息文本列表，作为初始匹配的输入文本。
   * @param maxDepth 递归最大深度，用于控制链式激活的层数上限防止无限循环。
   * @param maxTokens 提示词最大 token 数限制，用于截断最终生成的提示词文本。
   * @returns 激活结果，包含合并后的条目、匹配信息和提示词文本，供后续提示词构建使用。
   */
  async activateEntriesRecursive(
    worldBookIds: Array<string>,
    messages: Array<string>,
    maxDepth: number,
    maxTokens: number,
  ): Promise<WorldInfoActivation> {
    const activation = await this.activateEntries(worldBookIds, messages);
    // 递归扫描：第一轮激活的条目内容加入后续轮次扫描。
    if (maxDepth <= 1) {
      return activation;
    }
    let extendedMessages = messages.slice();
    for (let ei = 0; ei < activation.entries.length; ei += 1) {
      const entry = activation.entries[ei];
      extendedMessages.push(entry.content);
    }
    const deep = await this.activateEntriesRecursive(worldBookIds, extendedMessages, maxDepth - 1, maxTokens);
    // 合并结果，按 (worldBookId, entryId) 去重。
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
    for (let ei = 0; ei < deep.entries.length; ei += 1) {
      const e = deep.entries[ei];
      const match = deep.matches[ei];
      // 检查条目是否已在合并结果中。
      const key = this.entryActivationKey(match.worldBookId, e.id);
      if (!seen.has(key)) {
        seen.add(key);
        merged.push(this.copyEntry(e));
        mergedMatches.push(this.copyMatch(match));
      }
    }
    return {
      entries: this.copyEntries(merged),
      matches: this.copyMatches(mergedMatches),
      promptText: this.buildPromptText(merged).substring(0, maxTokens * 3),
    };
  }

  /**
   * 导入时计算下一条目 ID，确保不与其他条目 ID 冲突。
   * @param importedNextEntryId 导入数据中的 nextEntryId。
   * @param entries 导入的条目列表。
   * @returns 计算后的下一条目 ID。
   */
  private nextEntryIdAfterImport(importedNextEntryId: number, entries: Array<WorldInfoEntry>): number {
    // 取 max(导入的 nextEntryId, 所有条目的 uid+1, entry-前缀 ID+1)。
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
   * 生成条目激活的唯一去重键。
   * @param worldBookId 世界书 ID。
   * @param entryId 条目 ID。
   * @returns "worldBookId:entryId" 格式的去重键。
   */
  private entryActivationKey(worldBookId: string, entryId: string): string {
    return `${worldBookId}:${entryId}`;
  }

  /**
   * 深拷贝世界书数据，防止外部修改内部状态。
   * @param book 世界书数据。
   * @returns 世界书深拷贝。
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
   * 深拷贝条目列表。
   * @param entries 条目列表。
   * @returns 条目深拷贝列表。
   */
  private copyEntries(entries: Array<WorldInfoEntry>): Array<WorldInfoEntry> {
    const result = new Array<WorldInfoEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      result.push(this.copyEntry(entries[index]));
    }
    return result;
  }

  /**
   * 深拷贝单条条目。
   * @param entry 条目记录。
   * @returns 条目深拷贝。
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
   * 深拷贝匹配信息列表。
   * @param matches 匹配信息列表。
   * @returns 匹配信息深拷贝列表。
   */
  private copyMatches(matches: Array<WorldInfoMatch>): Array<WorldInfoMatch> {
    const result = new Array<WorldInfoMatch>();
    for (let index = 0; index < matches.length; index += 1) {
      result.push(this.copyMatch(matches[index]));
    }
    return result;
  }

  /**
   * 深拷贝单条匹配信息。
   * @param match 匹配信息。
   * @returns 匹配信息深拷贝。
   */
  private copyMatch(match: WorldInfoMatch): WorldInfoMatch {
    return {
      worldBookId: match.worldBookId,
      entryId: match.entryId,
      key: match.key,
    };
  }

  /**
   * 深拷贝索引条目列表。
   * @param entries 索引条目列表。
   * @returns 索引条目深拷贝列表。
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
