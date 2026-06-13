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

export class SpriteRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private records: Map<string, SpriteRecord> = new Map<string, SpriteRecord>();
  private selections: Map<string, SpriteSelectionRecord> = new Map<string, SpriteSelectionRecord>();
  private rootPath: string = 'tavern-data/users/default/characters';

  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

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

  getExpression(characterName: string, subfolderName: string): SpriteSelectionRecord {
    const normalizedCharacter = safePathSegment(characterName, 'character');
    const normalizedSubfolder = this.safeOptionalSegment(subfolderName);
    const selection = this.selections.get(this.selectionKey(normalizedCharacter, normalizedSubfolder));
    if (selection === undefined) {
      return this.emptySelection(normalizedCharacter, normalizedSubfolder);
    }
    return this.copySelection(selection);
  }

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
