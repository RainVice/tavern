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
 * 在实体（角色、聊天）分类管理流程中，支持标签的创建、编辑、删除以及与实体的多对多映射关系管理。
 */
export class TagRuntime {
  /**
   * 事件总线实例，用于发布标签变更和映射变更事件。
   */
  private events: EventBus;
  /**
   * 按 ID 保存的标签记录映射表，是所有标签定义的核心存储。
   */
  private tags: Map<string, TagRecord> = new Map<string, TagRecord>();
  /**
   * 按实体键保存的标签 ID 列表映射表（实体 -> 标签关联），用于维护标签和实体之间的多对多关系。
   */
  private tagMap: Map<string, Array<string>> = new Map<string, Array<string>>();
  /**
   * 标签自增 ID 计数器。
   */
  private tagCounter: number = 0;

  /**
   * 初始化 TagRuntime 实例。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新标签；如果同名标签已存在则返回现有记录。
   * 在用户通过 UI 添加新标签或在导入流程中由 importTagsFromNames 间接调用。
   * @param params 标签创建参数。
   * @returns 新建或已有的标签记录副本。
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
   * 更新指定标签的属性值。
   * 在用户编辑标签（如改名、改色、改排序）时由 UI 层调用。
   * @param tagId 目标标签标识。
   * @param params 要更新的属性。
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
   * 删除指定标签并从所有实体的映射中移除关联。
   * 在用户删除标签时由 UI 层调用。
   * @param tagId 目标标签标识。
   */
  deleteTag(tagId: string): void {
    this.requireTag(tagId);
    this.tags.delete(tagId);
    this.removeTagFromMap(tagId);
  }

  /**
   * 列出所有标签记录，支持按指定排序模式排序。
   * 在 UI 展示标签管理列表或标签选择器时调用。
   * @param sortMode 排序模式：manual（默认，按 sortOrder）/ alphabetical / by_entries。
   * @returns 排序后的标签记录副本列表。
   */
  listTags(sortMode: string = 'manual'): Array<TagRecord> {
    return this.sortTags(Array.from(this.tags.values()), sortMode);
  }

  /**
   * 获取指定实体关联的所有标签记录。
   * 在 UI 展示某个角色或聊天的标签列表时调用。
   * @param entityKey 实体键（如角色 ID 或聊天 ID）。
   * @param sortMode 排序模式。
   * @returns 关联的标签记录副本列表。
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
   * 为指定实体添加标签关联。
   * 在用户为角色或聊天选择标签时由 UI 层调用。
   * @param entityKey 实体键。
   * @param tagId 目标标签标识。
   * @returns 该实体的当前标签 ID 列表副本。
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
   * 从标签 ID 列表创建实体的标签映射（批量绑定）。
   * 在从外部数据（如角色卡导入）恢复标签关联时由宿主或导入流程调用。
   * @param entityKey 实体键。
   * @param tagIds 要绑定的标签 ID 列表。
   * @returns 绑定后的标签 ID 列表副本。
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
   * 重命名实体的标签映射键（用于实体标识变更时同步映射）。
   * 在实体（如角色）的标识符变更时由宿主调用，确保标签映射跟随实体。
   * @param oldKey 旧的实体键。
   * @param newKey 新的实体键。
   */
  renameTagKey(oldKey: string, newKey: string): void {
    const value = this.tagMap.get(oldKey);
    this.tagMap.set(newKey, value === undefined ? new Array<string>() : value.slice());
    this.tagMap.delete(oldKey);
    this.publishMap(newKey, this.tagMap.get(newKey) as Array<string>);
  }

  /**
   * 从指定实体上移除标签关联。
   * 在用户取消标签关联时由 UI 层调用。
   * @param tagId 要移除的标签 ID。
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
   * 从所有或指定实体的映射中移除标签的关联。
   * 在标签被删除时自动由 deleteTag 调用，清理所有关联。
   * @param tagId 要移除的标签 ID。
   * @param entityKey 可选，指定实体键；不传时从所有实体中移除。
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
   * 从标签名称列表导入标签：根据 importSetting 策略创建或跳过标签，并绑定到实体。
   * 在解析外部数据（如角色卡文件中的标签列表）时由导入流程调用。
   * @param entityKey 实体键。
   * @param names 标签名称列表。
   * @param importSetting 导入策略：none（全部忽略）/ only_existing（仅已有）/ all（创建并绑定）。
   * @returns 导入结果，包含已导入、已忽略和已创建的标签。
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
   * 判断指定标签是否为文件夹类型（folderType !== "NONE"）。
   * 在 UI 需要区分标签和文件夹时调用。
   * @param tagId 目标标签标识。
   * @returns 是文件夹标签时返回 true。
   */
  isFolderTag(tagId: string): boolean {
    const tag = this.requireTag(tagId);
    return tag.folderType !== 'NONE';
  }

  /**
   * 统计每个标签被多少个实体使用。
   * 在 UI 展示标签使用频次或按使用数排序时调用。
   * @returns 标签 ID 到使用次数的映射。
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
   * 按名称不区分大小写查找标签。
   * @param name 标签名称。
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
   * 确保指定标签存在，缺失时抛出错误。
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
   * 深度复制 TagRecord，防止外部代码修改内部状态。
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
   * 把导入过程的统计信息组装为 TagImportResult 结构。
   * @param entityKey 实体键。
   * @param imported 已导入的标签。
   * @param ignored 被忽略的名称。
   * @param created 新建的标签。
   * @returns 导入结果。
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
   * 发布标签事件，通知宿主或其他 Runtime。
   * @param eventName 事件名称（如 tag.created / tag.updated）。
   */
  private publishTag(eventName: string, tag: TagRecord): void {
    const payload: TagEventPayload = {
      tag: this.copyTag(tag),
    };
    this.events.publish<TagEventPayload>(eventName, payload);
  }

  /**
   * 发布标签映射更新事件。
   * @param entityKey 实体键。
   * @param tagIds 该实体的标签 ID 列表。
   */
  private publishMap(entityKey: string, tagIds: Array<string>): void {
    const payload: TagMapEventPayload = {
      entityKey: entityKey,
      tagIds: tagIds.slice(),
    };
    this.events.publish<TagMapEventPayload>('tag.map.updated', payload);
  }
}
