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
 * 在角色编辑或个人资料设置流程中被调用，用于头像的上传、读取、删除和列表展示。
 */
export class AvatarRuntime {
  /**
   * 文件存储适配器，用于将头像文件内容和索引数据写入磁盘。
   */
  private files: TavernFileStore;
  /**
   * 事件总线，用于在头像上传或删除时发布事件通知其他模块。
   */
  private events: EventBus;
  /**
   * 内存中的头像记录映射表，以 "targetType:targetId" 为键，用于快速查找目标对象的头像记录。
   */
  private records: Map<string, AvatarRecord> = new Map<string, AvatarRecord>();
  /**
   * 头像索引文件的存储路径，用于启动时加载和运行时持久化全部头像元信息。
   */
  private indexPath: string = 'tavern-data/users/default/avatars/index.json';

  /**
   * 初始化当前运行时实例，由宿主在应用启动时通过依赖注入创建。
   * @param files 文件存储适配器，用于持久化头像文件内容和索引数据。
   * @param events 事件总线，用于发布头像上传和删除事件。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 上传头像，创建记录、写入磁盘、更新索引并发布上传事件。
   * 在角色编辑或个人资料设置页面中，用户选择并裁剪图片后触发。
   * @param targetType 头像所属目标对象类型（如 character、persona），用于区分不同模块的头像存储目录。
   * @param targetId 头像所属目标对象标识，用于将头像关联到具体的角色或个人资料。
   * @param fileName 头像文件名称，写入磁盘时使用，需经过安全性过滤。
   * @param mimeType 头像文件的 MIME 类型，用于存储和渲染时识别格式。
   * @param content 头像文件内容（base64 编码），用于写入磁盘和后续读取。
   * @param crop 头像裁剪区域配置，用于记录用户在原始图片中选择的裁剪范围。
   * @returns 创建的头像记录副本，供调用方获取完整的头像元信息。
   */
  async uploadAvatar(targetType: string, targetId: string, fileName: string, mimeType: string, content: string, crop: AvatarCrop): Promise<AvatarRecord> {
    const key = this.key(targetType, targetId);
    const now = Date.now();
    const existing = this.records.get(key);
    // 对文件名做安全检查，过滤非法字符
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
   * 获取指定目标对象的头像记录，不存在时返回 undefined。
   * 在角色详情页或个人资料展示页面中被调用，用于加载头像显示。
   * @param targetType 目标对象类型，用于索引查找的键前缀。
   * @param targetId 目标对象标识，与 targetType 组合成查找键。
   * @returns 头像记录副本，未找到返回 undefined。
   */
  async getAvatar(targetType: string, targetId: string): Promise<AvatarRecord | undefined> {
    const record = this.records.get(this.key(targetType, targetId));
    if (record === undefined) {
      return undefined;
    }
    return this.copyRecord(record);
  }

  /**
   * 读取指定目标对象头像文件的原始内容，用于图片渲染或导出。
   * @param targetType 目标对象类型，用于定位头像记录。
   * @param targetId 目标对象标识，与 targetType 组合定位头像记录。
   * @returns 头像文件的文本内容（base64 编码或原始字符串）。
   */
  async readAvatarContent(targetType: string, targetId: string): Promise<string> {
    const record = this.requireRecord(targetType, targetId);
    return this.files.readText(record.path);
  }

  /**
   * 按目标对象类型筛选并返回头像记录列表（深拷贝），用于头像管理列表展示或按类型批量操作。
   * @param targetType 目标对象类型（如 character、persona），用于筛选相同类型的头像记录。
   * @returns 匹配指定类型的头像记录副本列表，按 targetId 排序。
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
   * 删除指定目标对象的头像，从内存映射表和磁盘中移除并发布删除事件。
   * 在角色编辑或个人资料设置页面中，用户点击删除头像按钮时触发。
   * @param targetType 目标对象类型，用于定位要删除的头像记录。
   * @param targetId 目标对象标识，与 targetType 组合定位要删除的头像记录。
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
   * 获取指定目标对象的头像记录，不存在时抛出异常，供内部方法在需要确保记录存在时使用。
   * @param targetType 目标对象类型，用于索引查找的键前缀。
   * @param targetId 目标对象标识，与 targetType 组合成查找键。
   * @returns 头像记录（内部引用）。
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
   * 深拷贝 AvatarRecord，防止外部代码修改内部状态，用于所有对外暴露头像记录的场景。
   * @param record 要复制的头像记录，原记录不会被修改。
   * @returns 深拷贝后的头像记录，调用方可安全修改。
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
   * 深拷贝 AvatarCrop，防止外部代码修改内部状态，用于所有对外暴露裁剪区域的场景。
   * @param crop 要复制的裁剪区域，原对象不会被修改。
   * @returns 深拷贝后的裁剪区域，调用方可安全修改。
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
