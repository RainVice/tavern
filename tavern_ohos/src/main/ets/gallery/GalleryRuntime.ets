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
   * 构造运行时实例，绑定外部传入的事件总线。
   * @param events 事件总线实例，用于发布图库相关事件。
   */
  constructor(events: EventBus) { this.events=events; }
  /**
   * 添加一张图片到图库，完成持久化后返回新创建的图片对象。
   * @param characterId 所属角色标识。
   * @param fileName 图片文件名。
   * @param mimeType 图片 MIME 类型，如 "image/png"。
   * @param path 图片文件在本地存储中的绝对路径。
   * @returns 新创建的图片对象副本。
   */
  addImage(characterId: string, fileName: string, mimeType: string, path: string): GalleryImage {
    this.counter+=1; const imageId=`gallery-${this.counter}`; const now=Date.now();
    const image: GalleryImage = { imageId, characterId, fileName, mimeType, path, caption:'', tags:new Array<string>(), createdAt:now };
    this.images.set(imageId, this.copyImage(image));
    this.events.publish<GalleryImageAddedPayload>('gallery.image.added', { image: this.copyImage(image) });
    return this.copyImage(image);
  }
  /**
   * 从图库中移除指定图片，并发布移除事件。
   * @param imageId 待移除的图片标识。
   */
  removeImage(imageId: string): void {
    const image=this.images.get(imageId);
    if (image===undefined) throw new Error(`图库图片未找到: ${imageId}`);
    this.images.delete(imageId);
    this.events.publish<GalleryImageRemovedPayload>('gallery.image.removed', { imageId });
  }
  /**
   * 根据标识查询指定图片，不存在时抛出错误。
   * @param imageId 待查询的图片标识。
   * @returns 图片数据的副本。
   */
  getImage(imageId: string): GalleryImage {
    return this.copyImage(this.requireImage(imageId));
  }
  /**
   * 查询指定角色的全部图片，未指定角色时返回所有图片。
   * @param characterId 可选，角色标识，传入后只返回该角色的图片。
   * @returns 符合条件的图片列表；返回副本，调用方修改不影响内部状态。
   */
  listImages(characterId?: string): Array<GalleryImage> {
    const result=new Array<GalleryImage>(); const values=Array.from(this.images.values());
    for (let i=0;i<values.length;i++) { if (characterId===undefined||values[i].characterId===characterId) result.push(this.copyImage(values[i])); }
    return result;
  }
  /**
   * 重新设置指定图片的描述文字。
   * @param imageId 图片标识。
   * @param caption 新的描述文字。
   */
  setCaption(imageId: string, caption: string): void { this.requireImage(imageId).caption=caption; }
  /**
   * 导出当前图库全部数据，用于备份或与外部系统互通。
   * @returns 包含全部图片的可序列化导出对象。
   */
  exportData(): GalleryExportData { return { images: this.listImages() }; }
  /**
   * 从外部数据中导入图库数据，用于从备份恢复。
   * @param data 待导入的序列化图库数据。
   */
  importData(data: GalleryExportData): void {
    for (let i=0;i<data.images.length;i++) {
      const image = this.copyImage(data.images[i]);
      this.images.set(image.imageId, image);
      this.counter = Math.max(this.counter, this.parseCounter(image.imageId));
    }
  }

  /**
   * 根据标识获取图片对象，不存在时抛出错误。
   * @param imageId 图片标识。
   * @returns 匹配的图片对象。
   */
  private requireImage(imageId: string): GalleryImage {
    const image=this.images.get(imageId); if (image===undefined) throw new Error(`图库图片未找到: ${imageId}`); return image;
  }

  /**
   * 深拷贝图片对象，防止外部修改影响内部状态。
   * @returns 拷贝后的新图片对象。
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
   * 从图片标识中解析出自增计数器数值，用于重启后恢复计数器状态。
   * @param imageId 图片标识，格式如 "gallery-1"。
   * @returns 解析后的数值；格式不匹配时返回 0。
   */
  private parseCounter(imageId: string): number {
    if (!imageId.startsWith('gallery-')) {
      return 0;
    }
    const parsed = Number(imageId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
