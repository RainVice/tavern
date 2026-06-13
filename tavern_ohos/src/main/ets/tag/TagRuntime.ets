import { EventBus } from '../runtime/EventBus';
import type {
  TagCreateParams,
  TagEventPayload,
  TagImportResult,
  TagMapEventPayload,
  TagRecord,
} from './TagModels';

/**
 * 提供标签相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class TagRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * tags 列表，由当前实例内部维护。
   */
  private tags: Map<string, TagRecord> = new Map<string, TagRecord>();
  /**
   * tag Map 值，由当前实例内部维护。
   */
  private tagMap: Map<string, Array<string>> = new Map<string, Array<string>>();
  /**
   * tag Counter 值，由当前实例内部维护。
   */
  private tagCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的标签记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  createTag(params: TagCreateParams): TagRecord {
    const existing = this.findTagByName(params.name);
    if (existing !== undefined) {
      return this.copyTag(existing);
    }
    const now = Date.now();
    const tag: TagRecord = {
      id: params.id === undefined ? this.nextTagId() : params.id,
      name: params.name,
      folderType: params.folderType === undefined ? 'NONE' : params.folderType,
      filterState: params.filterState === undefined ? 'UNDEFINED' : params.filterState,
      sortOrder: params.sortOrder === undefined ? this.nextSortOrder() : params.sortOrder,
      color: params.color === undefined ? '' : params.color,
      color2: params.color2 === undefined ? '' : params.color2,
      createDate: now,
      hiddenOnCharacterCard: params.hiddenOnCharacterCard === undefined ? false : params.hiddenOnCharacterCard,
    };
    this.tags.set(tag.id, tag);
    this.publishTag('tag.created', tag);
    return this.copyTag(tag);
  }

  /**
   * 更新指定标签，写回存储并按需发布变更事件。
   * @param tagId 目标标签标识。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  updateTag(tagId: string, params: TagCreateParams): TagRecord {
    const tag = this.requireTag(tagId);
    tag.name = params.name;
    tag.folderType = params.folderType === undefined ? tag.folderType : params.folderType;
    tag.filterState = params.filterState === undefined ? tag.filterState : params.filterState;
    tag.sortOrder = params.sortOrder === undefined ? tag.sortOrder : params.sortOrder;
    tag.color = params.color === undefined ? tag.color : params.color;
    tag.color2 = params.color2 === undefined ? tag.color2 : params.color2;
    tag.hiddenOnCharacterCard = params.hiddenOnCharacterCard === undefined ? tag.hiddenOnCharacterCard : params.hiddenOnCharacterCard;
    this.publishTag('tag.updated', tag);
    return this.copyTag(tag);
  }

  /**
   * 删除指定标签，并清理相关索引或资源引用。
   * @param tagId 目标标签标识。
   */
  deleteTag(tagId: string): void {
    this.requireTag(tagId);
    this.tags.delete(tagId);
    this.removeTagFromMap(tagId);
  }

  /**
   * 读取Tags列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listTags(sortMode: string = 'manual'): Array<TagRecord> {
    return this.sortTags(Array.from(this.tags.values()), sortMode);
  }

  /**
   * 读取Tags List 列表，不存在时通常抛出错误或返回空值。


   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  getTagsList(entityKey: string, sortMode: string = 'manual'): Array<TagRecord> {
    const tagIds = this.tagMap.get(entityKey);
    if (tagIds === undefined) {
      return new Array<TagRecord>();
    }
    const result = new Array<TagRecord>();
    for (let index = 0; index < tagIds.length; index += 1) {
      const tag = this.tags.get(tagIds[index]);
      if (tag !== undefined) {
        result.push(this.copyTag(tag));
      }
    }
    return this.sortTags(result, sortMode);
  }

  /**
   * 创建或写入标签ToEntity，完成持久化后返回可供调用方使用的结果。

   * @param tagId 目标标签标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  addTagToEntity(entityKey: string, tagId: string): Array<string> {
    this.requireTag(tagId);
    const existing = this.tagMap.get(entityKey);
    const tagIds = existing === undefined ? new Array<string>() : existing.slice();
    if (tagIds.indexOf(tagId) < 0) {
      tagIds.push(tagId);
    }
    this.tagMap.set(entityKey, tagIds);
    this.publishMap(entityKey, tagIds);
    return tagIds.slice();
  }

  /**
   * 根据标签标识列表创建标签映射，用于批量绑定实体和标签。

   * @param tagIds 目标标签标识列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  createTagMapFromList(entityKey: string, tagIds: Array<string>): Array<string> {
    const result = new Array<string>();
    for (let index = 0; index < tagIds.length; index += 1) {
      if (this.tags.has(tagIds[index]) && result.indexOf(tagIds[index]) < 0) {
        result.push(tagIds[index]);
      }
    }
    this.tagMap.set(entityKey, result);
    this.publishMap(entityKey, result);
    return result.slice();
  }

  /**
   * 更新标签Key状态，必要时写回存储并发布对应事件。


   */
  renameTagKey(oldKey: string, newKey: string): void {
    const value = this.tagMap.get(oldKey);
    this.tagMap.set(newKey, value === undefined ? new Array<string>() : value.slice());
    this.tagMap.delete(oldKey);
    this.publishMap(newKey, this.tagMap.get(newKey) as Array<string>);
  }

  /**
   * 从实体上移除标签，用于解除注册、绑定或索引关系。
   * @param tagId 目标标签标识。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  removeTagFromEntity(tagId: string, entityKey: string): Array<string> {
    const value = this.tagMap.get(entityKey);
    if (value === undefined) {
      return new Array<string>();
    }
    const result = new Array<string>();
    for (let index = 0; index < value.length; index += 1) {
      if (value[index] !== tagId) {
        result.push(value[index]);
      }
    }
    this.tagMap.set(entityKey, result);
    this.publishMap(entityKey, result);
    return result.slice();
  }

  /**
   * 从标签映射中移除标签，用于解除注册、绑定或索引关系。
   * @param tagId 目标标签标识。

   */
  removeTagFromMap(tagId: string, entityKey: string | undefined = undefined): void {
    if (entityKey !== undefined) {
      this.removeTagFromEntity(tagId, entityKey);
      return;
    }
    const keys = Array.from(this.tagMap.keys());
    for (let index = 0; index < keys.length; index += 1) {
      this.removeTagFromEntity(tagId, keys[index]);
    }
  }

  /**
   * 从外部数据导入Tags From Names 列表，转换为当前运行时的数据结构。



   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  importTagsFromNames(entityKey: string, names: Array<string>, importSetting: string): TagImportResult {
    const imported = new Array<TagRecord>();
    const ignored = new Array<string>();
    // 创建后的记录。
    const created = new Array<TagRecord>();
    if (importSetting === 'none') {
      return this.toImportResult(entityKey, imported, ignored.concat(names), created);
    }
    const existingIds = this.tagMap.get(entityKey);
    const assigned = existingIds === undefined ? new Array<string>() : existingIds.slice();
    const limit = Math.min(names.length, 50);
    for (let index = 0; index < limit; index += 1) {
      // 名称。
      const name = names[index].trim();
      if (name.length === 0 || name === 'ROOT' || name === 'TAVERN') {
        ignored.push(names[index]);
        continue;
      }
      const existing = this.findTagByName(name);
      if (existing === undefined && importSetting === 'only_existing') {
        ignored.push(name);
        continue;
      }
      const tag = existing === undefined ? this.createTag({ name: name }) : this.copyTag(existing);
      if (existing === undefined) {
        created.push(tag);
      }
      if (assigned.indexOf(tag.id) < 0) {
        assigned.push(tag.id);
        imported.push(tag);
      }
    }
    this.tagMap.set(entityKey, assigned);
    this.publishMap(entityKey, assigned);
    return this.toImportResult(entityKey, imported, ignored, created);
  }

  /**
   * 判断Folder Tag 值是否满足条件。
   * @param tagId 目标标签标识。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  isFolderTag(tagId: string): boolean {
    const tag = this.requireTag(tagId);
    return tag.folderType !== 'NONE';
  }

  /**
   * 统计TagUsage，用于预算、分页或状态汇总。
   */
  countTagUsage(): Map<string, number> {
    const counts = new Map<string, number>();
    const keys = Array.from(this.tagMap.keys());
    for (let keyIndex = 0; keyIndex < keys.length; keyIndex += 1) {
      const tagIds = this.tagMap.get(keys[keyIndex]);
      if (tagIds === undefined) {
        continue;
      }
      for (let index = 0; index < tagIds.length; index += 1) {
        const current = counts.get(tagIds[index]);
        counts.set(tagIds[index], current === undefined ? 1 : current + 1);
      }
    }
    return counts;
  }
  private sortTags(values: Array<TagRecord>, sortMode: string): Array<TagRecord> {
    const result = new Array<TagRecord>();
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyTag(values[index]));
    }
    const counts = this.countTagUsage();
    result.sort((left: TagRecord, right: TagRecord) => this.compareTags(left, right, sortMode, counts));
    return result;
  }
  private compareTags(left: TagRecord, right: TagRecord, sortMode: string, counts: Map<string, number>): number {
    const alphabetical = left.name.toLowerCase().localeCompare(right.name.toLowerCase());
    if (sortMode === 'alphabetical') {
      return alphabetical;
    }
    if (sortMode === 'by_entries') {
      const leftCount = counts.get(left.id);
      const rightCount = counts.get(right.id);
      return ((rightCount === undefined ? 0 : rightCount) - (leftCount === undefined ? 0 : leftCount)) || alphabetical;
    }
    return (left.sortOrder - right.sortOrder) || alphabetical;
  }

  /**
   * 在当前集合中查找Tag By 名称，未命中时返回空值或默认位置。
   * @param name 显示名称或注册名称。
   */
  private findTagByName(name: string): TagRecord | undefined {
    const normalized = name.toLowerCase();
    const values = Array.from(this.tags.values());
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].name.toLowerCase() === normalized) {
        return values[index];
      }
    }
    return undefined;
  }

  /**
   * 读取必须存在的Tag 值，缺失时抛出错误。
   * @param tagId 目标标签标识。
   */
  private requireTag(tagId: string): TagRecord {
    const tag = this.tags.get(tagId);
    if (tag === undefined) {
      throw new Error(`Tag not found: ${tagId}`);
    }
    return tag;
  }
  private nextTagId(): string {
    this.tagCounter += 1;
    return `tag-${this.tagCounter}`;
  }
  private nextSortOrder(): number {
    return this.tags.size + 1;
  }

  /**
   * 复制Tag 值，避免外部修改内部状态。
   */
  private copyTag(tag: TagRecord): TagRecord {
    return {
      id: tag.id,
      name: tag.name,
      folderType: tag.folderType,
      filterState: tag.filterState,
      sortOrder: tag.sortOrder,
      color: tag.color,
      color2: tag.color2,
      createDate: tag.createDate,
      hiddenOnCharacterCard: tag.hiddenOnCharacterCard,
    };
  }

  /**
   * 把导入过程统计转换为导入结果结构。

   * @param imported 导入结果。

   * @param created 创建后的记录。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private toImportResult(entityKey: string, imported: Array<TagRecord>, ignored: Array<string>, created: Array<TagRecord>): TagImportResult {
    return {
      entityKey: entityKey,
      imported: imported,
      ignored: ignored,
      created: created,
    };
  }

  /**
   * 发布标签事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。

   */
  private publishTag(eventName: string, tag: TagRecord): void {
    const payload: TagEventPayload = {
      tag: this.copyTag(tag),
    };
    this.events.publish<TagEventPayload>(eventName, payload);
  }

  /**
   * 发布标签事件，把状态变化通知给宿主或其他 Runtime。

   * @param tagIds 目标标签标识列表。
   */
  private publishMap(entityKey: string, tagIds: Array<string>): void {
    const payload: TagMapEventPayload = {
      entityKey: entityKey,
      tagIds: tagIds.slice(),
    };
    this.events.publish<TagMapEventPayload>('tag.map.updated', payload);
  }
}
