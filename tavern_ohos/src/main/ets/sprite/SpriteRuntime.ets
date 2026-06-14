import { EventBus } from '../runtime/EventBus';
import { safeFileName, safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  RisuSpriteImport,
  SpriteDeletedPayload,
  SpriteExpressionChangedPayload,
  SpriteRecord,
  SpriteSelectionRecord,
  SpriteUploadedPayload,
  SpriteUploadParams,
} from './SpriteModels';

/**
 * 提供表情图相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class SpriteRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 精灵图记录映射表，以 "角色名:子目录:立绘名" 为键维护所有上传立绘的内存索引。
   */
  private records: Map<string, SpriteRecord> = new Map<string, SpriteRecord>();
  /**
   * 表情选择状态映射表，以 "角色名:子目录" 为键维护当前表情选择索引。
   */
  private selections: Map<string, SpriteSelectionRecord> = new Map<string, SpriteSelectionRecord>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/characters';

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
   * 上传一张表情图到存储，覆盖已存在的同名立绘，然后发布 `sprite.uploaded` 事件。
   * @param params 上传参数，包含角色名、子目录、标签、文件名、MIME 类型和内容。
   * @returns 创建或更新后的精灵图记录。
   */
  async uploadSprite(params: SpriteUploadParams): Promise<SpriteRecord> {
    const characterName = safePathSegment(params.characterName, 'character');
    const subfolderName = this.safeOptionalSegment(params.subfolderName);
    const spriteName = safePathSegment(params.spriteName, 'sprite');
    const fileName = `${spriteName}${this.extension(params.fileName)}`;
    const key = this.key(characterName, subfolderName, spriteName);
    const existing = this.records.get(key);
    if (existing !== undefined) {
      await this.files.delete(existing.path);
    }
    const now = Date.now();
    const record: SpriteRecord = {
      schemaVersion: 1,
      characterName: characterName,
      subfolderName: subfolderName,
      label: params.label,
      spriteName: spriteName,
      fileName: fileName,
      mimeType: params.mimeType,
      path: this.spritePath(characterName, subfolderName, fileName),
      content: params.content,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(key, this.copyRecord(record));
    await this.files.writeText(record.path, record.content, false);
    const payload: SpriteUploadedPayload = {
      sprite: this.copyRecord(record),
    };
    this.events.publish<SpriteUploadedPayload>('sprite.uploaded', payload);
    return this.copyRecord(record);
  }

  /**
   * 从 RisuAI 格式导入多个表情图，逐个上传并返回导入结果。
   * @param characterName 角色名称。
   * @param sprites 来源数据中的表情图列表。
   * @returns 导入成功的精灵图记录列表。
   */
  async importRisuSprites(characterName: string, sprites: Array<RisuSpriteImport>): Promise<Array<SpriteRecord>> {
    const imported = new Array<SpriteRecord>();
    for (let index = 0; index < sprites.length; index += 1) {
      const params: SpriteUploadParams = {
        characterName: characterName,
        subfolderName: '',
        label: sprites[index].label,
        spriteName: sprites[index].label,
        fileName: `${sprites[index].label}.png`,
        mimeType: 'image/png',
        content: sprites[index].content,
      };
      imported.push(await this.uploadSprite(params));
    }
    return imported;
  }

  /**
   * 查询指定角色和子目录下的表情图列表，返回每个记录的副本。
   * @param characterName 角色名称。
   * @param subfolderName 子目录名称。
   * @returns 符合条件的精灵图记录列表。
   */
  async listSprites(characterName: string, subfolderName: string): Promise<Array<SpriteRecord>> {
    const normalizedCharacter = safePathSegment(characterName, 'character');
    const normalizedSubfolder = this.safeOptionalSegment(subfolderName);
    const result = new Array<SpriteRecord>();
    this.records.forEach((record: SpriteRecord) => {
      if (record.characterName === normalizedCharacter && record.subfolderName === normalizedSubfolder) {
        result.push(this.copyRecord(record));
      }
    });
    result.sort((left: SpriteRecord, right: SpriteRecord) => left.label.localeCompare(right.label) || left.spriteName.localeCompare(right.spriteName));
    return result;
  }

  /**
   * 为指定角色和子目录设置当前表情状态，并发布 `sprite.expression.changed` 事件。
   * @param characterName 角色名称。
   * @param subfolderName 子目录名称。
   * @param expression 表情标签。
   * @param spriteName 立绘名称。
   * @returns 更新后的表情选择记录。
   */
  async setExpression(characterName: string, subfolderName: string, expression: string, spriteName: string): Promise<SpriteSelectionRecord> {
    const normalizedCharacter = safePathSegment(characterName, 'character');
    const normalizedSubfolder = this.safeOptionalSegment(subfolderName);
    const normalizedSprite = this.safeOptionalSegment(spriteName);
    let path = '';
    if (normalizedSprite.length > 0) {
      path = this.requireRecord(normalizedCharacter, normalizedSubfolder, normalizedSprite).path;
    }
    const selection: SpriteSelectionRecord = {
      characterName: normalizedCharacter,
      subfolderName: normalizedSubfolder,
      expression: expression,
      spriteName: normalizedSprite,
      path: path,
      updatedAt: Date.now(),
    };
    this.selections.set(this.selectionKey(normalizedCharacter, normalizedSubfolder), this.copySelection(selection));
    const payload: SpriteExpressionChangedPayload = {
      characterName: normalizedCharacter,
      subfolderName: normalizedSubfolder,
      expression: expression,
      spriteName: normalizedSprite,
      path: path,
    };
    this.events.publish<SpriteExpressionChangedPayload>('sprite.expression.changed', payload);
    return this.copySelection(selection);
  }

  /**
   * 获取指定角色和子目录的当前表情选择状态，未设置时返回空记录。
   * @param characterName 角色名称。
   * @param subfolderName 子目录名称。
   * @returns 当前的精灵图选择记录，若无选择则返回空记录。
   */
  getExpression(characterName: string, subfolderName: string): SpriteSelectionRecord {
    const normalizedCharacter = safePathSegment(characterName, 'character');
    const normalizedSubfolder = this.safeOptionalSegment(subfolderName);
    const selection = this.selections.get(this.selectionKey(normalizedCharacter, normalizedSubfolder));
    if (selection === undefined) {
      return this.emptySelection(normalizedCharacter, normalizedSubfolder);
    }
    return this.copySelection(selection);
  }

  /**
   * 删除指定立绘及其文件，并清理选择状态（若当前选择指向该立绘），最后发布 `sprite.deleted` 事件。
   * @param characterName 角色名称。
   * @param subfolderName 子目录名称。
   * @param spriteName 立绘名称。
   */
  async deleteSprite(characterName: string, subfolderName: string, spriteName: string): Promise<void> {
    const normalizedCharacter = safePathSegment(characterName, 'character');
    const normalizedSubfolder = this.safeOptionalSegment(subfolderName);
    const normalizedSprite = safePathSegment(spriteName, 'sprite');
    const record = this.requireRecord(normalizedCharacter, normalizedSubfolder, normalizedSprite);
    this.records.delete(this.key(normalizedCharacter, normalizedSubfolder, normalizedSprite));
    await this.files.delete(record.path);
    const selectionKey = this.selectionKey(normalizedCharacter, normalizedSubfolder);
    const selection = this.selections.get(selectionKey);
    if (selection !== undefined && selection.spriteName === normalizedSprite) {
      this.selections.set(selectionKey, this.emptySelection(normalizedCharacter, normalizedSubfolder));
    }
    const payload: SpriteDeletedPayload = {
      characterName: normalizedCharacter,
      subfolderName: normalizedSubfolder,
      spriteName: normalizedSprite,
      path: record.path,
    };
    this.events.publish<SpriteDeletedPayload>('sprite.deleted', payload);
  }

  /**
   * 查找指定键的记录，若不存在则抛出异常。
   * @param characterName 角色名称。
   * @param subfolderName 子目录名称。
   * @param spriteName 立绘名称。
   * @returns 匹配的精灵图记录。
   */
  private requireRecord(characterName: string, subfolderName: string, spriteName: string): SpriteRecord {
    const record = this.records.get(this.key(characterName, subfolderName, spriteName));
    if (record === undefined) {
      throw new Error(`Sprite not found: ${characterName}:${subfolderName}:${spriteName}`);
    }
    return record;
  }

  /**
   * 根据角色名、子目录和文件名拼接文件的存储路径。
   */
  private spritePath(characterName: string, subfolderName: string, fileName: string): string {
    if (subfolderName.length === 0) {
      return `${this.rootPath}/${characterName}/sprites/${fileName}`;
    }
    return `${this.rootPath}/${characterName}/${subfolderName}/${fileName}`;
  }

  /**
   * 从文件名中提取扩展名，非图片扩展名统一替换为 `.png`。
   */
  private extension(fileName: string): string {
    const safeName = safeFileName(fileName, 'sprite.png');
    const dotIndex = safeName.lastIndexOf('.');
    if (dotIndex < 0) {
      return '.png';
    }
    const extension = safeName.substring(dotIndex).toLowerCase();
    if (extension === '.png' || extension === '.jpg' || extension === '.jpeg' || extension === '.webp' || extension === '.gif') {
      return extension;
    }
    return '.png';
  }

  /**
   * 对可选子目录名执行安全转义，空字符串保持不变。
   */
  private safeOptionalSegment(value: string): string {
    if (value.length === 0) {
      return '';
    }
    return safePathSegment(value, '');
  }

  /**
   * 生成精灵图的内部映射键：`角色名:子目录:立绘名`。
   */
  private key(characterName: string, subfolderName: string, spriteName: string): string {
    return `${characterName}:${subfolderName}:${spriteName}`;
  }

  /**
   * 生成选择状态的内部映射键：`角色名:子目录`。
   * @param characterName 角色名称。
   * @param subfolderName 子目录名称。
   */
  private selectionKey(characterName: string, subfolderName: string): string {
    return `${characterName}:${subfolderName}`;
  }

  /**
   * 返回一个空的精灵图选择记录，用于默认/未选择状态。
   */
  private emptySelection(characterName: string, subfolderName: string): SpriteSelectionRecord {
    return {
      characterName: characterName,
      subfolderName: subfolderName,
      expression: '',
      spriteName: '',
      path: '',
      updatedAt: 0,
    };
  }

  /**
   * 深复制精灵图记录，防止外部修改影响内部状态。
   * @param record 原始记录。
   * @returns 复制后的新记录。
   */
  private copyRecord(record: SpriteRecord): SpriteRecord {
    return {
      schemaVersion: record.schemaVersion,
      characterName: record.characterName,
      subfolderName: record.subfolderName,
      label: record.label,
      spriteName: record.spriteName,
      fileName: record.fileName,
      mimeType: record.mimeType,
      path: record.path,
      content: record.content,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  /**
   * 深复制精灵图选择记录，防止外部修改影响内部状态。
   * @param selection 原始选择记录。
   * @returns 复制后的新记录。
   */
  private copySelection(selection: SpriteSelectionRecord): SpriteSelectionRecord {
    return {
      characterName: selection.characterName,
      subfolderName: selection.subfolderName,
      expression: selection.expression,
      spriteName: selection.spriteName,
      path: selection.path,
      updatedAt: selection.updatedAt,
    };
  }
}
