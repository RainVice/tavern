import { EventBus } from '../runtime/EventBus';
import type {
  TagCreateParams,
  TagEventPayload,
  TagImportResult,
  TagMapEventPayload,
  TagRecord,
} from './TagModels';

export class TagRuntime {
  private events: EventBus;
  private tags: Map<string, TagRecord> = new Map<string, TagRecord>();
  private tagMap: Map<string, Array<string>> = new Map<string, Array<string>>();
  private tagCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

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

  deleteTag(tagId: string): void {
    this.requireTag(tagId);
    this.tags.delete(tagId);
    this.removeTagFromMap(tagId);
  }

  listTags(sortMode: string = 'manual'): Array<TagRecord> {
    return this.sortTags(Array.from(this.tags.values()), sortMode);
  }

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

  renameTagKey(oldKey: string, newKey: string): void {
    const value = this.tagMap.get(oldKey);
    this.tagMap.set(newKey, value === undefined ? new Array<string>() : value.slice());
    this.tagMap.delete(oldKey);
    this.publishMap(newKey, this.tagMap.get(newKey) as Array<string>);
  }

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

  isFolderTag(tagId: string): boolean {
    const tag = this.requireTag(tagId);
    return tag.folderType !== 'NONE';
  }

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

  private toImportResult(entityKey: string, imported: Array<TagRecord>, ignored: Array<string>, created: Array<TagRecord>): TagImportResult {
    return {
      entityKey: entityKey,
      imported: imported,
      ignored: ignored,
      created: created,
    };
  }

  private publishTag(eventName: string, tag: TagRecord): void {
    const payload: TagEventPayload = {
      tag: this.copyTag(tag),
    };
    this.events.publish<TagEventPayload>(eventName, payload);
  }

  private publishMap(entityKey: string, tagIds: Array<string>): void {
    const payload: TagMapEventPayload = {
      entityKey: entityKey,
      tagIds: tagIds.slice(),
    };
    this.events.publish<TagMapEventPayload>('tag.map.updated', payload);
  }
}
