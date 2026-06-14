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
 * 在聊天界面设置、主题配置和背景图库管理流程中被调用，用于背景图的导入、列表、激活、重命名和删除。
 */
export class BackgroundRuntime {
  /**
   * 文件存储适配器，用于读写背景图数据和索引文件。
   */
  private files: TavernFileStore;
  /**
   * 事件总线，用于发布背景图导入、重命名、删除等状态变更事件。
   */
  private events: EventBus;
  /**
   * 资源运行时，用于管理背景图对应资源的导入、重命名和删除。
   */
  private assets: AssetRuntime;
  /**
   * 缩略图运行时，用于为背景图生成和管理缩略图。
   */
  private thumbnails: ThumbnailRuntime;
  /**
   * 主题运行时，用于激活背景图时同步更新聊天界面的主题背景。
   */
  private themes: ThemeRuntime;
  /**
   * 背景记录内存索引，以背景标识为键，用于快速查找和更新背景记录。
   */
  private records: Map<string, BackgroundRecord> = new Map<string, BackgroundRecord>();
  /**
   * 背景图数据根路径，用于构建索引文件和资源文件的存储目录。
   */
  private rootPath: string = 'tavern-data/users/default/assets/backgrounds';

  /**
   * 注入背景图运行时依赖并初始化实例状态，由宿主在应用启动时通过依赖注入创建。
   * @param files 文件存储适配器，用于读写背景图数据和索引文件。
   * @param events 事件总线，用于发布背景图状态变更事件。
   * @param assets 资源运行时，用于管理背景图对应的 Asset 资源。
   * @param thumbnails 缩略图运行时，用于为背景图生成缩略图。
   * @param themes 主题运行时，用于在激活背景图时更新主题状态。
   */
  constructor(files: TavernFileStore, events: EventBus, assets: AssetRuntime, thumbnails: ThumbnailRuntime, themes: ThemeRuntime) {
    this.files = files;
    this.events = events;
    this.assets = assets;
    this.thumbnails = thumbnails;
    this.themes = themes;
  }

  /**
   * 从外部数据导入背景图：创建 Asset、生成缩略图、写入内存索引并持久化，发布导入事件。
   * 在背景图管理页面中，用户从文件选择器导入背景图时触发。
   * @param params 背景导入参数，包含标识、文件名、内容、MIME 类型、动画标记、文件夹信息和缩略图数据。
   * @returns 导入完成后的完整背景记录，包含文件路径、缩略图路径和时间戳。
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
   * 获取所有背景图的摘要列表及缩略图配置，用于 UI 渲染背景图选择面板。
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
   * 从所有背景记录中提取所有文件夹标识，去重排序后返回列表，用于 UI 渲染文件夹筛选器。
   * @returns 去重并排序后的文件夹记录列表，每条记录以标识同时作为名称。
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
   * 激活指定文件名的背景图：校验记录存在性后通知主题运行时更新激活的背景图。
   * 在聊天界面设置中，用户选择背景图作为聊天背景时触发。
   * @param fileName 要激活的背景图文件名，用于查找对应的背景记录。
   */
  async activateBackground(fileName: string): Promise<void> {
    this.requireRecordByFileName(fileName);
    await this.themes.setActiveBackground(fileName);
  }

  /**
   * 重命名背景图：同步重命名关联的 Asset 和缩略图，更新内存索引并持久化，发布重命名事件。
   * 在背景图管理页面中，用户修改背景图文件名时触发。
   * @param backgroundId 要重命名的背景图标识，用于查找对应的背景记录。
   * @param newFileName 新的文件名，用于更新存储路径和索引。
   * @returns 重命名后的完整背景记录，包含更新后的文件名和路径。
   */
  async renameBackground(backgroundId: string, newFileName: string): Promise<BackgroundRecord> {
    const record = this.requireRecord(backgroundId);
    // 记录旧文件名，用于失效旧的缩略图和构造重命名事件载荷。
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
   * 删除指定背景图：从内存索引移除、删除关联 Asset、失效缩略图、清理主题引用，最后持久化并发布删除事件。
   * 在背景图管理页面中，用户确认删除背景图时触发。
   * @param backgroundId 要删除的背景图标识，用于查找对应的背景记录和关联资源。
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
   * 根据标识查找背景记录，不存在时抛出异常，供内部方法在需要确保记录存在时使用。
   * @param backgroundId 要查找的背景图标识，用于在内存索引中定位记录。
   */
  private requireRecord(backgroundId: string): BackgroundRecord {
    const record = this.records.get(backgroundId);
    if (record === undefined) {
      throw new Error(`Background not found: ${backgroundId}`);
    }
    return record;
  }

  /**
   * 根据文件名遍历查找背景记录，不存在时抛出异常，供 activateBackground 确保激活前记录存在。
   * @param fileName 要查找的背景图文件名，用于在内存索引中遍历匹配。
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
   * 获取所有背景记录的副本列表，按文件名排序，供内部持久化和列表展示使用。
   * @returns 所有背景记录的副本，按文件名升序排列，调用方可安全修改返回值而不影响内部状态。
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
   * 将背景导入参数转换为资源创建参数，用于委托 AssetRuntime 处理背景图资源的文件管理。
   * @param params 背景导入参数，包含标识、类型、文件名、MIME 类型、内容和元数据。
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
   * 深度复制背景记录，防止外部代码意外修改内部状态，用于所有对外暴露背景记录的场景。
   * @param record 要复制的原背景记录，原对象不会被修改。
   * @returns 与原记录值相等的新记录对象，调用方可安全修改。
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
   * 浅复制字符串数组，防止外部代码修改内部数组内容，用于复制 folderIds 等字符串列表字段。
   * @param values 要复制的源字符串数组，原数组不会被修改。
   * @returns 元素相同的新数组，调用方可安全修改。
   */
  private copyStrings(values: Array<string>): Array<string> {
    const result = new Array<string>();
    for (let index = 0; index < values.length; index += 1) {
      result.push(values[index]);
    }
    return result;
  }
}
