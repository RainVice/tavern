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
 * 在对话流程中由聊天 UI 层调用以管理角色表情图（uploadSprite / deleteSprite / setExpression / getExpression），
 * 在角色导入流程中由 CharacterRuntime 调用以导入 Risu 格式表情图（importRisuSprites）。
 */
export class SpriteRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private records: Map<string, SpriteRecord> = new Map<string, SpriteRecord>();
  private selections: Map<string, SpriteSelectionRecord> = new Map<string, SpriteSelectionRecord>();
  private rootPath: string = 'tavern-data/users/default/characters';

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器，用于读写表情图图片文件。
   * @param events 事件总线实例，用于在表情图上传、删除、表情切换时发布事件。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 上传一张表情图片，写入文件存储并更新内存索引，发布上传事件。
   * 由 UI 层在用户上传角色表情图时调用，如果 spriteName 已存在则覆盖旧文件。
   * @param params 表情图上传参数，包含角色名、子文件夹、图片内容和文件名等信息，由 UI 表单收集。
   * @returns 上传后的表情图记录副本。
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
   * 从 Risu 格式导入一组表情图数据，批量上传到当前角色下。
   * 由 CharacterRuntime 在导入角色数据时调用，将 Risu 格式的表情列表转换为 SpriteRecord 存储。
   * @param characterName 目标角色名称，传入 uploadSprite 作为 characterName。
   * @param sprites Risu 格式的表情图导入数据列表，每个元素包含标签和图片内容。
   * @returns 上传后的表情图记录列表。
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
   * 查询指定角色和子文件夹下的所有表情图列表。
   * 由 UI 层在初始化表情选择器或刷新表情列表时调用。
   * @param characterName 角色名称，用于限定查询范围。
   * @param subfolderName 子文件夹名称，用于限定查询范围。
   * @returns 匹配的表情图记录列表副本，按标签和名称排序。
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
   * 设置指定角色和子文件夹的当前表情状态，并发布表情变更事件。
   * 由 UI 层在用户切换角色表情时调用，更新当前表情选择状态并通知宿主刷新显示。
   * @param characterName 角色名称，用于定位在哪个角色下切换表情。
   * @param subfolderName 子文件夹名称，用于确定表情变更发生的子文件夹范围。
   * @param expression 表情名称（如 "happy"），标识当前表情的语义（如开心、难过等）。
   * @param spriteName 对应的立绘名称，用于查找具体的表情图片文件。
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
   * 获取指定角色和子文件夹的当前表情选择状态。
   * 由 UI 层在初始化聊天界面或恢复角色显示时调用，获取该角色当前应该展示的表情。
   * @param characterName 角色名称。
   * @param subfolderName 子文件夹名称。
   * @returns 表情选择记录副本；未设置时返回空选择记录（expression 和 spriteName 为空字符串）。
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
   * 删除指定立绘及其文件，并清理内存索引和选择状态。
   * 由 UI 层在用户删除角色表情图时调用，同时清理文件存储和内存中的相关数据。
   * @param characterName 角色名称，用于定位要删除的表情图所属角色。
   * @param subfolderName 子文件夹名称，用于定位要删除的表情图所属子文件夹。
   * @param spriteName 要删除的立绘名称，对应 SpriteRecord.spriteName。
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
   * 查找指定角色和子文件夹下的表情图记录，不存在时抛出异常。
   * @param characterName 角色名称。
   * @param subfolderName 子文件夹名称。
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
    // 安全处理文件名。
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
   * 生成角色和子文件夹的选择状态键名。
   * @param characterName 角色名称。
   * @param subfolderName 子文件夹名称。
   * @returns 格式为 "characterName:subfolderName" 的键名。
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
   * 深拷贝表情图记录。
   * @param record 待拷贝的记录。
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
   * 深拷贝表情选择记录。
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
