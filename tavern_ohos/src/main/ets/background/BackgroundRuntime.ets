import { AssetRuntime } from '../asset/AssetRuntime';
import type { AssetCreateParams, AssetRecord } from '../asset/AssetModels';
import { EventBus } from '../runtime/EventBus';
import type { TavernFileStore } from '../storage/TavernFileStore';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ThumbnailRuntime } from '../thumbnail/ThumbnailRuntime';
import type { ThumbnailDimensions, ThumbnailRecord } from '../thumbnail/ThumbnailModels';
import type {
  BackgroundDeletedPayload,
  BackgroundFolderRecord,
  BackgroundImportedPayload,
  BackgroundImportParams,
  BackgroundIndexData,
  BackgroundListItem,
  BackgroundListResult,
  BackgroundRecord,
  BackgroundRenamedPayload,
} from './BackgroundModels';

/**
 * 提供背景图相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class BackgroundRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 资源运行时实例，用于管理背景图资产。
   */
  private assets: AssetRuntime;
  /**
   * 缩略图运行时实例，用于生成背景图缩略图。
   */
  private thumbnails: ThumbnailRuntime;
  /**
   * 主题运行时实例，用于同步背景图激活。
   */
  private themes: ThemeRuntime;
  /**
   * 内存中的背景图记录映射表。
   */
  private records: Map<string, BackgroundRecord> = new Map<string, BackgroundRecord>();
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data/users/default/assets/backgrounds';

  /**
   * 注入背景图运行时依赖并初始化实例状态。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   */
  constructor(files: TavernFileStore, events: EventBus, assets: AssetRuntime, thumbnails: ThumbnailRuntime, themes: ThemeRuntime) {
    this.files = files;
    this.events = events;
    this.assets = assets;
    this.thumbnails = thumbnails;
    this.themes = themes;
  }

  /**
   * 从外部数据导入Background 值，转换为当前运行时的数据结构。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 导入的背景图记录副本。
   */
  async importBackground(params: BackgroundImportParams): Promise<BackgroundRecord> {
    const now = Date.now();
    const asset = await this.assets.importAsset(this.toAssetParams(params));
    const thumbnail = await this.thumbnails.generateThumbnail({
      type: 'bg',
      fileName: asset.fileName,
      sourcePath: asset.path,
      content: params.thumbnailContent,
      width: 160,
      height: 90,
      animated: params.isAnimated,
    });
    const existing = this.records.get(params.id);
    const record: BackgroundRecord = {
      schemaVersion: 1,
      id: params.id,
      fileName: asset.fileName,
      path: asset.path,
      content: params.content,
      mimeType: params.mimeType,
      metadataJson: params.metadataJson,
      isAnimated: params.isAnimated,
      folderIds: this.copyStrings(params.folderIds),
      thumbnailPath: thumbnail.path,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(record.id, this.copyRecord(record));
    await this.persistIndex();
    const payload: BackgroundImportedPayload = {
      background: this.copyRecord(record),
    };
    this.events.publish<BackgroundImportedPayload>('background.imported', payload);
    return this.copyRecord(record);
  }

  /**
   * 读取Backgrounds列表，返回副本，调用方修改返回值不会直接改变内部状态。
   */
  async listBackgrounds(): Promise<BackgroundListResult> {
    const images = new Array<BackgroundListItem>();
    const records = await this.listRecords();
    for (let index = 0; index < records.length; index += 1) {
      const item: BackgroundListItem = {
        filename: records[index].fileName,
        isAnimated: records[index].isAnimated,
      };
      images.push(item);
    }
    const config: ThumbnailDimensions = this.thumbnails.getConfiguredDimensions('bg');
    return {
      images: images,
      config: config,
    };
  }

  /**
   * 读取Folders列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 背景图列表副本
   */
  async listFolders(): Promise<Array<BackgroundFolderRecord>> {
    const folderIds = new Set<string>();
    this.records.forEach((record: BackgroundRecord) => {
      for (let index = 0; index < record.folderIds.length; index += 1) {
        folderIds.add(record.folderIds[index]);
      }
    });
    const ids = Array.from(folderIds).sort();
    const result = new Array<BackgroundFolderRecord>();
    for (let index = 0; index < ids.length; index += 1) {
      const folder: BackgroundFolderRecord = {
        id: ids[index],
        name: ids[index],
      };
      result.push(folder);
    }
    return result;
  }

  /**
   * 将指定背景图设为当前激活状态，并同步主题。
   * @param fileName 文件名称。
   */
  async activateBackground(fileName: string): Promise<void> {
    this.requireRecordByFileName(fileName);
    await this.themes.setActiveBackground(fileName);
  }

  /**
   * 更新背景图状态，必要时写回存储并发布对应事件。
   * @param backgroundId 目标背景标识。
   * @param newFileName 新记录文件名称。
   */
  async renameBackground(backgroundId: string, newFileName: string): Promise<BackgroundRecord> {
    const record = this.requireRecord(backgroundId);
    // old File 名称。
    const oldFileName = record.fileName;
    await this.thumbnails.invalidateThumbnail('bg', oldFileName);
    const asset: AssetRecord = await this.assets.renameAsset(backgroundId, newFileName);
    const thumbnail: ThumbnailRecord = await this.thumbnails.generateThumbnail({
      type: 'bg',
      fileName: asset.fileName,
      sourcePath: asset.path,
      content: record.content,
      width: 160,
      height: 90,
      animated: record.isAnimated,
    });
    const updated = this.copyRecord(record);
    updated.fileName = asset.fileName;
    updated.path = asset.path;
    updated.thumbnailPath = thumbnail.path;
    updated.updatedAt = Date.now();
    this.records.set(backgroundId, this.copyRecord(updated));
    await this.persistIndex();
    const payload: BackgroundRenamedPayload = {
      oldFileName: oldFileName,
      background: this.copyRecord(updated),
    };
    this.events.publish<BackgroundRenamedPayload>('background.renamed', payload);
    return this.copyRecord(updated);
  }

  /**
   * 删除指定背景图，并清理相关索引或资源引用。
   * @param backgroundId 目标背景标识。
   */
  async deleteBackground(backgroundId: string): Promise<void> {
    const record = this.requireRecord(backgroundId);
    this.records.delete(backgroundId);
    await this.assets.deleteAsset(backgroundId);
    await this.thumbnails.invalidateThumbnail('bg', record.fileName);
    if (this.themes.getActiveBackground() === record.fileName) {
      await this.themes.setActiveBackground('');
    }
    await this.persistIndex();
    const payload: BackgroundDeletedPayload = {
      backgroundId: backgroundId,
      fileName: record.fileName,
    };
    this.events.publish<BackgroundDeletedPayload>('background.deleted', payload);
  }

  /**
   * 读取必须存在的Record 值，缺失时抛出错误。
   * @param backgroundId 目标背景标识。
   */
  private requireRecord(backgroundId: string): BackgroundRecord {
    const record = this.records.get(backgroundId);
    if (record === undefined) {
      throw new Error(`Background not found: ${backgroundId}`);
    }
    return record;
  }

  /**
   * 读取必须存在的Record By File 名称，缺失时抛出错误。
   * @param fileName 文件名称。
   */
  private requireRecordByFileName(fileName: string): BackgroundRecord {
    let found: BackgroundRecord | undefined = undefined;
    this.records.forEach((record: BackgroundRecord) => {
      if (record.fileName === fileName) {
        found = record;
      }
    });
    if (found === undefined) {
      throw new Error(`Background not found: ${fileName}`);
    }
    return found;
  }

  /**
   * 读取Records列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 背景图列表副本
   */
  private async listRecords(): Promise<Array<BackgroundRecord>> {
    const result = new Array<BackgroundRecord>();
    this.records.forEach((record: BackgroundRecord) => {
      result.push(this.copyRecord(record));
    });
    result.sort((left: BackgroundRecord, right: BackgroundRecord) => left.fileName.localeCompare(right.fileName));
    return result;
  }
  private async persistIndex(): Promise<void> {
    await this.files.ensureDirectory(this.rootPath);
    const data: BackgroundIndexData = {
      backgrounds: await this.listRecords(),
    };
    await this.files.writeText(`${this.rootPath}/index.json`, JSON.stringify(data), true);
  }

  /**
   * 把背景记录转换为资源导入参数列表。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  private toAssetParams(params: BackgroundImportParams): AssetCreateParams {
    return {
      id: params.id,
      type: 'background',
      fileName: params.fileName,
      mimeType: params.mimeType,
      content: params.content,
      metadataJson: params.metadataJson,
    };
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private copyRecord(record: BackgroundRecord): BackgroundRecord {
    return {
      schemaVersion: record.schemaVersion,
      id: record.id,
      fileName: record.fileName,
      path: record.path,
      content: record.content,
      mimeType: record.mimeType,
      metadataJson: record.metadataJson,
      isAnimated: record.isAnimated,
      folderIds: this.copyStrings(record.folderIds),
      thumbnailPath: record.thumbnailPath,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  /**
   * 复制Strings 列表，避免外部修改内部状态。
   * @param values 待处理的值列表。
   * @returns 背景图列表副本
   */
  private copyStrings(values: Array<string>): Array<string> {
    const result = new Array<string>();
    for (let index = 0; index < values.length; index += 1) {
      result.push(values[index]);
    }
    return result;
  }
}
