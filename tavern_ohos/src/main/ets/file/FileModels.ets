export interface FileUploadParams {
  id: string;
  fileName: string;
  mimeType: string;
  content: string;
  attachmentId: string;
  attachmentTargetType: string;
  attachmentTargetId: string;
  includeInPrompt: boolean;
  includeInRag: boolean;
  dataBankDocumentId: string;
  dataBankScope: string;
  dataBankTags: Array<string>;
  metadataJson: string;
}

export interface FileRecord {
  schemaVersion: number;
  id: string;
  fileName: string;
  mimeType: string;
  path: string;
  content: string;
  attachmentId: string;
  dataBankDocumentId: string;
  metadataJson: string;
  createdAt: number;
  updatedAt: number;
}

export interface FileVerifyResult {
  path: string;
  exists: boolean;
}

export interface FileUploadedPayload {
  file: FileRecord;
}

export interface FileDeletedPayload {
  fileId: string;
  path: string;
}

export interface FileIndexData {
  files: Array<FileRecord>;
}
