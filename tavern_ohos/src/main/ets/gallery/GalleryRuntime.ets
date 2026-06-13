import { EventBus } from '../runtime/EventBus';
import type { GalleryExportData, GalleryImage, GalleryImageAddedPayload, GalleryImageRemovedPayload } from './GalleryModels';

export class GalleryRuntime {
  private events: EventBus; private images: Map<string,GalleryImage>=new Map(); private counter=0;
  constructor(events: EventBus) { this.events=events; }
  addImage(characterId: string, fileName: string, mimeType: string, path: string): GalleryImage {
    this.counter+=1; const imageId=`gallery-${this.counter}`; const now=Date.now();
    const image: GalleryImage = { imageId, characterId, fileName, mimeType, path, caption:'', tags:new Array<string>(), createdAt:now };
    this.images.set(imageId, this.copyImage(image));
    this.events.publish<GalleryImageAddedPayload>('gallery.image.added', { image: this.copyImage(image) });
    return this.copyImage(image);
  }
  removeImage(imageId: string): void {
    const image=this.images.get(imageId);
    if (image===undefined) throw new Error(`图库图片未找到: ${imageId}`);
    this.images.delete(imageId);
    this.events.publish<GalleryImageRemovedPayload>('gallery.image.removed', { imageId });
  }
  getImage(imageId: string): GalleryImage {
    return this.copyImage(this.requireImage(imageId));
  }
  listImages(characterId?: string): Array<GalleryImage> {
    const result=new Array<GalleryImage>(); const values=Array.from(this.images.values());
    for (let i=0;i<values.length;i++) { if (characterId===undefined||values[i].characterId===characterId) result.push(this.copyImage(values[i])); }
    return result;
  }
  setCaption(imageId: string, caption: string): void { this.requireImage(imageId).caption=caption; }
  exportData(): GalleryExportData { return { images: this.listImages() }; }
  importData(data: GalleryExportData): void {
    for (let i=0;i<data.images.length;i++) {
      const image = this.copyImage(data.images[i]);
      this.images.set(image.imageId, image);
      this.counter = Math.max(this.counter, this.parseCounter(image.imageId));
    }
  }

  private requireImage(imageId: string): GalleryImage {
    const image=this.images.get(imageId); if (image===undefined) throw new Error(`图库图片未找到: ${imageId}`); return image;
  }

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

  private parseCounter(imageId: string): number {
    if (!imageId.startsWith('gallery-')) {
      return 0;
    }
    const parsed = Number(imageId.substring(8));
    return parsed > 0 ? parsed : 0;
  }
}
