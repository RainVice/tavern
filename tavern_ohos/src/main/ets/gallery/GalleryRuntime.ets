import { EventBus } from '../runtime/EventBus';
import type { GalleryExportData, GalleryImage, GalleryImageAddedPayload, GalleryImageRemovedPayload } from './GalleryModels';

/**
 * 提供角色图库相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class GalleryRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private images: Map<string,GalleryImage>=new Map(); private counter=0;
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }
  /**
   * 创建或写入图片，完成持久化后返回可供调用方使用的结果。
   * @param characterId 目标角色标识。
   * @param fileName 文件名称。

   * @param path 目标文件或目录路径。
   */
  addImage(characterId: string, fileName: string, mimeType: string, path: string): GalleryImage {
    this.counter+=1; const imageId=`gallery-${this.counter}`; const now=Date.now();
    const image: GalleryImage = { imageId, characterId, fileName, mimeType, path, caption:'', tags:new Array<string>(), createdAt:now };
    this.images.set(imageId, this.copyImage(image));
    this.events.publish<GalleryImageAddedPayload>('gallery.image.added', { image: this.copyImage(image) });
    return this.copyImage(image);
  }
  /**
   * 移除图片，用于解除注册、绑定或索引关系。
   * @param imageId 目标图片标识。
   */
  removeImage(imageId: string): void {
    const image=this.images.get(imageId);
    if (image===undefined) throw new Error(`图库图片未找到: ${imageId}`);
    this.images.delete(imageId);
    this.events.publish<GalleryImageRemovedPayload>('gallery.image.removed', { imageId });
  }
  /**
   * 读取指定图片，不存在时抛出错误。
   * @param imageId 目标图片标识。
   * @returns 更新或读取后的记录副本。
   */
  getImage(imageId: string): GalleryImage {
    return this.copyImage(this.requireImage(imageId));
  }
  /**
   * 读取Images列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param characterId 目标角色标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listImages(characterId?: string): Array<GalleryImage> {
    const result=new Array<GalleryImage>(); const values=Array.from(this.images.values());
    for (let i=0;i<values.length;i++) { if (characterId===undefined||values[i].characterId===characterId) result.push(this.copyImage(values[i])); }
    return result;
  }
  /**
   * 设置图片描述，用于切换运行时状态或保存配置。
   * @param imageId 目标图片标识。

   */
  setCaption(imageId: string, caption: string): void { this.requireImage(imageId).caption=caption; }
  /**
   * 导出数据，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 可持久化或可传输的导出内容。
   */
  exportData(): GalleryExportData { return { images: this.listImages() }; }
  /**
   * 从外部数据导入Data 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  importData(data: GalleryExportData): void {
    for (let i=0;i<data.images.length;i++) {
      const image = this.copyImage(data.images[i]);
      this.images.set(image.imageId, image);
      this.counter = Math.max(this.counter, this.parseCounter(image.imageId));
    }
  }

  /**
   * 读取必须存在的Image 值，缺失时抛出错误。
   * @param imageId 目标图片标识。
   */
  private requireImage(imageId: string): GalleryImage {
    const image=this.images.get(imageId); if (image===undefined) throw new Error(`图库图片未找到: ${imageId}`); return image;
  }

  /**
   * 复制Image 值，避免外部修改内部状态。
   */
  private copyImage(image: GalleryImage): GalleryImage {
    return {
      imageId: image.imageId,
      characterId: image.characterId,
      fileName: image.fileName,
      mimeType: image.mimeType,
      path: image.path,
      caption: image.caption,
      tags: image.tags.slice(),
      createdAt: image.createdAt,
    };
  }

  /**
   * 解析Counter，非法输入会返回失败标记或空结果。
   * @param imageId 目标图片标识。
   */
  private parseCounter(imageId: string): number {
    if (!imageId.startsWith('gallery-')) {
      return 0;
    }
    const parsed = Number(imageId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
