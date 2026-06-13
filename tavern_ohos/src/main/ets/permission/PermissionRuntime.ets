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

export class PermissionRuntime {
  private events: EventBus;
  private grants: Map<string, PermissionGrantRecord> = new Map<string, PermissionGrantRecord>();
  private consentRequests: Map<string, PermissionConsentRequest> = new Map<string, PermissionConsentRequest>();
  private audit: Array<PermissionAuditRecord> = new Array<PermissionAuditRecord>();
  private fileRoots: Map<string, Array<string>> = new Map<string, Array<string>>();
  private dangerousApis: Set<string> = new Set<string>();
  private policies: Map<string, PermissionPolicyRecord> = new Map<string, PermissionPolicyRecord>();
  private crashCounts: Map<string, number> = new Map<string, number>();
  private isolatedPlugins: Set<string> = new Set<string>();
  private auditCounter: number = 0;
  private consentCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

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

  revoke(subjectType: string, subjectId: string, permission: string): void {
    this.grants.delete(this.grantKey(subjectType, subjectId, permission));
    this.addAudit('revoke', subjectType, subjectId, permission, '', true, 'revoked');
  }

  check(subjectType: string, subjectId: string, permission: string, resource: string): PermissionCheckResult {
    const grant = this.grants.get(this.grantKey(subjectType, subjectId, permission));
    let allowed = false;
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

  resolveConsent(requestId: string, approved: boolean): PermissionConsentRequest {
    const request = this.requireConsent(requestId);
    request.resolved = true;
    request.approved = approved;
    request.updatedAt = Date.now();
    if (approved) {
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

  checkNetworkAccess(subjectType: string, subjectId: string, url: string): PermissionCheckResult {
    if (this.isPrivateNetworkUrl(url)) {
      return this.check(subjectType, subjectId, 'network:private', url);
    }
    if (url.startsWith('https://')) {
      return this.check(subjectType, subjectId, 'network:https', url);
    }
    return this.check(subjectType, subjectId, 'network:http', url);
  }

  addAllowedFileRoot(subjectType: string, subjectId: string, root: string): PermissionPolicyRecord {
    const key = this.subjectKey(subjectType, subjectId);
    const roots = this.fileRoots.get(key);
    const records = roots === undefined ? new Array<string>() : roots;
    records.push(root);
    this.fileRoots.set(key, records);
    const policy = this.setPolicy(subjectType, subjectId, 'fileRoot', root);
    this.addAudit('policy.fileRoot', subjectType, subjectId, 'file:access', root, true, 'root added');
    return this.copyPolicy(policy);
  }

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

  blockDangerousApi(apiName: string): void {
    this.dangerousApis.add(apiName);
    this.addAudit('policy.blockApi', 'runtime', 'global', 'api:block', apiName, true, 'api blocked');
  }

  checkDangerousApi(subjectType: string, subjectId: string, apiName: string): PermissionCheckResult {
    if (this.dangerousApis.has(apiName)) {
      return this.publishCheck(subjectType, subjectId, 'api:use', apiName, false, `Dangerous API blocked: ${apiName}`);
    }
    return this.publishCheck(subjectType, subjectId, 'api:use', apiName, true, 'allowed');
  }

  setExecutionTimeout(subjectType: string, subjectId: string, timeoutMs: number): PermissionPolicyRecord {
    const policy = this.setPolicy(subjectType, subjectId, 'executionTimeout', `${timeoutMs}`);
    this.addAudit('policy.timeout', subjectType, subjectId, 'execution:timeout', `${timeoutMs}`, true, 'timeout set');
    return this.copyPolicy(policy);
  }

  recordPluginCrash(pluginId: string): PermissionPolicyRecord {
    const current = this.crashCounts.get(pluginId);
    const count = current === undefined ? 1 : current + 1;
    this.crashCounts.set(pluginId, count);
    if (count >= 3) {
      this.isolatedPlugins.add(pluginId);
    }
    const policy = this.setPolicy('plugin', pluginId, 'crashCount', `${count}`);
    this.addAudit('plugin.crash', 'plugin', pluginId, 'plugin:execute', `${count}`, count < 3, count >= 3 ? 'isolated' : 'recorded');
    return this.copyPolicy(policy);
  }

  isPluginIsolated(pluginId: string): boolean {
    return this.isolatedPlugins.has(pluginId);
  }

  listAudit(): Array<PermissionAuditRecord> {
    const result = new Array<PermissionAuditRecord>();
    for (let index = 0; index < this.audit.length; index += 1) {
      result.push(this.copyAudit(this.audit[index]));
    }
    return result;
  }

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

  private setPolicy(subjectType: string, subjectId: string, policyType: string, value: string): PermissionPolicyRecord {
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

  private requireConsent(requestId: string): PermissionConsentRequest {
    const request = this.consentRequests.get(requestId);
    if (request === undefined) {
      throw new Error(`Permission consent request not found: ${requestId}`);
    }
    return request;
  }

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

  private isPrivateIpv6(host: string): boolean {
    return host.startsWith('fc')
      || host.startsWith('fd')
      || host.startsWith('fe8')
      || host.startsWith('fe9')
      || host.startsWith('fea')
      || host.startsWith('feb');
  }

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

  private inIpv4Range(value: number, baseAddress: string, prefix: number): boolean {
    const base = this.parseIpv4(baseAddress);
    if (base < 0) {
      return false;
    }
    const mask = prefix === 0 ? 0 : (0xffffffff << (32 - prefix)) >>> 0;
    return (value & mask) === (base & mask);
  }

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
