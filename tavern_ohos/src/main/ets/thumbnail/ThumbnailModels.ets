export interface ThumbnailCreateParams {
  type: string;
  fileName: string;
  sourcePath: string;
  content: string;
  width: number;
  height: number;
  animated: boolean;
}

export interface ThumbnailDimensions {
  width: number;
  height: number;
}

export interface ThumbnailRecord {
  schemaVersion: number;
  type: string;
  fileName: string;
  sourcePath: string;
  path: string;
  content: string;
  width: number;
  height: number;
  aspectRatio: number;
  resolution: number;
  animated: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface ThumbnailGeneratedPayload {
  thumbnail: ThumbnailRecord;
}

export interface ThumbnailInvalidatedPayload {
  type: string;
  fileName: string;
  path: string;
}

export interface ThumbnailIndexData {
  thumbnails: Array<ThumbnailRecord>;
}
