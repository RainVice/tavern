export type ImageFormat = 'png' | 'webp' | 'jpeg' | 'unknown';
export interface ImageMetadataChunk { type: string; size: number; }
export interface ImageMetadata {
  format: ImageFormat; width: number; height: number;
  hasCharacterCard: boolean; rawChunks: Array<ImageMetadataChunk>;
}
export interface MetadataExtractResult {
  metadata: ImageMetadata; characterCardJson: string;
}
export interface MetadataWriteParams {
  format: ImageFormat; characterCardJson: string; outputPath: string; sourceData?: ArrayBuffer;
}
export interface MetadataExtractedPayload { result: MetadataExtractResult; }
