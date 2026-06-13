export interface DataBankDocumentCreateParams {
  id: string;
  scope: string;
  sourceType: string;
  fileName: string;
  mimeType: string;
  content: string;
  tags: Array<string>;
  metadataJson: string;
  enabled: boolean;
}

export interface DataBankDocumentRecord {
  schemaVersion: number;
  id: string;
  scope: string;
  sourceType: string;
  fileName: string;
  mimeType: string;
  path: string;
  content: string;
  tags: Array<string>;
  metadataJson: string;
  enabled: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface DataBankExportData {
  documents: Array<DataBankDocumentRecord>;
}

export interface DataBankUpdatedPayload {
  documentId: string;
  document: DataBankDocumentRecord;
}

export interface DataBankDeletedPayload {
  documentId: string;
}
