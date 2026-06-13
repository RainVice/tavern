export interface GalleryImage {
  imageId: string; characterId: string; fileName: string; mimeType: string;
  path: string; caption: string; tags: Array<string>; createdAt: number;
}
export interface GalleryImageAddedPayload { image: GalleryImage; }
export interface GalleryImageRemovedPayload { imageId: string; }
export interface GalleryExportData { images: Array<GalleryImage>; }
