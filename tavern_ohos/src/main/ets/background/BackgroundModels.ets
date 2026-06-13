import type { ThumbnailDimensions } from '../thumbnail/ThumbnailModels';

export interface BackgroundImportParams {
  id: string;
  fileName: string;
  content: string;
  mimeType: string;
  metadataJson: string;
  isAnimated: boolean;
  folderIds: Array<string>;
  thumbnailContent: string;
}

export interface BackgroundRecord {
  schemaVersion: number;
  id: string;
  fileName: string;
  path: string;
  content: string;
  mimeType: string;
  metadataJson: string;
  isAnimated: boolean;
  folderIds: Array<string>;
  thumbnailPath: string;
  createdAt: number;
  updatedAt: number;
}

export interface BackgroundListItem {
  filename: string;
  isAnimated: boolean;
}

export interface BackgroundFolderRecord {
  id: string;
  name: string;
}

export interface BackgroundListResult {
  images: Array<BackgroundListItem>;
  config: ThumbnailDimensions;
}

export interface BackgroundImportedPayload {
  background: BackgroundRecord;
}

export interface BackgroundRenamedPayload {
  oldFileName: string;
  background: BackgroundRecord;
}

export interface BackgroundDeletedPayload {
  backgroundId: string;
  fileName: string;
}

export interface BackgroundIndexData {
  backgrounds: Array<BackgroundRecord>;
}
