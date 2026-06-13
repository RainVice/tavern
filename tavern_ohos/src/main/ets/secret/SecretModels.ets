export interface SecretCreateParams {
  id: string;
  providerId: string;
  scope: string;
  scopeId: string;
  label: string;
  value: string;
  active: boolean;
}

export interface SecretRecord {
  id: string;
  secretRef: string;
  providerId: string;
  scope: string;
  scopeId: string;
  label: string;
  active: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface SecretValueRecord {
  secretRef: string;
  value: string;
}

export interface SecretStateRecord {
  id: string;
  secretRef: string;
  providerId: string;
  scope: string;
  scopeId: string;
  label: string;
  maskedValue: string;
  active: boolean;
  updatedAt: number;
}

export interface SecretExportRecord {
  id: string;
  secretRef: string;
  providerId: string;
  scope: string;
  scopeId: string;
  label: string;
  maskedValue: string;
  active: boolean;
  updatedAt: number;
}

export interface SecretAccessOptions {
  requesterId: string;
  permissions: Array<string>;
}

export interface SecretEventPayload {
  secret: SecretRecord;
}

export interface SecretDeletedPayload {
  secretRef: string;
  providerId: string;
}

export interface SecretRotatedPayload {
  secret: SecretRecord;
  previousSecretRef: string;
}
