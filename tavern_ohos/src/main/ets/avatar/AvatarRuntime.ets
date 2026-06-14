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

/**
 * 提供头像相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class AvatarRuntime {
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
  private records: Map<string, AvatarRecord> = new Map<string, AvatarRecord>();
  /**
   * index 路径。
   */
  private indexPath: string = 'tavern-data/users/default/avatars/index.json';

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
   * 执行 uploadAvatar 的内部处理步骤，供当前模块复用。

   * @param targetId 目标目标对象标识。
   * @param fileName 文件名称。

   * @param content 要写入或追加的文本内容。
   */
  async uploadAvatar(targetType: string, targetId: string, fileName: string, mimeType: string, content: string, crop: AvatarCrop): Promise<AvatarRecord> {
    // 键名。
    const key = this.key(targetType, targetId);
    const now = Date.now();
    const existing = this.records.get(key);
    // safe 名称。
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

  /**
   * 读取指定头像，不存在时抛出错误。

   * @param targetId 目标目标对象标识。
   * @returns 更新或读取后的记录副本。
   */
  async getAvatar(targetType: string, targetId: string): Promise<AvatarRecord | undefined> {
    const record = this.records.get(this.key(targetType, targetId));
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  /**
   * 读取Avatar Content 值，并转换为运行时使用的数据结构。

   * @param targetId 目标目标对象标识。
   */
  async readAvatarContent(targetType: string, targetId: string): Promise<string> {
    const record = this.requireRecord(targetType, targetId);
    return this.files.readText(record.path);
  }

  /**
   * 读取ByTargetType列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 删除指定头像，并清理相关索引或资源引用。

   * @param targetId 目标目标对象标识。
   */
  async deleteAvatar(targetType: string, targetId: string): Promise<void> {
    // 键名。
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

  /**
   * 读取必须存在的Record 值，缺失时抛出错误。

   * @param targetId 目标目标对象标识。
   */
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

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
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

  /**
   * 复制Crop 值，避免外部修改内部状态。
   */
  private copyCrop(crop: AvatarCrop): AvatarCrop {
    return {
      x: crop.x,
      y: crop.y,
      width: crop.width,
      height: crop.height,
    };
  }
}
