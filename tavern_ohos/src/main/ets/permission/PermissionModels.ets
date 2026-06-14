/**
 * 调用权限授予接口时所需的参数。
 * 用于 PermissionRuntime.grant 方法，指定要授予的主体、权限、作用域和过期时间。
 */
export interface PermissionGrantParams {
  /**
   * 请求权限的主体类型（如 plugin、persona），用于在授权记录和审计日志中区分主体种类。
   */
  subjectType: string;
  /**
   * 请求权限的主体标识，用于在授权记录中定位具体主体。
   */
  subjectId: string;
  /**
   * 权限名称（如 file:access、network:private），标识授权的具体操作类型。
   */
  permission: string;
  /**
   * 权限的作用域标识，用于限定权限适用的资源范围（如特定文件路径或 API 端点）。
   */
  scope: string;
  /**
   * 权限过期时间戳，0 表示永不过期，用于实现时效性授权。
   */
  expiresAt: number;
}

/**
 * 权限授予记录，存储已授予的权限及其过期时间。
 * 由 PermissionRuntime.grant 创建，在 check 时用于判断主体是否拥有某权限。
 */
export interface PermissionGrantRecord {
  /**
   * 授予权限的主体类型，用于在授权索引中与 subjectId 组合作为键的一部分。
   */
  subjectType: string;
  /**
   * 授予权限的主体标识，用于定位具体主体的授权记录。
   */
  subjectId: string;
  /**
   * 授予的权限名称，用于在 check 时匹配主体申请的权限。
   */
  permission: string;
  /**
   * 权限的作用域标识，用于在授权记录中记录权限适用的资源范围。
   */
  scope: string;
  /**
   * 权限过期时间戳，0 表示永不过期，check 时用于校验权限是否仍有效。
   */
  expiresAt: number;
  /**
   * 权限授予的时间戳，用于审计和授权记录的时间追溯。
   */
  grantedAt: number;
}

/**
 * 权限检查后返回给调用方的结果。
 * 由 PermissionRuntime.check、checkNetworkAccess、checkFileAccess、checkDangerousApi 等方法返回。
 */
export interface PermissionCheckResult {
  /**
   * 是否允许通过，决定调用方后续操作是否可继续。
   */
  allowed: boolean;
  /**
   * 判决的原因描述（如 "allowed"、"Missing permission: xxx"、"Permission expired: xxx"），用于日志和调试。
   */
  reason: string;
  /**
   * 请求权限的主体类型，回显给调用方用于确认检查的目标主体。
   */
  subjectType: string;
  /**
   * 请求权限的主体标识，回显给调用方用于确认检查的目标主体。
   */
  subjectId: string;
  /**
   * 被检查的权限名称，回显给调用方用于确认检查的权限。
   */
  permission: string;
  /**
   * 被访问的资源标识，回显给调用方用于确认检查的资源。
   */
  resource: string;
}

/**
 * 发送给外部服务或宿主层的权限同意请求。
 * 由 PermissionRuntime.requestConsent 创建，resolveConsent 处理审批结果。
 */
export interface PermissionConsentRequest {
  /**
   * 同意请求的唯一标识，用于在 resolveConsent 时定位目标请求。
   */
  id: string;
  /**
   * 请求权限的主体类型，说明谁在请求权限。
   */
  subjectType: string;
  /**
   * 请求权限的主体标识，说明谁在请求权限。
   */
  subjectId: string;
  /**
   * 请求的权限名称，说明主体需要什么权限。
   */
  permission: string;
  /**
   * 请求权限的原因说明，用于向用户展示请求上下文以决定是否批准。
   */
  reason: string;
  /**
   * 是否已处理，resolveConsent 执行后设为 true，避免重复处理。
   */
  resolved: boolean;
  /**
   * 是否已批准，resolveConsent 根据调用方传入的 approved 参数设置。
   */
  approved: boolean;
  /**
   * 请求创建时的时间戳，用于追踪请求发起时间。
   */
  createdAt: number;
  /**
   * 请求更新时的时间戳，resolveConsent 执行时更新。
   */
  updatedAt: number;
}

/**
 * 权限审计记录，记录每次权限操作的详细信息。
 * 由 addAudit 在 grant、revoke、check 等操作时创建，通过 listAudit 可查询所有审计记录。
 */
export interface PermissionAuditRecord {
  /**
   * 审计记录的唯一标识，格式为 permission-audit-{自增序号}。
   */
  id: string;
  /**
   * 操作类型（如 grant、revoke、check、consent.request、consent.denied），用于审计分类。
   */
  action: string;
  /**
   * 操作涉及的主体类型，用于审计追溯时确定主体种类。
   */
  subjectType: string;
  /**
   * 操作涉及的主体标识，用于审计追溯时确定具体主体。
   */
  subjectId: string;
  /**
   * 操作涉及的权限名称，用于审计追溯时确定被操作的权限。
   */
  permission: string;
  /**
   * 操作涉及的资源标识，用于审计追溯时确定被操作的资源。
   */
  resource: string;
  /**
   * 操作是否允许，用于审计追溯时判断操作结果。
   */
  allowed: boolean;
  /**
   * 操作的原因或结果描述，用于审计追溯时的详细说明。
   */
  reason: string;
  /**
   * 审计记录创建时的时间戳。
   */
  createdAt: number;
}

/**
 * 权限策略记录，存储针对主体的各种策略配置。
 * 由 setPolicy 创建，可通过 listPolicies 查询指定主体的所有策略。
 */
export interface PermissionPolicyRecord {
  /**
   * 策略所属的主体类型，用于区分不同类型主体（如 plugin、persona）的策略。
   */
  subjectType: string;
  /**
   * 策略所属的主体标识，用于定位具体主体的策略记录。
   */
  subjectId: string;
  /**
   * 策略类型（如 fileRoot 文件根目录、executionTimeout 执行超时、crashCount 崩溃次数），区分不同策略种类。
   */
  policyType: string;
  /**
   * 策略的字段值，对应策略类型的具体取值。
   */
  value: string;
  /**
   * 策略创建时的时间戳，用于追踪策略首次配置时间。
   */
  createdAt: number;
  /**
   * 策略最后更新时间戳，用于追踪策略最近一次变更时间。
   */
  updatedAt: number;
}

/**
 * 权限授予完成时通过事件总线发布的数据载荷。
 * 由 grant 方法发布，通知监听方（如 UI 层）更新权限状态显示。
 */
export interface PermissionGrantedPayload {
  /**
   * 已授予的权限记录，供监听方获取授权详情。
   */
  grant: PermissionGrantRecord;
}

/**
 * 权限检查完成时通过事件总线发布的数据载荷。
 * 由 publishCheck 在每次 check 操作后发布，通知监听方记录权限检查日志。
 */
export interface PermissionCheckedPayload {
  /**
   * 权限检查结果，供监听方获取判决详情。
   */
  result: PermissionCheckResult;
}

/**
 * 权限同意请求创建或处理完成时通过事件总线发布的数据载荷。
 * 由 requestConsent（创建）和 resolveConsent（处理）发布，通知监听方更新同意请求 UI。
 */
export interface PermissionConsentPayload {
  /**
   * 当前的权限同意请求对象，供监听方获取请求状态和详情。
   */
  request: PermissionConsentRequest;
}
