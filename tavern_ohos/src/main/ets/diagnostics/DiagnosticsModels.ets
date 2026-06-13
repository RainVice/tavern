export interface DiagnosticRecord {
  id: string;
  kind: string;
  subjectId: string;
  label: string;
  status: string;
  message: string;
  createdAt: number;
}

export interface DiagnosticBundle {
  id: string;
  name: string;
  path: string;
  records: Array<DiagnosticRecord>;
  createdAt: number;
}

export interface DiagnosticHealthSummary {
  totalRecords: number;
  errorCount: number;
  warningCount: number;
  status: string;
}

export interface DiagnosticsRecordCreatedPayload {
  record: DiagnosticRecord;
}

export interface DiagnosticsBundleCreatedPayload {
  bundle: DiagnosticBundle;
}
