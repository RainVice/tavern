export interface AssetCreateParams {
  id: string;
  type: string;
  fileName: string;
  mimeType: string;
  content: string;
  metadataJson: string;
}

export interface AssetRecord {
  schemaVersion: number;
  id: string;
  type: string;
  fileName: string;
  mimeType: string;
  path: string;
  content: string;
  metadataJson: string;
  createdAt: number;
  updatedAt: number;
}

export interface AssetImportedPayload {
  asset: AssetRecord;
}

export interface AssetRenamedPayload {
  assetId: string;
  oldPath: string;
  asset: AssetRecord;
}

export interface AssetDeletedPayload {
  assetId: string;
  type: string;
  path: string;
}

export interface AssetIndexData {
  assets: Array<AssetRecord>;
}
