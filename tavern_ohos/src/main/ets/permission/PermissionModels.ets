import type {
  RuntimePermission,
  TavernScope,
} from '../contracts/PublicContracts';

/**
 * 调用权限审计能力时所需的参数集合。
 */
export interface PermissionGrantParams {
  /**
   * 被审计主体的类型（如 "user"、"character"、"plugin"）。
   */
  subjectType: string;
  /**
   * 被审计主体的唯一标识。
   */
  subjectId: string;
  /**
   * 需要授权的运行时权限标识。
   */
  permission: RuntimePermission;
  /**
   * 授权作用域描述。
   */
  scope: TavernScope;
  /**
   * 授权的过期时间戳（毫秒）；0 表示永不过期。
   */
  expiresAt: number;
}

/**
 * 持久化或内存索引中的一条授权记录，记录完整的授权上下文。
 */
export interface PermissionGrantRecord {
  /**
   * 被审计主体的类型。
   */
  subjectType: string;
  /**
   * 被审计主体的唯一标识。
   */
  subjectId: string;
  /**
   * 已授权的运行时权限标识。
   */
  permission: RuntimePermission;
  /**
   * 授权作用域描述。
   */
  scope: TavernScope;
  /**
   * 授权的过期时间戳（毫秒）；0 表示永不过期。
   */
  expiresAt: number;
  /**
   * 授权创建时的时间戳（毫秒）。
   */
  grantedAt: number;
}

/**
 * 权限审计操作完成后返回给调用方的结果。
 */
export interface PermissionCheckResult {
  /**
   * 是否允许通过。
   */
  allowed: boolean;
  /**
   * 审计结果的原因说明。
   */
  reason: string;
  /**
   * 被审计主体的类型。
   */
  subjectType: string;
  /**
   * 被审计主体的唯一标识。
   */
  subjectId: string;
  /**
   * 被审计的运行时权限标识。
   */
  permission: RuntimePermission;
  /**
   * 被审计的资源路径或描述。
   */
  resource: string;
}

/**
 * 发送给外部服务或宿主网络层的授权请求数据。
 */
export interface PermissionConsentRequest {
  /**
   * 请求的唯一标识。
   */
  id: string;
  /**
   * 发起请求的主体类型。
   */
  subjectType: string;
  /**
   * 发起请求的主体标识。
   */
  subjectId: string;
  /**
   * 需要用户确认的运行时权限标识。
   */
  permission: RuntimePermission;
  /**
   * 发起请求的原因说明。
   */
  reason: string;
  /**
   * 请求是否已被处理。
   */
  resolved: boolean;
  /**
   * 请求是否已被批准。
   */
  approved: boolean;
  /**
   * 请求创建时的时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 请求最近一次更新的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 权限审计日志中的一条记录，用于追溯权限检查历史。
 */
export interface PermissionAuditRecord {
  /**
   * 审计记录的唯一标识。
   */
  id: string;
  /**
   * 审计操作类型（如 "grant"、"check"、"revoke"）。
   */
  action: string;
  /**
   * 被审计主体的类型。
   */
  subjectType: string;
  /**
   * 被审计主体的唯一标识。
   */
  subjectId: string;
  /**
   * 涉及的运行时权限标识。
   */
  permission: RuntimePermission;
  /**
   * 审计涉及的资源路径或描述。
   */
  resource: string;
  /**
   * 审计结果是否允许通过。
   */
  allowed: boolean;
  /**
   * 审计结果的原因说明。
   */
  reason: string;
  /**
   * 审计记录创建时的时间戳（毫秒）。
   */
  createdAt: number;
}

/**
 * 权限策略记录，用于持久化和追溯运行时策略配置。
 */
export interface PermissionPolicyRecord {
  /**
   * 策略作用的主体类型。
   */
  subjectType: string;
  /**
   * 策略作用的主体标识。
   */
  subjectId: string;
  /**
   * 策略类型（如 "fileRoot"、"executionTimeout"、"crashCount"）。
   */
  policyType: string;
  /**
   * 策略的字段值。
   */
  value: string;
  /**
   * 策略创建时的时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 策略最近一次更新的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 权限授权事件发布时携带的数据结构。
 */
export interface PermissionGrantedPayload {
  /**
   * 授权记录。
   */
  grant: PermissionGrantRecord;
}

/**
 * 权限检查事件发布时携带的数据结构。
 */
export interface PermissionCheckedPayload {
  /**
   * 检查结果。
   */
  result: PermissionCheckResult;
}

/**
 * 权限请求事件发布时携带的数据结构。
 */
export interface PermissionConsentPayload {
  /**
   * 授权请求。
   */
  request: PermissionConsentRequest;
}
