/**
 * 描述调用权限审计能力时需要传入的参数。
 */
export interface PermissionGrantParams {
  /**
   * subject Type 值，由当前实例内部维护。
   */
  subjectType: string;
  /**
   * subject 标识。
   */
  subjectId: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: string;
  /**
   * 作用域。
   */
  scope: string;
  /**
   * expires At 值，由当前实例内部维护。
   */
  expiresAt: number;
}

/**
 * 描述权限审计持久化或内存索引中的一条记录。
 */
export interface PermissionGrantRecord {
  /**
   * subject Type 值，由当前实例内部维护。
   */
  subjectType: string;
  /**
   * subject 标识。
   */
  subjectId: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: string;
  /**
   * 作用域。
   */
  scope: string;
  /**
   * expires At 值，由当前实例内部维护。
   */
  expiresAt: number;
  /**
   * granted At 值，由当前实例内部维护。
   */
  grantedAt: number;
}

/**
 * 描述权限审计操作完成后返回给调用方的结果。
 */
export interface PermissionCheckResult {
  /**
   * allowed 值，由当前实例内部维护。
   */
  allowed: boolean;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
  /**
   * subject Type 值，由当前实例内部维护。
   */
  subjectType: string;
  /**
   * subject 标识。
   */
  subjectId: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: string;
  /**
   * resource 值，由当前实例内部维护。
   */
  resource: string;
}

/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface PermissionConsentRequest {
  /**
   * 标识。
   */
  id: string;
  /**
   * subject Type 值，由当前实例内部维护。
   */
  subjectType: string;
  /**
   * subject 标识。
   */
  subjectId: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: string;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
  /**
   * resolved 值，由当前实例内部维护。
   */
  resolved: boolean;
  /**
   * approved 值，由当前实例内部维护。
   */
  approved: boolean;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述权限审计持久化或内存索引中的一条记录。
 */
export interface PermissionAuditRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * action 值，由当前实例内部维护。
   */
  action: string;
  /**
   * subject Type 值，由当前实例内部维护。
   */
  subjectType: string;
  /**
   * subject 标识。
   */
  subjectId: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: string;
  /**
   * resource 值，由当前实例内部维护。
   */
  resource: string;
  /**
   * allowed 值，由当前实例内部维护。
   */
  allowed: boolean;
  /**
   * 原因说明，由当前实例内部维护。
   */
  reason: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
}

/**
 * 描述权限审计持久化或内存索引中的一条记录。
 */
export interface PermissionPolicyRecord {
  /**
   * subject Type 值，由当前实例内部维护。
   */
  subjectType: string;
  /**
   * subject 标识。
   */
  subjectId: string;
  /**
   * policy Type 值，由当前实例内部维护。
   */
  policyType: string;
  /**
   * 字段值。
   */
  value: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述权限审计事件发布时携带的数据结构。
 */
export interface PermissionGrantedPayload {
  /**
   * grant 值，由当前实例内部维护。
   */
  grant: PermissionGrantRecord;
}

/**
 * 描述权限审计事件发布时携带的数据结构。
 */
export interface PermissionCheckedPayload {
  /**
   * 处理结果。
   */
  result: PermissionCheckResult;
}

/**
 * 描述权限审计事件发布时携带的数据结构。
 */
export interface PermissionConsentPayload {
  /**
   * request 值，由当前实例内部维护。
   */
  request: PermissionConsentRequest;
}
