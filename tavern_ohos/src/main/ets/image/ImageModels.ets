export interface ImageUploadParams {
  id: string;
  fileName: string;
  format: string;
  folderName: string;
  mimeType: string;
  content: string;
  thumbnailType: string;
  thumbnailContent: string;
  thumbnailWidth: number;
  thumbnailHeight: number;
  attachmentId: string;
  attachmentTargetType: string;
  attachmentTargetId: string;
  includeInPrompt: boolean;
  includeInRag: boolean;
}

export interface ImageRecord {
  schemaVersion: number;
  id: string;
  fileName: string;
  format: string;
  folderName: string;
  mimeType: string;
  path: string;
  content: string;
  thumbnailType: string;
  thumbnailPath: string;
  attachmentId: string;
  createdAt: number;
  updatedAt: number;
}

export interface ImageUploadedPayload {
  image: ImageRecord;
}

export interface ImageDeletedPayload {
  imageId: string;
  path: string;
}

export interface ImageIndexData {
  images: Array<ImageRecord>;
}
