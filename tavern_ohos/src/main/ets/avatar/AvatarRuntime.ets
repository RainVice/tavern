import { EventBus } from '../runtime/EventBus';
import { safeFileName, safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  AvatarCrop,
  AvatarDeletedPayload,
  AvatarIndexData,
  AvatarRecord,
  AvatarUploadedPayload,
} from './AvatarModels';

export class AvatarRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private records: Map<string, AvatarRecord> = new Map<string, AvatarRecord>();
  private indexPath: string = 'tavern-data/users/default/avatars/index.json';

  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  async uploadAvatar(targetType: string, targetId: string, fileName: string, mimeType: string, content: string, crop: AvatarCrop): Promise<AvatarRecord> {
    const key = this.key(targetType, targetId);
    const now = Date.now();
    const existing = this.records.get(key);
    const safeName = safeFileName(fileName);
    const record: AvatarRecord = {
      schemaVersion: 1,
      targetType: targetType,
      targetId: targetId,
      fileName: safeName,
      mimeType: mimeType,
      path: this.avatarPath(targetType, targetId, safeName),
      content: content,
      crop: this.copyCrop(crop),
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(key, this.copyRecord(record));
    await this.files.writeText(record.path, record.content, false);
    await this.persistIndex();
    const payload: AvatarUploadedPayload = {
      avatar: this.copyRecord(record),
    };
    this.events.publish<AvatarUploadedPayload>('avatar.uploaded', payload);
    return this.copyRecord(record);
  }

  async getAvatar(targetType: string, targetId: string): Promise<AvatarRecord | undefined> {
    const record = this.records.get(this.key(targetType, targetId));
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  async readAvatarContent(targetType: string, targetId: string): Promise<string> {
    const record = this.requireRecord(targetType, targetId);
    return this.files.readText(record.path);
  }

  async listByTargetType(targetType: string): Promise<Array<AvatarRecord>> {
    const result = new Array<AvatarRecord>();
    this.records.forEach((record: AvatarRecord) => {
      if (record.targetType === targetType) {
        result.push(this.copyRecord(record));
      }
    });
    result.sort((left: AvatarRecord, right: AvatarRecord) => left.targetId.localeCompare(right.targetId));
    return result;
  }

  async deleteAvatar(targetType: string, targetId: string): Promise<void> {
    const key = this.key(targetType, targetId);
    const record = this.requireRecord(targetType, targetId);
    this.records.delete(key);
    await this.files.delete(record.path);
    await this.persistIndex();
    const payload: AvatarDeletedPayload = {
      targetType: targetType,
      targetId: targetId,
      path: record.path,
    };
    this.events.publish<AvatarDeletedPayload>('avatar.deleted', payload);
  }

  private requireRecord(targetType: string, targetId: string): AvatarRecord {
    const record = this.records.get(this.key(targetType, targetId));
    if (record === undefined) {
      throw new Error(`Avatar not found: ${targetType}:${targetId}`);
    }
    return record;
  }

  private async persistIndex(): Promise<void> {
    const avatars = new Array<AvatarRecord>();
    this.records.forEach((record: AvatarRecord) => {
      avatars.push(this.copyRecord(record));
    });
    avatars.sort((left: AvatarRecord, right: AvatarRecord) => this.key(left.targetType, left.targetId).localeCompare(this.key(right.targetType, right.targetId)));
    const data: AvatarIndexData = {
      avatars: avatars,
    };
    await this.files.writeText(this.indexPath, JSON.stringify(data), true);
  }

  private avatarPath(targetType: string, targetId: string, fileName: string): string {
    if (targetType === 'character') {
      return `tavern-data/users/default/characters/${safePathSegment(targetId)}/avatar.png`;
    }
    if (targetType === 'persona') {
      return `tavern-data/users/default/personas/${safeFileName(targetId)}`;
    }
    return `tavern-data/users/default/assets/${safePathSegment(targetType, 'avatar')}/${fileName}`;
  }

  private key(targetType: string, targetId: string): string {
    return `${targetType}:${targetId}`;
  }

  private copyRecord(record: AvatarRecord): AvatarRecord {
    return {
      schemaVersion: record.schemaVersion,
      targetType: record.targetType,
      targetId: record.targetId,
      fileName: record.fileName,
      mimeType: record.mimeType,
      path: record.path,
      content: record.content,
      crop: this.copyCrop(record.crop),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  private copyCrop(crop: AvatarCrop): AvatarCrop {
    return {
      x: crop.x,
      y: crop.y,
      width: crop.width,
      height: crop.height,
    };
  }
}
