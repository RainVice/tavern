import { EventBus } from '../runtime/EventBus';
import type { GalleryExportData, GalleryImage, GalleryImageAddedPayload, GalleryImageRemovedPayload } from './GalleryModels';

/**
 * 提供角色图库相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 角色图库用于存储和管理与角色关联的图片（如头像、外观参考图等），
 * UI 图库面板可据此展示角色图片列表，支持按角色筛选、添加/移除图片和设置描述。
 */
export class GalleryRuntime {
  /**
   * 事件总线，用于在添加/移除图库图片时向 UI 面板和其他模块广播变更事件。
   */
  private events: EventBus; private images: Map<string,GalleryImage>=new Map(); private counter=0;

  /**
   * 初始化运行时实例，注入事件总线依赖。
   * @param events 事件总线实例，用于在 addImage/removeImage 时发布 'gallery.image.added' / 'gallery.image.removed' 事件。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 向图库中添加一张图片，生成唯一标识并发布图片添加事件。
   * 在用户将图片添加到角色图库时由宿主或 UI 层调用。
   * @param characterId 图片所属角色标识，用于在图库中按角色过滤和分组显示图片。
   * @param fileName 图片文件名，用于在存储中生成路径以及 UI 展示文件名信息。
   * @param mimeType 图片 MIME 类型（如 'image/png'），用于区分图片格式。
   * @param path 图片在存储中的路径，用于后续读取和展示图片内容。
   */
  addImage(characterId: string, fileName: string, mimeType: string, path: string): GalleryImage {
    this.counter+=1; const imageId=`gallery-${this.counter}`; const now=Date.now();
    const image: GalleryImage = { imageId, characterId, fileName, mimeType, path, caption:'', tags:new Array<string>(), createdAt:now };
    this.images.set(imageId, this.copyImage(image));
    this.events.publish<GalleryImageAddedPayload>('gallery.image.added', { image: this.copyImage(image) });
    return this.copyImage(image);
  }

  /**
   * 从图库中移除指定图片，解除索引并发布图片移除事件。
   * 在用户从图库中删除图片时由宿主或 UI 层调用。
   * @param imageId 要移除的图片标识，用于在 images 索引中查找和删除对应记录。
   * @throws 当指定 imageId 不存在时抛出错误。
   */
  removeImage(imageId: string): void {
    const image=this.images.get(imageId);
    if (image===undefined) throw new Error(`图库图片未找到: ${imageId}`);
    this.images.delete(imageId);
    this.events.publish<GalleryImageRemovedPayload>('gallery.image.removed', { imageId });
  }

  /**
   * 根据标识获取图片数据副本，图片不存在时抛出错误。
   * 在 UI 需要展示特定图片详情时由宿主调用。
   * @param imageId 要获取的图片标识，用于在 images 索引中查找对应的记录。
   * @returns 该图片的数据副本。
   * @throws 当指定 imageId 不存在时抛出错误。
   */
  getImage(imageId: string): GalleryImage {
    return this.copyImage(this.requireImage(imageId));
  }

  /**
   * 列出图库中的图片，可按角色筛选，不传角色则返回全部图片。
   * 在 UI 图库面板渲染图片列表时由宿主调用。
   * @param characterId 可选的角色标识，传入时仅返回该角色关联的图片，
   *                    用于在角色详情页或图库筛选视图中展示特定角色的图库内容。
   * @returns 符合条件的图片数据副本列表，每个条目修改不影响内部状态。
   */
  listImages(characterId?: string): Array<GalleryImage> {
    const result=new Array<GalleryImage>(); const values=Array.from(this.images.values());
    for (let i=0;i<values.length;i++) { if (characterId===undefined||values[i].characterId===characterId) result.push(this.copyImage(values[i])); }
    return result;
  }

  /**
   * 设置图片的描述文字。
   * 在用户为图库图片添加或编辑描述时由 UI 层调用。
   * @param imageId 要设置描述的图片标识，用于在 images 索引中查找对应的记录。
   * @param caption 图片描述文字，会直接更新到对应记录的 caption 字段。
   */
  setCaption(imageId: string, caption: string): void { this.requireImage(imageId).caption=caption; }

  /**
   * 导出所有图库图片数据，用于备份、迁移或与 SillyTavern 数据互通。
   * 通常在设置页面执行导出操作时由宿主调用。
   * @returns 包含全部图片列表的可序列化导出对象。
   */
  exportData(): GalleryExportData { return { images: this.listImages() }; }

  /**
   * 从外部数据导入图库图片，恢复到运行时状态中。
   * 通常在设置页面对导入数据进行恢复时由宿主调用。
   * @param data 待导入的图库导出数据，通常来自备份或迁移文件，
   *             其 images 数组会被逐一合并到运行时的 images 索引中。
   */
  importData(data: GalleryExportData): void {
    for (let i=0;i<data.images.length;i++) {
      const image = this.copyImage(data.images[i]);
      this.images.set(image.imageId, image);
      this.counter = Math.max(this.counter, this.parseCounter(image.imageId));
    }
  }

  /**
   * 按标识查找图片，不存在时抛出错误。
   * @param imageId 要查找的图片标识。
   */
  private requireImage(imageId: string): GalleryImage {
    const image=this.images.get(imageId); if (image===undefined) throw new Error(`图库图片未找到: ${imageId}`); return image;
  }

  /**
   * 深拷贝图片数据，防止外部代码修改内部状态。
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
   * 从图片标识中解析出自增计数器值，用于导入时保持计数器不冲突。
   * @param imageId 图片标识，格式为 'gallery-{数字}'。
   */
  private parseCounter(imageId: string): number {
    if (!imageId.startsWith('gallery-')) {
      return 0;
    }
    const parsed = Number(imageId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
