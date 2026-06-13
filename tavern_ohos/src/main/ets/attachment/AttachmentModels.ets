export interface AttachmentCreateParams {
  id: string;
  kind: string;
  fileName: string;
  mimeType: string;
  storagePath: string;
  content: string;
  includeInPrompt: boolean;
  includeInRag: boolean;
  captionText: string;
  translationText: string;
  metadataJson: string;
}

export interface AttachmentRecord {
  schemaVersion: number;
  id: string;
  kind: string;
  fileName: string;
  mimeType: string;
  storagePath: string;
  content: string;
  includeInPrompt: boolean;
  includeInRag: boolean;
  captionText: string;
  translationText: string;
  metadataJson: string;
  deleted: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface AttachmentBindingRecord {
  attachmentId: string;
  targetType: string;
  targetId: string;
  createdAt: number;
}

export interface AttachmentPromptRecord {
  attachmentId: string;
  kind: string;
  fileName: string;
  mimeType: string;
  content: string;
}

export interface AttachmentExportData {
  attachment: AttachmentRecord;
  bindings: Array<AttachmentBindingRecord>;
}

export interface AttachmentAddedPayload {
  attachmentId: string;
  targetType: string;
  targetId: string;
  attachment: AttachmentRecord;
}

export interface AttachmentDeletedPayload {
  attachmentId: string;
}

export interface AttachmentUpdatedPayload {
  attachment: AttachmentRecord;
}
