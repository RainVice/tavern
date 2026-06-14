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
   * 记录副本列表，由当前实例内部维护。
   */
  private records: Map<string, SpriteRecord> = new Map<string, SpriteRecord>();
  /**
   * selections 列表，由当前实例内部维护。
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
   * 执行 uploadSprite 的内部处理步骤，供当前模块复用。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  async uploadSprite(params: SpriteUploadParams): Promise<SpriteRecord> {
    // character 名称。
    const characterName = safePathSegment(params.characterName, 'character');
    // subfolder 名称。
    const subfolderName = this.safeOptionalSegment(params.subfolderName);
    // sprite 名称。
    const spriteName = safePathSegment(params.spriteName, 'sprite');
    // file 名称。
    const fileName = `${spriteName}${this.extension(params.fileName)}`;
    // 键名。
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
   * 从外部数据导入Risu Sprites 列表，转换为当前运行时的数据结构。
   * @param characterName 角色名称。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async importRisuSprites(characterName: string, sprites: Array<RisuSpriteImport>): Promise<Array<SpriteRecord>> {
    const imported = new Array<SpriteRecord>();
    for (let index = 0; index < sprites.length; index += 1) {
      // 调用参数。
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
   * 读取Sprites列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param characterName 角色名称。
   * @param subfolderName subfolder名称。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 设置表情状态，用于切换运行时状态或保存配置。
   * @param characterName 角色名称。
   * @param subfolderName subfolder名称。

   * @param spriteName 立绘名称。
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
   * 读取指定Expression，不存在时抛出错误。
   * @param characterName 角色名称。
   * @param subfolderName subfolder名称。
   * @returns 更新或读取后的记录副本。
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
   * 删除指定立绘，并清理相关索引或资源引用。
   * @param characterName 角色名称。
   * @param subfolderName subfolder名称。
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
   * 读取必须存在的Record 值，缺失时抛出错误。
   * @param characterName 角色名称。
   * @param subfolderName subfolder名称。
   * @param spriteName 立绘名称。
   */
  private requireRecord(characterName: string, subfolderName: string, spriteName: string): SpriteRecord {
    const record = this.records.get(this.key(characterName, subfolderName, spriteName));
    if (record === undefined) {
      throw new Error(`Sprite not found: ${characterName}:${subfolderName}:${spriteName}`);
    }
    return record;
  }
  private spritePath(characterName: string, subfolderName: string, fileName: string): string {
    if (subfolderName.length === 0) {
      return `${this.rootPath}/${characterName}/sprites/${fileName}`;
    }
    return `${this.rootPath}/${characterName}/${subfolderName}/${fileName}`;
  }
  private extension(fileName: string): string {
    // safe 名称。
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
  private safeOptionalSegment(value: string): string {
    if (value.length === 0) {
      return '';
    }
    return safePathSegment(value, '');
  }
  private key(characterName: string, subfolderName: string, spriteName: string): string {
    return `${characterName}:${subfolderName}:${spriteName}`;
  }

  /**
   * 读取或解析ionKey，调用方应处理不存在或不匹配的情况。
   * @param characterName 角色名称。
   * @param subfolderName subfolder名称。
   */
  private selectionKey(characterName: string, subfolderName: string): string {
    return `${characterName}:${subfolderName}`;
  }
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
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
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
   * 复制Selection 值，避免外部修改内部状态。
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
