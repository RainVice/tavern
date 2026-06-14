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
 * 头像模块的无 UI 运行时服务，负责头像上传、读取、删除等状态管理，
 * 以及底层文件读写和事件发布。
 */
export class AvatarRuntime {
  /**
   * 文件存储适配器，用于持久化头像文件。
   */
  private files: TavernFileStore;
  /**
   * 事件总线，用于广播头像变更事件。
   */
  private events: EventBus;
  /**
   * 内存中的头像记录映射表，以 "{targetType}:{targetId}" 为键。
   */
  private records: Map<string, AvatarRecord> = new Map<string, AvatarRecord>();
  /**
   * 头像索引文件在存储中的路径。
   */
  private indexPath: string = 'tavern-data/users/default/avatars/index.json';

  /**
   * 创建 AvatarRuntime 实例。
   * @param files  用于读写头像文件的存储适配器。
   * @param events 用于发布头像相关事件的事件总线。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 上传头像：将给定内容写入文件存储，更新内存索引，并发布 avatar.uploaded 事件。
   *
   * @param targetType 目标类型（如 "character"、"persona"）。
   * @param targetId   目标对象的唯一标识符。
   * @param fileName   头像文件的原始名称。
   * @param mimeType   头像文件的 MIME 类型（如 "image/png"）。
   * @param content    头像文件的 base64 编码内容。
   * @param crop       头像的裁剪区域坐标。
   * @returns 上传成功后的完整头像记录副本。
   */
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

  /**
   * 获取指定目标的头像记录。如果不存在返回 undefined 而非抛出异常。
   *
   * @param targetType 目标类型（如 "character"、"persona"）。
   * @param targetId   目标对象的唯一标识符。
   * @returns 头像记录的副本，不存在时返回 undefined。
   */
  async getAvatar(targetType: string, targetId: string): Promise<AvatarRecord | undefined> {
    const record = this.records.get(this.key(targetType, targetId));
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  /**
   * 读取指定头像的文件内容（base64 字符串）。
   *
   * @param targetType 目标类型。
   * @param targetId   目标对象的唯一标识符。
   * @returns 头像文件的原始文本内容。
   */
  async readAvatarContent(targetType: string, targetId: string): Promise<string> {
    const record = this.requireRecord(targetType, targetId);
    return this.files.readText(record.path);
  }

  /**
   * 按目标类型列出所有头像记录，结果按 targetId 字典序排列。
   *
   * @param targetType 要筛选的目标类型。
   * @returns 匹配的头像记录列表，每条记录均为独立副本。
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
   * 删除指定目标的头像：从内存索引移除、删除存储文件、更新索引文件，
   * 并发布 avatar.deleted 事件。
   *
   * @param targetType 目标类型。
   * @param targetId   目标对象的唯一标识符。
   */
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

  /**
   * 获取指定目标的头像记录，不存在时抛出异常。
   *
   * @param targetType 目标类型。
   * @param targetId   目标对象的唯一标识符。
   * @returns 头像记录。
   * @throws 当记录不存在时抛 Error。
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
   * 创建 AvatarRecord 的深层副本，防止调用方修改内部状态。
   *
   * @param record 源记录。
   * @returns 完整的独立副本。
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
   * 创建 AvatarCrop 的浅层副本。
   *
   * @param crop 源裁剪坐标。
   * @returns 相同的坐标值构成的新对象。
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
