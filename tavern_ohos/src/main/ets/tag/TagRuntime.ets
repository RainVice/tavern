import { EventBus } from '../runtime/EventBus';
import type {
  TagCreateParams,
  TagEventPayload,
  TagImportResult,
  TagMapEventPayload,
  TagRecord,
} from './TagModels';

/**
 * 提供标签相关的无 UI 运行时能力，负责标签记录的创建、更新、删除、查询，以及标签与实体之间的映射管理，并通过事件总线发布对应的状态变更事件。
 */
export class TagRuntime {
  /**
   * 事件总线实例，用于发布标签和标签映射状态变更事件。
   */
  private events: EventBus;
  /**
   * 按 tagId 索引的标签记录 Map，由当前运行时内部维护。
   */
  private tags: Map<string, TagRecord> = new Map<string, TagRecord>();
  /**
   * 按 entityKey 索引的标签 ID 列表 Map，由当前运行时内部维护。
   */
  private tagMap: Map<string, Array<string>> = new Map<string, Array<string>>();
  /**
   * 自增 ID 计数器，用于生成新标签标识。
   */
  private tagCounter: number = 0;

  /**
   * 构建标签运行时实例。
   * @param events 注入的事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的标签记录。若名称已存在则直接返回现有记录；否则创建并发布 tag.created 事件。
   * @param params 创建参数。
   * @returns 创建后的标签记录副本。
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
   * 更新指定标签字段，发布 tag.updated 事件。
   * @param tagId 要更新的标签标识。
   * @param params 需要更新的字段值。
   * @returns 更新后的标签记录副本。
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
   * 删除指定标签，并从所有实体的映射中移除该标签的引用。
   * @param tagId 要删除的标签标识。
   */
  deleteTag(tagId: string): void {
    this.requireTag(tagId);
    this.tags.delete(tagId);
    this.removeTagFromMap(tagId);
  }

  /**
   * 获取所有标签记录的排序列表副本。
   * @param sortMode 排序模式："manual" / "alphabetical" / "by_entries"。
   * @returns 排序后的标签记录副本列表。
   */
  listTags(sortMode: string = 'manual'): Array<TagRecord> {
    return this.sortTags(Array.from(this.tags.values()), sortMode);
  }

  /**
   * 获取指定实体已绑定的标签记录列表。
   * @param entityKey 实体键。
   * @param sortMode 排序模式。
   * @returns 绑定的标签记录副本列表。
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
   * 为实体绑定一个标签，若已绑定则忽略。
   * @param entityKey 实体键。
   * @param tagId 标签标识。
   * @returns 绑定后该实体的标签 ID 列表副本。
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
   * 根据标签 ID 列表为实体批量建立标签映射，自动过滤不存在的标签并去重。
   * @param entityKey 实体键。
   * @param tagIds 要绑定的标签标识列表。
   * @returns 绑定后该实体的标签 ID 列表副本。
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
   * 将实体的标签映射键从 oldKey 重命名为 newKey。
   * @param oldKey 旧实体键。
   * @param newKey 新实体键。
   */
  renameTagKey(oldKey: string, newKey: string): void {
    const value = this.tagMap.get(oldKey);
    this.tagMap.set(newKey, value === undefined ? new Array<string>() : value.slice());
    this.tagMap.delete(oldKey);
    this.publishMap(newKey, this.tagMap.get(newKey) as Array<string>);
  }

  /**
   * 从指定实体上移除标签绑定。
   * @param tagId 标签标识。
   * @param entityKey 实体键。
   * @returns 移除后该实体的标签 ID 列表副本。
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
   * 从标签映射中移除标签绑定。若指定 entityKey 则只移除该实体的绑定；否则移除所有实体中的该标签。
   * @param tagId 标签标识。
   * @param entityKey 可选的实体键；不传时从所有实体移除。
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
   * 从外部名称列表导入标签，自动创建不存在的标签，并绑定到指定实体。
   * @param entityKey 实体键。
   * @param names 标签名称列表。
   * @param importSetting 导入策略："none" / "only_existing" / 其他（创建不存在的）。
   * @returns 导入结果统计。
   */
  importTagsFromNames(entityKey: string, names: Array<string>, importSetting: string): TagImportResult {
    const imported = new Array<TagRecord>();
    const ignored = new Array<string>();
    const created = new Array<TagRecord>();
    if (importSetting === 'none') {
      return this.toImportResult(entityKey, imported, ignored.concat(names), created);
    }
    const existingIds = this.tagMap.get(entityKey);
    const assigned = existingIds === undefined ? new Array<string>() : existingIds.slice();
    const limit = Math.min(names.length, 50);
    for (let index = 0; index < limit; index += 1) {
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
   * 判断指定标签是否为文件夹类型标签（folderType 不为 "NONE"）。
   * @param tagId 标签标识。
   * @returns 是文件夹标签返回 true，否则 false。
   */
  isFolderTag(tagId: string): boolean {
    const tag = this.requireTag(tagId);
    return tag.folderType !== 'NONE';
  }

  /**
   * 统计每个标签被关联的实体数量。
   * @returns 标签 ID 到计数的 Map。
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
   * 在 tags Map 中按名称精确查找标签（不区分大小写）。
   * @param name 标签名称。
   * @returns 找到的标签记录，未找到时返回 undefined。
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
   * 根据 ID 获取标签记录，标签不存在时抛出异常。
   * @param tagId 标签标识。
   * @returns 标签记录引用（非副本）。
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
   * 深度复制 TagRecord，防止外部修改内部状态。
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
   * 将导入过程统计转换为 TagImportResult 结构。
   * @param entityKey 实体键。
   * @param imported 已成功导入的标签记录列表。
   * @param ignored 被忽略的标签名称列表。
   * @param created 新创建的标签记录列表。
   * @returns 导入结果对象。
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
   * 发布 tag.created / tag.updated 事件，通知监听者标签已变更。
   * @param eventName 事件名称。
   * @param tag 变更相关的标签记录。
   */
  private publishTag(eventName: string, tag: TagRecord): void {
    const payload: TagEventPayload = {
      tag: this.copyTag(tag),
    };
    this.events.publish<TagEventPayload>(eventName, payload);
  }

  /**
   * 发布 tag.map.updated 事件，通知监听者标签映射已变更。
   * @param entityKey 映射变更涉及的实体键。
   * @param tagIds 绑定到该实体的标签标识列表。
   */
  private publishMap(entityKey: string, tagIds: Array<string>): void {
    const payload: TagMapEventPayload = {
      entityKey: entityKey,
      tagIds: tagIds.slice(),
    };
    this.events.publish<TagMapEventPayload>('tag.map.updated', payload);
  }
}
