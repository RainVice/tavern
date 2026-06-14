import { EventBus } from '../runtime/EventBus';
import type { RuntimePermission } from '../contracts/PublicContracts';
import type {
  PermissionAuditRecord,
  PermissionCheckedPayload,
  PermissionCheckResult,
  PermissionConsentPayload,
  PermissionConsentRequest,
  PermissionGrantedPayload,
  PermissionGrantParams,
  PermissionGrantRecord,
  PermissionPolicyRecord,
} from './PermissionModels';

/**
 * 提供权限审计相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class PermissionRuntime {
  /**
   * 事件总线，用于发布权限相关事件。
   */
  private events: EventBus;
  /**
   * 已授权的权限记录，键为 subjectType:subjectId:permission。
   */
  private grants: Map<string, PermissionGrantRecord> = new Map<string, PermissionGrantRecord>();
  /**
   * 待处理或已处理的授权请求，键为请求 ID。
   */
  private consentRequests: Map<string, PermissionConsentRequest> = new Map<string, PermissionConsentRequest>();
  /**
   * 审计操作历史记录列表。
   */
  private audit: Array<PermissionAuditRecord> = new Array<PermissionAuditRecord>();
  /**
   * 允许访问的文件根路径，键为 subjectType:subjectId。
   */
  private fileRoots: Map<string, Array<string>> = new Map<string, Array<string>>();
  /**
   * 被封禁的危险 API 名称集合。
   */
  private dangerousApis: Set<string> = new Set<string>();
  /**
   * 权限策略记录，键为 subjectType:subjectId:policyType:value。
   */
  private policies: Map<string, PermissionPolicyRecord> = new Map<string, PermissionPolicyRecord>();
  /**
   * 插件崩溃次数计数，键为插件标识。
   */
  private crashCounts: Map<string, number> = new Map<string, number>();
  /**
   * 因频繁崩溃而被隔离的插件标识集合。
   */
  private isolatedPlugins: Set<string> = new Set<string>();
  /**
   * 审计记录计数器，用于生成唯一 ID。
   */
  private auditCounter: number = 0;
  /**
   * 授权请求计数器，用于生成唯一 ID。
   */
  private consentCounter: number = 0;

  /**
   * 初始化权限运行时实例，绑定事件总线。
   * @param events 事件总线实例，用于发布权限变更事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 授予指定主体指定权限，并发布授权事件。
   * @param params 授权参数，包含主体、权限、作用域和过期时间。
   * @returns 新创建的授权记录副本。
   */
  grant(params: PermissionGrantParams): PermissionGrantRecord {
    const grant: PermissionGrantRecord = {
      subjectType: params.subjectType,
      subjectId: params.subjectId,
      permission: params.permission,
      scope: params.scope,
      expiresAt: params.expiresAt,
      grantedAt: Date.now(),
    };
    this.grants.set(this.grantKey(params.subjectType, params.subjectId, params.permission), this.copyGrant(grant));
    this.addAudit('grant', params.subjectType, params.subjectId, params.permission, params.scope, true, 'granted');
    const payload: PermissionGrantedPayload = {
      grant: this.copyGrant(grant),
    };
    this.events.publish<PermissionGrantedPayload>('permission.granted', payload);
    return this.copyGrant(grant);
  }

  /**
   * 撤销指定主体指定权限，并记录审计日志。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param permission 需要撤销的运行时权限标识。
   */
  revoke(subjectType: string, subjectId: string, permission: RuntimePermission): void {
    this.grants.delete(this.grantKey(subjectType, subjectId, permission));
    this.addAudit('revoke', subjectType, subjectId, permission, '', true, 'revoked');
  }

  /**
   * 检查指定主体是否拥有指定权限，并记录审计日志。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param permission 待检查的运行时权限标识。
   * @param resource 被访问的资源描述。
   * @returns 包含是否允许以及原因说明的检查结果。
   */
  check(subjectType: string, subjectId: string, permission: RuntimePermission, resource: string): PermissionCheckResult {
    const grant = this.grants.get(this.grantKey(subjectType, subjectId, permission));
    let allowed = false;
    // 原因说明。
    let reason = `Missing permission: ${permission}`;
    if (grant !== undefined) {
      if (grant.expiresAt === 0 || grant.expiresAt >= Date.now()) {
        allowed = true;
        reason = 'allowed';
      } else {
        reason = `Permission expired: ${permission}`;
      }
    }
    return this.publishCheck(subjectType, subjectId, permission, resource, allowed, reason);
  }

  /**
   * 发起权限请求，等待外部用户确认，并发布请求事件。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param permission 需要用户确认的运行时权限标识。
   * @param reason 发起请求的原因说明。
   * @returns 新创建的请求对象副本。
   */
  requestConsent(subjectType: string, subjectId: string, permission: RuntimePermission, reason: string): PermissionConsentRequest {
    this.consentCounter += 1;
    const now = Date.now();
    const request: PermissionConsentRequest = {
      id: `permission-consent-${this.consentCounter}`,
      subjectType: subjectType,
      subjectId: subjectId,
      permission: permission,
      reason: reason,
      resolved: false,
      approved: false,
      createdAt: now,
      updatedAt: now,
    };
    this.consentRequests.set(request.id, this.copyConsent(request));
    const payload: PermissionConsentPayload = {
      request: this.copyConsent(request),
    };
    this.events.publish<PermissionConsentPayload>('permission.consent.requested', payload);
    this.addAudit('consent.request', subjectType, subjectId, permission, reason, false, 'pending');
    return this.copyConsent(request);
  }

  /**
   * 处理对指定授权请求的审批结果：批准时自动执行授权，拒绝时记录审计日志。
   * @param requestId 目标授权请求标识。
   * @param approved 是否批准该请求。
   * @returns 更新后的请求对象副本。
   */
  resolveConsent(requestId: string, approved: boolean): PermissionConsentRequest {
    const request = this.requireConsent(requestId);
    request.resolved = true;
    request.approved = approved;
    request.updatedAt = Date.now();
    if (approved) {
      // 调用参数。
      const params: PermissionGrantParams = {
        subjectType: request.subjectType,
        subjectId: request.subjectId,
        permission: request.permission,
        scope: '',
        expiresAt: 0,
      };
      this.grant(params);
    } else {
      this.addAudit('consent.denied', request.subjectType, request.subjectId, request.permission, request.reason, false, 'denied');
    }
    const payload: PermissionConsentPayload = {
      request: this.copyConsent(request),
    };
    this.events.publish<PermissionConsentPayload>('permission.consent.resolved', payload);
    return this.copyConsent(request);
  }

  /**
   * 检查网络访问是否满足当前权限规则。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param url 待检查的 URL。
   * @returns 网络访问权限检查结果。
   */
  checkNetworkAccess(subjectType: string, subjectId: string, url: string): PermissionCheckResult {
    if (this.isPrivateNetworkUrl(url)) {
      return this.check(subjectType, subjectId, 'network:private', url);
    }
    if (url.startsWith('https://')) {
      return this.check(subjectType, subjectId, 'network:https', url);
    }
    return this.check(subjectType, subjectId, 'network:http', url);
  }

  /**
   * 为指定主体添加允许访问的文件根路径，并记录策略。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param root 规范化后的根路径。
   * @returns 新创建的策略记录副本。
   */
  addAllowedFileRoot(subjectType: string, subjectId: string, root: string): PermissionPolicyRecord {
    // 键名。
    const key = this.subjectKey(subjectType, subjectId);
    const roots = this.fileRoots.get(key);
    const records = roots === undefined ? new Array<string>() : roots;
    records.push(root);
    this.fileRoots.set(key, records);
    const policy = this.setPolicy(subjectType, subjectId, 'fileRoot', root);
    this.addAudit('policy.fileRoot', subjectType, subjectId, 'file:access', root, true, 'root added');
    return this.copyPolicy(policy);
  }

  /**
   * 检查文件访问是否满足当前权限规则。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param path 目标文件或目录路径。
   * @returns 文件访问权限检查结果。
   */
  checkFileAccess(subjectType: string, subjectId: string, path: string): PermissionCheckResult {
    if (path.indexOf('..') >= 0) {
      return this.publishCheck(subjectType, subjectId, 'file:access', path, false, 'Path traversal blocked');
    }
    const roots = this.fileRoots.get(this.subjectKey(subjectType, subjectId));
    if (roots !== undefined) {
      for (let index = 0; index < roots.length; index += 1) {
        if (this.isPathInRoot(path, roots[index])) {
          return this.publishCheck(subjectType, subjectId, 'file:access', path, true, 'allowed');
        }
      }
    }
    return this.publishCheck(subjectType, subjectId, 'file:access', path, false, 'File root not allowed');
  }

  /**
   * 封禁指定的危险 API，阻止后续调用。
   * @param apiName 需要封禁的 API 名称。
   */
  blockDangerousApi(apiName: string): void {
    this.dangerousApis.add(apiName);
    this.addAudit('policy.blockApi', 'runtime', 'global', 'api:block', apiName, true, 'api blocked');
  }

  /**
   * 检查指定 API 是否已被封禁，并根据结果发布审计事件。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param apiName 待检查的 API 名称。
   * @returns 包含是否允许调用的检查结果。
   */
  checkDangerousApi(subjectType: string, subjectId: string, apiName: string): PermissionCheckResult {
    if (this.dangerousApis.has(apiName)) {
      return this.publishCheck(subjectType, subjectId, 'api:use', apiName, false, `Dangerous API blocked: ${apiName}`);
    }
    return this.publishCheck(subjectType, subjectId, 'api:use', apiName, true, 'allowed');
  }

  /**
   * 设置指定主体的执行超时时间策略，并记录审计日志。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param timeoutMs 超时时间（毫秒）。
   * @returns 新创建的策略记录副本。
   */
  setExecutionTimeout(subjectType: string, subjectId: string, timeoutMs: number): PermissionPolicyRecord {
    const policy = this.setPolicy(subjectType, subjectId, 'executionTimeout', `${timeoutMs}`);
    this.addAudit('policy.timeout', subjectType, subjectId, 'execution:timeout', `${timeoutMs}`, true, 'timeout set');
    return this.copyPolicy(policy);
  }

  /**
   * 记录一次插件崩溃事件；当同一插件崩溃次数达到阈值时自动将其隔离。
   * @param pluginId 插件标识。
   * @returns 崩溃计数策略记录副本。
   */
  recordPluginCrash(pluginId: string): PermissionPolicyRecord {
    const current = this.crashCounts.get(pluginId);
    // 数量。
    const count = current === undefined ? 1 : current + 1;
    this.crashCounts.set(pluginId, count);
    if (count >= 3) {
      this.isolatedPlugins.add(pluginId);
    }
    const policy = this.setPolicy('plugin', pluginId, 'crashCount', `${count}`);
    this.addAudit('plugin.crash', 'plugin', pluginId, 'plugin:execute', `${count}`, count < 3, count >= 3 ? 'isolated' : 'recorded');
    return this.copyPolicy(policy);
  }

  /**
   * 判断指定插件是否因频繁崩溃而被隔离。
   * @param pluginId 插件标识。
   * @returns 已被隔离时返回 true，否则返回 false。
   */
  isPluginIsolated(pluginId: string): boolean {
    return this.isolatedPlugins.has(pluginId);
  }

  /**
   * 返回审计记录列表的副本。
   * @returns 审计记录数组；调用方修改返回值不影响内部状态。
   */
  listAudit(): Array<PermissionAuditRecord> {
    const result = new Array<PermissionAuditRecord>();
    for (let index = 0; index < this.audit.length; index += 1) {
      result.push(this.copyAudit(this.audit[index]));
    }
    return result;
  }

  /**
   * 返回指定主体的策略记录列表的副本。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @returns 符合条件的策略记录数组；调用方修改返回值不影响内部状态。
   */
  listPolicies(subjectType: string, subjectId: string): Array<PermissionPolicyRecord> {
    const prefix = `${this.subjectKey(subjectType, subjectId)}:`;
    const result = new Array<PermissionPolicyRecord>();
    const keys = Array.from(this.policies.keys());
    for (let index = 0; index < keys.length; index += 1) {
      if (keys[index].startsWith(prefix)) {
        const policy = this.policies.get(keys[index]);
        if (policy !== undefined) {
          result.push(this.copyPolicy(policy));
        }
      }
    }
    return result;
  }

  /**
   * 发布权限检查事件并记录审计日志。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param permission 待检查的运行时权限标识。
   * @param resource 被访问的资源描述。
   * @param allowed 是否允许通过。
   * @param reason 检查结果的原因说明。
   * @returns 权限检查结果。
   */
  private publishCheck(
    subjectType: string,
    subjectId: string,
    permission: RuntimePermission,
    resource: string,
    allowed: boolean,
    reason: string,
  ): PermissionCheckResult {
    const result: PermissionCheckResult = {
      allowed: allowed,
      reason: reason,
      subjectType: subjectType,
      subjectId: subjectId,
      permission: permission,
      resource: resource,
    };
    const payload: PermissionCheckedPayload = {
      result: this.copyCheckResult(result),
    };
    this.events.publish<PermissionCheckedPayload>('permission.checked', payload);
    this.addAudit('check', subjectType, subjectId, permission, resource, allowed, reason);
    return this.copyCheckResult(result);
  }

  /**
   * 创建或更新一条权限策略记录。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param policyType 策略类型。
   * @param value 策略值。
   * @returns 策略记录副本。
   */
  private setPolicy(subjectType: string, subjectId: string, policyType: string, value: string): PermissionPolicyRecord {
    // 键名。
    const key = `${this.subjectKey(subjectType, subjectId)}:${policyType}:${value}`;
    const now = Date.now();
    const existing = this.policies.get(key);
    const policy: PermissionPolicyRecord = {
      subjectType: subjectType,
      subjectId: subjectId,
      policyType: policyType,
      value: value,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.policies.set(key, this.copyPolicy(policy));
    return this.copyPolicy(policy);
  }

  /**
   * 创建并追加一条审计日志记录。
   * @param action 审计操作类型。
   * @param subjectType 目标主体类型。
   * @param subjectId 目标主体标识。
   * @param permission 涉及的运行时权限标识。
   * @param resource 涉及的资源描述。
   * @param allowed 是否允许通过。
   * @param reason 审计原因说明。
   * @returns 新创建的审计记录。
   */
  private addAudit(
    action: string,
    subjectType: string,
    subjectId: string,
    permission: RuntimePermission,
    resource: string,
    allowed: boolean,
    reason: string,
  ): PermissionAuditRecord {
    this.auditCounter += 1;
    const record: PermissionAuditRecord = {
      id: `permission-audit-${this.auditCounter}`,
      action: action,
      subjectType: subjectType,
      subjectId: subjectId,
      permission: permission,
      resource: resource,
      allowed: allowed,
      reason: reason,
      createdAt: Date.now(),
    };
    this.audit.push(record);
    return this.copyAudit(record);
  }

  /**
   * 根据 ID 查找授权请求，不存在则抛出异常。
   * @param requestId 目标请求标识。
   * @returns 查找到的授权请求对象。
   */
  private requireConsent(requestId: string): PermissionConsentRequest {
    const request = this.consentRequests.get(requestId);
    if (request === undefined) {
      throw new Error(`Permission consent request not found: ${requestId}`);
    }
    return request;
  }

  /**
   * 判断给定 URL 是否属于私有网络地址。
   * @returns 是私有地址时返回 true，否则返回 false。
   */
  private isPrivateNetworkUrl(url: string): boolean {
    const host = this.extractHost(url).toLowerCase();
    if (host.length === 0) {
      return false;
    }
    if (host === 'localhost' || host === '::1') {
      return true;
    }
    if (this.isPrivateIpv6(host)) {
      return true;
    }
    const ipv4 = this.parseIpv4(host);
    if (ipv4 < 0) {
      return false;
    }
    return this.inIpv4Range(ipv4, '127.0.0.0', 8)
      || this.inIpv4Range(ipv4, '10.0.0.0', 8)
      || this.inIpv4Range(ipv4, '172.16.0.0', 12)
      || this.inIpv4Range(ipv4, '192.168.0.0', 16)
      || this.inIpv4Range(ipv4, '169.254.0.0', 16);
  }

  /**
   * 从 URL 中提取主机名。
   */
  private extractHost(url: string): string {
    const schemeIndex = url.indexOf('://');
    if (schemeIndex < 0) {
      return '';
    }
    const remainder = url.substring(schemeIndex + 3);
    if (remainder.startsWith('[')) {
      const endIndex = remainder.indexOf(']');
      if (endIndex < 0) {
        return '';
      }
      return remainder.substring(1, endIndex);
    }
    let endIndex = remainder.length;
    const slashIndex = remainder.indexOf('/');
    if (slashIndex >= 0 && slashIndex < endIndex) {
      endIndex = slashIndex;
    }
    const queryIndex = remainder.indexOf('?');
    if (queryIndex >= 0 && queryIndex < endIndex) {
      endIndex = queryIndex;
    }
    const hashIndex = remainder.indexOf('#');
    if (hashIndex >= 0 && hashIndex < endIndex) {
      endIndex = hashIndex;
    }
    const hostPort = remainder.substring(0, endIndex);
    const colonIndex = hostPort.indexOf(':');
    if (colonIndex < 0) {
      return hostPort;
    }
    return hostPort.substring(0, colonIndex);
  }

  /**
   * 判断主机名是否属于私有 IPv6 地址范围。
   * @param host 待判断的主机名。
   * @returns 是私有 IPv6 地址时返回 true，否则返回 false。
   */
  private isPrivateIpv6(host: string): boolean {
    return host.startsWith('fc')
      || host.startsWith('fd')
      || host.startsWith('fe8')
      || host.startsWith('fe9')
      || host.startsWith('fea')
      || host.startsWith('feb');
  }

  /**
   * 将 IPv4 地址字符串解析为 32 位整数。
   * @param host 待解析的 IPv4 地址字符串。
   * @returns 解析成功返回整数，否则返回 -1。
   */
  private parseIpv4(host: string): number {
    const parts = host.split('.');
    if (parts.length !== 4) {
      return -1;
    }
    let value = 0;
    for (let index = 0; index < parts.length; index += 1) {
      if (!this.isDecimalDigits(parts[index])) {
        return -1;
      }
      const segment = Number.parseInt(parts[index], 10);
      if (Number.isNaN(segment) || segment < 0 || segment > 255) {
        return -1;
      }
      value = ((value * 256) + segment) >>> 0;
    }
    return value;
  }

  /**
   * 判断给定的整数 IPv4 地址是否在指定的 CIDR 地址段内。
   * @param value 待检查的 IPv4 整数地址。
   * @param baseAddress CIDR 网络地址字符串。
   * @param prefix CIDR 前缀长度（0-32）。
   * @returns 在地址段内返回 true，否则返回 false。
   */
  private inIpv4Range(value: number, baseAddress: string, prefix: number): boolean {
    const base = this.parseIpv4(baseAddress);
    if (base < 0) {
      return false;
    }
    const mask = prefix === 0 ? 0 : (0xffffffff << (32 - prefix)) >>> 0;
    return (value & mask) === (base & mask);
  }

  /**
   * 判断字符串是否为纯十进制数字。
   * @param value 待检查的字符串。
   * @returns 全部由十进制数字组成时返回 true，否则返回 false。
   */
  private isDecimalDigits(value: string): boolean {
    if (value.length === 0) {
      return false;
    }
    for (let index = 0; index < value.length; index += 1) {
      const code = value.charCodeAt(index);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  /**
   * 判断路径是否在指定的根路径范围内（防止路径穿越）。
   * @param path 目标文件或目录路径。
   * @param root 规范化后的根路径。
   * @returns 在根路径内返回 true，否则返回 false。
   */
  private isPathInRoot(path: string, root: string): boolean {
    if (root.length === 0) {
      return false;
    }
    if (path === root) {
      return true;
    }
    if (root.endsWith('/')) {
      return path.startsWith(root);
    }
    return path.startsWith(`${root}/`);
  }
  private grantKey(subjectType: string, subjectId: string, permission: RuntimePermission): string {
    return `${this.subjectKey(subjectType, subjectId)}:${permission}`;
  }
  private subjectKey(subjectType: string, subjectId: string): string {
    return `${subjectType}:${subjectId}`;
  }

  /**
   * 深拷贝授权记录，防止外部修改内部状态。
   */
  private copyGrant(grant: PermissionGrantRecord): PermissionGrantRecord {
    return {
      subjectType: grant.subjectType,
      subjectId: grant.subjectId,
      permission: grant.permission,
      scope: grant.scope,
      expiresAt: grant.expiresAt,
      grantedAt: grant.grantedAt,
    };
  }

  /**
   * 深拷贝授权请求对象，防止外部修改内部状态。
   * @param request 待深拷贝的授权请求对象。
   */
  private copyConsent(request: PermissionConsentRequest): PermissionConsentRequest {
    return {
      id: request.id,
      subjectType: request.subjectType,
      subjectId: request.subjectId,
      permission: request.permission,
      reason: request.reason,
      resolved: request.resolved,
      approved: request.approved,
      createdAt: request.createdAt,
      updatedAt: request.updatedAt,
    };
  }

  /**
   * 深拷贝审计记录，防止外部修改内部状态。
   * @param record 待深拷贝的审计记录。
   */
  private copyAudit(record: PermissionAuditRecord): PermissionAuditRecord {
    return {
      id: record.id,
      action: record.action,
      subjectType: record.subjectType,
      subjectId: record.subjectId,
      permission: record.permission,
      resource: record.resource,
      allowed: record.allowed,
      reason: record.reason,
      createdAt: record.createdAt,
    };
  }

  /**
   * 深拷贝策略记录，防止外部修改内部状态。
   */
  private copyPolicy(policy: PermissionPolicyRecord): PermissionPolicyRecord {
    return {
      subjectType: policy.subjectType,
      subjectId: policy.subjectId,
      policyType: policy.policyType,
      value: policy.value,
      createdAt: policy.createdAt,
      updatedAt: policy.updatedAt,
    };
  }

  /**
   * 深拷贝检查结果，防止外部修改内部状态。
   * @param result 待深拷贝的检查结果。
   */
  private copyCheckResult(result: PermissionCheckResult): PermissionCheckResult {
    return {
      allowed: result.allowed,
      reason: result.reason,
      subjectType: result.subjectType,
      subjectId: result.subjectId,
      permission: result.permission,
      resource: result.resource,
    };
  }
}
