import { EventBus } from '../runtime/EventBus';
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
   * 事件总线。
   */
  private events: EventBus;
  /**
   * grants 列表，由当前实例内部维护。
   */
  private grants: Map<string, PermissionGrantRecord> = new Map<string, PermissionGrantRecord>();
  /**
   * consent Requests 列表，由当前实例内部维护。
   */
  private consentRequests: Map<string, PermissionConsentRequest> = new Map<string, PermissionConsentRequest>();
  /**
   * audit 值，由当前实例内部维护。
   */
  private audit: Array<PermissionAuditRecord> = new Array<PermissionAuditRecord>();
  /**
   * file Roots 列表，由当前实例内部维护。
   */
  private fileRoots: Map<string, Array<string>> = new Map<string, Array<string>>();
  /**
   * dangerous Apis 列表，由当前实例内部维护。
   */
  private dangerousApis: Set<string> = new Set<string>();
  /**
   * policies 列表，由当前实例内部维护。
   */
  private policies: Map<string, PermissionPolicyRecord> = new Map<string, PermissionPolicyRecord>();
  /**
   * crash Counts 列表，由当前实例内部维护。
   */
  private crashCounts: Map<string, number> = new Map<string, number>();
  /**
   * isolated Plugins 列表，由当前实例内部维护。
   */
  private isolatedPlugins: Set<string> = new Set<string>();
  /**
   * audit Counter 值，由当前实例内部维护。
   */
  private auditCounter: number = 0;
  /**
   * consent Counter 值，由当前实例内部维护。
   */
  private consentCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 执行 grant 的内部处理步骤，供当前模块复用。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 执行 revoke 的内部处理步骤，供当前模块复用。

   * @param subjectId 目标主体标识。

   */
  revoke(subjectType: string, subjectId: string, permission: string): void {
    this.grants.delete(this.grantKey(subjectType, subjectId, permission));
    this.addAudit('revoke', subjectType, subjectId, permission, '', true, 'revoked');
  }

  /**
   * 执行 check 的内部处理步骤，供当前模块复用。

   * @param subjectId 目标主体标识。
   */
  check(subjectType: string, subjectId: string, permission: string, resource: string): PermissionCheckResult {
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
   * 执行 requestConsent 的内部处理步骤，供当前模块复用。

   * @param subjectId 目标主体标识。

   * @param reason 失败、中止或恢复操作的原因说明。
   */
  requestConsent(subjectType: string, subjectId: string, permission: string, reason: string): PermissionConsentRequest {
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
   * 根据当前上下文解析Consent 值，返回实际可用值。
   * @param requestId 目标请求标识。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 检查网络Access是否满足当前规则。

   * @param subjectId 目标主体标识。
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
   * 创建或写入Allowed文件Root，完成持久化后返回可供调用方使用的结果。

   * @param subjectId 目标主体标识。
   * @param root 规范化后的根路径。
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
   * 检查文件Access是否满足当前规则。

   * @param subjectId 目标主体标识。
   * @param path 目标文件或目录路径。
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
   * 执行 blockDangerousApi 的内部处理步骤，供当前模块复用。
   * @param apiName api名称。
   */
  blockDangerousApi(apiName: string): void {
    this.dangerousApis.add(apiName);
    this.addAudit('policy.blockApi', 'runtime', 'global', 'api:block', apiName, true, 'api blocked');
  }

  /**
   * 检查DangerousApi是否满足当前规则。

   * @param subjectId 目标主体标识。
   * @param apiName api名称。
   */
  checkDangerousApi(subjectType: string, subjectId: string, apiName: string): PermissionCheckResult {
    if (this.dangerousApis.has(apiName)) {
      return this.publishCheck(subjectType, subjectId, 'api:use', apiName, false, `Dangerous API blocked: ${apiName}`);
    }
    return this.publishCheck(subjectType, subjectId, 'api:use', apiName, true, 'allowed');
  }

  /**
   * 设置执行超时时间，用于切换运行时状态或保存配置。

   * @param subjectId 目标主体标识。
   */
  setExecutionTimeout(subjectType: string, subjectId: string, timeoutMs: number): PermissionPolicyRecord {
    const policy = this.setPolicy(subjectType, subjectId, 'executionTimeout', `${timeoutMs}`);
    this.addAudit('policy.timeout', subjectType, subjectId, 'execution:timeout', `${timeoutMs}`, true, 'timeout set');
    return this.copyPolicy(policy);
  }

  /**
   * 创建或写入PluginCrash，完成持久化后返回可供调用方使用的结果。
   * @param pluginId 插件标识。
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
   * 判断Plugin Isolated 值是否满足条件。
   * @param pluginId 插件标识。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  isPluginIsolated(pluginId: string): boolean {
    return this.isolatedPlugins.has(pluginId);
  }

  /**
   * 读取Audit列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listAudit(): Array<PermissionAuditRecord> {
    const result = new Array<PermissionAuditRecord>();
    for (let index = 0; index < this.audit.length; index += 1) {
      result.push(this.copyAudit(this.audit[index]));
    }
    return result;
  }

  /**
   * 读取Policies列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @param subjectId 目标主体标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 发布权限审计事件，把状态变化通知给宿主或其他 Runtime。

   * @param subjectId 目标主体标识。



   * @param reason 失败、中止或恢复操作的原因说明。
   */
  private publishCheck(
    subjectType: string,
    subjectId: string,
    permission: string,
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
   * 设置权限策略，用于切换运行时状态或保存配置。

   * @param subjectId 目标主体标识。

   * @param value 要保存或比较的字段值。
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
   * 创建或写入Audit，完成持久化后返回可供调用方使用的结果。


   * @param subjectId 目标主体标识。



   * @param reason 失败、中止或恢复操作的原因说明。
   */
  private addAudit(
    action: string,
    subjectType: string,
    subjectId: string,
    permission: string,
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
   * 读取必须存在的Consent 值，缺失时抛出错误。
   * @param requestId 目标请求标识。
   */
  private requireConsent(requestId: string): PermissionConsentRequest {
    const request = this.consentRequests.get(requestId);
    if (request === undefined) {
      throw new Error(`Permission consent request not found: ${requestId}`);
    }
    return request;
  }

  /**
   * 判断Private Network Url 值是否满足条件。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 解析或导入主机数据，转换为当前 SDK 可使用的结构。
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
   * 判断Private Ipv6 值是否满足条件。
   * @param host 目标主机名。
   * @returns 条件命中时返回 true，否则返回 false。
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
   * 解析IPv4 地址，非法输入会返回失败标记或空结果。
   * @param host 目标主机名。
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
   * 判断 IPv4 地址是否落在指定地址段内。
   * @param value 要保存或比较的字段值。
   * @param baseAddress CIDR 或地址段的基准地址。
   * @param prefix CIDR 前缀长度。
   * @returns 条件命中时返回 true，否则返回 false。
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
   * 判断十进制数字是否满足当前规则。
   * @param value 要保存或比较的字段值。
   * @returns 条件命中时返回 true，否则返回 false。
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
   * 判断Path In Root 值是否满足条件。
   * @param path 目标文件或目录路径。
   * @param root 规范化后的根路径。
   * @returns 条件命中时返回 true，否则返回 false。
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
  private grantKey(subjectType: string, subjectId: string, permission: string): string {
    return `${this.subjectKey(subjectType, subjectId)}:${permission}`;
  }
  private subjectKey(subjectType: string, subjectId: string): string {
    return `${subjectType}:${subjectId}`;
  }

  /**
   * 复制Grant 值，避免外部修改内部状态。
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
   * 复制Consent 值，避免外部修改内部状态。
   * @param request 待处理的请求对象。
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
   * 复制Audit 值，避免外部修改内部状态。
   * @param record 记录副本。
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
   * 复制Policy 值，避免外部修改内部状态。
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
   * 复制Check Result 值，避免外部修改内部状态。
   * @param result 返回结果。
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
