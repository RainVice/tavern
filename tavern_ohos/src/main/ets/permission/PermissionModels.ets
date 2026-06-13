export interface PermissionGrantParams {
  subjectType: string;
  subjectId: string;
  permission: string;
  scope: string;
  expiresAt: number;
}

export interface PermissionGrantRecord {
  subjectType: string;
  subjectId: string;
  permission: string;
  scope: string;
  expiresAt: number;
  grantedAt: number;
}

export interface PermissionCheckResult {
  allowed: boolean;
  reason: string;
  subjectType: string;
  subjectId: string;
  permission: string;
  resource: string;
}

export interface PermissionConsentRequest {
  id: string;
  subjectType: string;
  subjectId: string;
  permission: string;
  reason: string;
  resolved: boolean;
  approved: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface PermissionAuditRecord {
  id: string;
  action: string;
  subjectType: string;
  subjectId: string;
  permission: string;
  resource: string;
  allowed: boolean;
  reason: string;
  createdAt: number;
}

export interface PermissionPolicyRecord {
  subjectType: string;
  subjectId: string;
  policyType: string;
  value: string;
  createdAt: number;
  updatedAt: number;
}

export interface PermissionGrantedPayload {
  grant: PermissionGrantRecord;
}

export interface PermissionCheckedPayload {
  result: PermissionCheckResult;
}

export interface PermissionConsentPayload {
  request: PermissionConsentRequest;
}
