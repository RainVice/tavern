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
 * 调用方（如插件系统、文件系统、网络客户端）在操作敏感资源前通过此运行时进行权限检查，
 * 确保主体拥有足够的权限执行操作。
 */
export class PermissionRuntime {
  /**
   * 事件总线，用于发布权限授予、检查及同意请求等事件，通知监听方（如 UI 层）更新状态显示。
   */
  private events: EventBus;
  /**
   * 权限授予记录的索引，键为 subjectType:subjectId:permission。
   * 用于在 check 时快速查找主体是否拥有某权限。
   */
  private grants: Map<string, PermissionGrantRecord> = new Map<string, PermissionGrantRecord>();
  /**
   * 待处理的权限同意请求，键为请求 ID。
   * 用于跟踪需要用户交互确认的权限申请。
   */
  private consentRequests: Map<string, PermissionConsentRequest> = new Map<string, PermissionConsentRequest>();
  /**
   * 权限审计记录列表，记录每次操作详情。
   * 通过 listAudit 可查询所有历史操作，用于安全审计。
   */
  private audit: Array<PermissionAuditRecord> = new Array<PermissionAuditRecord>();
  /**
   * 允许文件访问的根目录列表，按 subjectType:subjectId 索引。
   * 用于 checkFileAccess 时判断文件路径是否在允许范围内。
   */
  private fileRoots: Map<string, Array<string>> = new Map<string, Array<string>>();
  /**
   * 被阻止的危险 API 名称集合。
   * 用于 checkDangerousApi 时判断 API 是否被阻止调用。
   */
  private dangerousApis: Set<string> = new Set<string>();
  /**
   * 权限策略记录索引，键为 subjectType:subjectId:policyType:value。
   * 用于存储文件根目录、执行超时、崩溃次数等运行时策略。
   */
  private policies: Map<string, PermissionPolicyRecord> = new Map<string, PermissionPolicyRecord>();
  /**
   * 插件崩溃次数统计，键为 pluginId。
   * 在 recordPluginCrash 中自增，达到 3 次自动隔离插件。
   */
  private crashCounts: Map<string, number> = new Map<string, number>();
  /**
   * 已被隔离的插件 ID 集合（崩溃达 3 次）。
   * 在 isPluginIsolated 中用于判断插件是否被阻止执行。
   */
  private isolatedPlugins: Set<string> = new Set<string>();
  /**
   * 审计记录自增计数器。
   */
  private auditCounter: number = 0;
  /**
   * 同意请求自增计数器。
   */
  private consentCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例，用于后续权限事件发布。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 授予主体指定的权限，创建授权记录、写入审计日志并发布授权事件。
   * 调用方（如权限管理界面或同意审批流程）在决定授予权限后调用此方法。
   * @param params 授权参数，包含主体类型、主体标识、权限名、作用域和过期时间。
   * @returns 创建的授权记录副本。
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
    this.grants.set(
      this.grantKey(params.subjectType, params.subjectId, params.permission),
      this.copyGrant(grant),
    );
    this.addAudit('grant', params.subjectType, params.subjectId, params.permission, params.scope, true, 'granted');
    const payload: PermissionGrantedPayload = {
      grant: this.copyGrant(grant),
    };
    this.events.publish<PermissionGrantedPayload>('permission.granted', payload);
    return this.copyGrant(grant);
  }

  /**
   * 撤销主体指定的权限，从授权记录中删除并写入审计日志。
   * 调用方（如权限管理界面）在需要收回权限时调用此方法。
   * @param subjectType 主体类型，用于定位要撤销的授权记录。
   * @param subjectId 主体标识，用于定位要撤销的授权记录。
   * @param permission 权限名称，用于定位要撤销的授权记录。
   */
  revoke(subjectType: string, subjectId: string, permission: string): void {
    this.grants.delete(this.grantKey(subjectType, subjectId, permission));
    this.addAudit('revoke', subjectType, subjectId, permission, '', true, 'revoked');
  }

  /**
   * 检查主体是否拥有指定权限（含过期校验），发布检查事件并返回判决结果。
   * 调用方（如文件系统、网络客户端）在执行敏感操作前调用此方法进行权限校验。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param permission 权限名称，指定要检查的权限类型。
   * @param resource 被访问的资源标识，用于审计日志记录。
   * @returns 权限检查结果，调用方根据 allowed 字段决定是否允许操作继续。
   */
  check(
    subjectType: string,
    subjectId: string,
    permission: string,
    resource: string,
  ): PermissionCheckResult {
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

  /**
   * 创建权限同意请求，发布请求事件并写入审计日志。
   * 调用方（如插件系统）在需要申请用户许可但尚无授权时调用，等待外部 resolveConsent 处理。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param permission 请求的权限名称。
   * @param reason 请求权限的原因说明，用于向用户展示。
   * @returns 创建的同意请求副本，id 可用于后续的 resolveConsent。
   */
  requestConsent(
    subjectType: string,
    subjectId: string,
    permission: string,
    reason: string,
  ): PermissionConsentRequest {
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
   * 决定同意请求的审批结果：批准则自动执行授权，拒绝则写入审计日志。
   * 外部（如 UI 层的权限同意弹窗）在用户做出决策后调用此方法。
   * @param requestId 目标同意请求的标识，由 requestConsent 返回的 id。
   * @param approved 是否批准。
   * @returns 更新后的同意请求副本。
   */
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
      this.addAudit(
        'consent.denied',
        request.subjectType,
        request.subjectId,
        request.permission,
        request.reason,
        false,
        'denied',
      );
    }
    const payload: PermissionConsentPayload = {
      request: this.copyConsent(request),
    };
    this.events.publish<PermissionConsentPayload>('permission.consent.resolved', payload);
    return this.copyConsent(request);
  }

  /**
   * 检查主体是否有权访问指定 URL（区分私网、HTTPS、HTTP 权限）。
   * 调用方（如 HTTP 客户端）在发起网络请求前调用，根据 URL 的协议和目标自动选择对应的网络权限检查。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param url 要访问的 URL，根据是否是私网和协议类型选择不同的检查权限。
   * @returns 权限检查结果。
   */
  checkNetworkAccess(
    subjectType: string,
    subjectId: string,
    url: string,
  ): PermissionCheckResult {
    if (this.isPrivateNetworkUrl(url)) {
      return this.check(subjectType, subjectId, 'network:private', url);
    }
    if (url.startsWith('https://')) {
      return this.check(subjectType, subjectId, 'network:https', url);
    }
    return this.check(subjectType, subjectId, 'network:http', url);
  }

  /**
   * 为主体添加允许文件访问的根目录，并写入策略记录。
   * 调用方（如插件管理界面）在配置插件的文件访问权限时调用，用于限定文件读写范围。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param root 允许文件访问的根路径，后续 checkFileAccess 会校验访问路径是否在此根目录下。
   * @returns 创建的权限策略记录副本。
   */
  addAllowedFileRoot(
    subjectType: string,
    subjectId: string,
    root: string,
  ): PermissionPolicyRecord {
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
   * 检查主体能否访问指定文件路径（防路径遍历，且必须在允许的根目录下）。
   * 调用方（如文件 I/O 系统）在读取或写入文件前调用，防止越权访问。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param path 要访问的文件路径，需要校验是否包含 .. 路径遍历且是否在允许的根目录下。
   * @returns 权限检查结果。
   */
  checkFileAccess(
    subjectType: string,
    subjectId: string,
    path: string,
  ): PermissionCheckResult {
    if (path.indexOf('..') >= 0) {
      return this.publishCheck(
        subjectType,
        subjectId,
        'file:access',
        path,
        false,
        'Path traversal blocked',
      );
    }
    const roots = this.fileRoots.get(this.subjectKey(subjectType, subjectId));
    if (roots !== undefined) {
      for (let index = 0; index < roots.length; index += 1) {
        if (this.isPathInRoot(path, roots[index])) {
          return this.publishCheck(
            subjectType,
            subjectId,
            'file:access',
            path,
            true,
            'allowed',
          );
        }
      }
    }
    return this.publishCheck(
      subjectType,
      subjectId,
      'file:access',
      path,
      false,
      'File root not allowed',
    );
  }

  /**
   * 将指定 API 加入阻止名单，后续调用将阻止使用。
   * 调用方（如安全策略配置）在发现危险 API 时调用，阻止不安全代码执行。
   * @param apiName 要阻止的 API 名称。
   */
  blockDangerousApi(apiName: string): void {
    this.dangerousApis.add(apiName);
    this.addAudit('policy.blockApi', 'runtime', 'global', 'api:block', apiName, true, 'api blocked');
  }

  /**
   * 检查指定 API 是否在阻止名单中。
   * 调用方（如脚本执行引擎）在执行任意代码前调用，阻止危险 API 被调用。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param apiName API 名称。
   * @returns 权限检查结果。
   */
  checkDangerousApi(
    subjectType: string,
    subjectId: string,
    apiName: string,
  ): PermissionCheckResult {
    if (this.dangerousApis.has(apiName)) {
      return this.publishCheck(
        subjectType,
        subjectId,
        'api:use',
        apiName,
        false,
        `Dangerous API blocked: ${apiName}`,
      );
    }
    return this.publishCheck(subjectType, subjectId, 'api:use', apiName, true, 'allowed');
  }

  /**
   * 设置主体的脚本执行超时时间，并写入策略记录。
   * 调用方（如插件管理器）在配置插件执行限制时调用，防止脚本无限执行。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param timeoutMs 超时毫秒数，超过此时间未完成的脚本执行将被终止。
   * @returns 创建的权限策略记录副本。
   */
  setExecutionTimeout(
    subjectType: string,
    subjectId: string,
    timeoutMs: number,
  ): PermissionPolicyRecord {
    const policy = this.setPolicy(
      subjectType,
      subjectId,
      'executionTimeout',
      `${timeoutMs}`,
    );
    this.addAudit(
      'policy.timeout',
      subjectType,
      subjectId,
      'execution:timeout',
      `${timeoutMs}`,
      true,
      'timeout set',
    );
    return this.copyPolicy(policy);
  }

  /**
   * 记录插件崩溃事件，崩溃达到 3 次时自动隔离该插件。
   * 调用方（如插件执行器）在插件执行失败时调用，用于自动防止频繁崩溃的插件继续运行。
   * @param pluginId 插件标识。
   * @returns 创建的权限策略记录副本。
   */
  recordPluginCrash(pluginId: string): PermissionPolicyRecord {
    const current = this.crashCounts.get(pluginId);
    const count = current === undefined ? 1 : current + 1;
    this.crashCounts.set(pluginId, count);
    if (count >= 3) {
      this.isolatedPlugins.add(pluginId);
    }
    const policy = this.setPolicy('plugin', pluginId, 'crashCount', `${count}`);
    this.addAudit(
      'plugin.crash',
      'plugin',
      pluginId,
      'plugin:execute',
      `${count}`,
      count < 3,
      count >= 3 ? 'isolated' : 'recorded',
    );
    return this.copyPolicy(policy);
  }

  /**
   * 判断指定插件是否因崩溃次数过多而被隔离。
   * 调用方（如插件执行器）在尝试执行插件前调用，跳过被隔离的插件。
   * @param pluginId 插件标识。
   * @returns 已被隔离时返回 true。
   */
  isPluginIsolated(pluginId: string): boolean {
    return this.isolatedPlugins.has(pluginId);
  }

  /**
   * 返回当前所有审计记录的副本列表。
   * 调用方（如安全审计界面）用于展示权限操作的完整历史。
   * @returns 审计记录列表。
   */
  listAudit(): Array<PermissionAuditRecord> {
    const result = new Array<PermissionAuditRecord>();
    for (let index = 0; index < this.audit.length; index += 1) {
      result.push(this.copyAudit(this.audit[index]));
    }
    return result;
  }

  /**
   * 返回指定主体的所有策略记录副本列表。
   * 调用方（如配置管理界面）用于查看指定主体的完整策略配置。
   * @param subjectType 主体类型，用于过滤策略记录。
   * @param subjectId 主体标识，用于过滤策略记录。
   * @returns 策略记录列表。
   */
  listPolicies(
    subjectType: string,
    subjectId: string,
  ): Array<PermissionPolicyRecord> {
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
   * 发布权限检查结果事件并写入审计日志。
   * 在 check、checkFileAccess、checkNetworkAccess、checkDangerousApi 内部调用，统一处理结果发布。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param permission 被检查的权限名称。
   * @param resource 被访问的资源标识。
   * @param allowed 是否允许。
   * @param reason 判决原因说明。
   * @returns 权限检查结果副本。
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
   * 创建或更新指定主体的策略记录，用于存储各种运行时策略配置。
   * 在 addAllowedFileRoot、setExecutionTimeout、recordPluginCrash 中调用。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param policyType 策略类型（如 fileRoot、executionTimeout、crashCount）。
   * @param value 策略值。
   * @returns 策略记录副本。
   */
  private setPolicy(
    subjectType: string,
    subjectId: string,
    policyType: string,
    value: string,
  ): PermissionPolicyRecord {
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
   * 创建审计记录并追加到列表中。
   * 在 grant、revoke、requestConsent、resolveConsent、check 等操作中调用。
   * @param action 操作类型。
   * @param subjectType 主体类型。
   * @param subjectId 主体标识。
   * @param permission 权限名称。
   * @param resource 资源标识。
   * @param allowed 是否允许。
   * @param reason 原因说明。
   * @returns 创建的审计记录副本。
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
   * 按 ID 查找同意请求，不存在时抛出异常。
   * 在 resolveConsent 中调用，用于定位需要处理的同意请求。
   * @param requestId 同意请求标识。
   * @returns 匹配的同意请求引用。
   */
  private requireConsent(requestId: string): PermissionConsentRequest {
    const request = this.consentRequests.get(requestId);
    if (request === undefined) {
      throw new Error(`Permission consent request not found: ${requestId}`);
    }
    return request;
  }

  /**
   * 判断 URL 是否指向私网地址（localhost、私网 IPv4/IPv6）。
   * 在 checkNetworkAccess 中用于决定使用 network:private 还是 network:https/http 权限检查。
   * @param url 待检查的 URL。
   * @returns 是私网地址时返回 true。
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
    return (
      this.inIpv4Range(ipv4, '127.0.0.0', 8) ||
      this.inIpv4Range(ipv4, '10.0.0.0', 8) ||
      this.inIpv4Range(ipv4, '172.16.0.0', 12) ||
      this.inIpv4Range(ipv4, '192.168.0.0', 16) ||
      this.inIpv4Range(ipv4, '169.254.0.0', 16)
    );
  }

  /**
   * 从 URL 中提取 host 部分（处理协议、路径、端口号、IPv6 括号等）。
   * 在 isPrivateNetworkUrl 中用于从完整 URL 中解析出主机名。
   * @param url 完整的 URL。
   * @returns 提取后的 host 字符串。
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
   * 判断 IPv6 地址是否为私有或链路本地地址。
   * 在 isPrivateNetworkUrl 中用于 IPv6 地址的私有性检查。
   * @param host 主机名字符串。
   * @returns 是私有 IPv6 时返回 true。
   */
  private isPrivateIpv6(host: string): boolean {
    return (
      host.startsWith('fc') ||
      host.startsWith('fd') ||
      host.startsWith('fe8') ||
      host.startsWith('fe9') ||
      host.startsWith('fea') ||
      host.startsWith('feb')
    );
  }

  /**
   * 将 IPv4 点分十进制字符串转换为数值，非法输入返回 -1。
   * 在 isPrivateNetworkUrl 和 inIpv4Range 中用于 IP 范围的数值比对。
   * @param host IPv4 地址字符串。
   * @returns 数值形式的 IPv4 地址。
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
   * 判断 IPv4 数值是否落在指定的 CIDR 地址段内。
   * 在 isPrivateNetworkUrl 中用于各私网段的比对。
   * @param value IPv4 数值。
   * @param baseAddress CIDR 基准地址字符串。
   * @param prefix CIDR 前缀长度。
   * @returns 在范围内返回 true。
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
   * 判断字符串是否只包含十进制数字。
   * 在 parseIpv4 中用于校验 IP 各段仅为数字。
   * @param value 待检查的字符串。
   * @returns 全部由十进制数字组成时返回 true。
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
   * 判断文件路径是否在允许的根目录下。
   * 在 checkFileAccess 中用于校验文件访问路径的安全范围。
   * @param path 文件路径。
   * @param root 允许的根目录路径。
   * @returns 路径在根目录下返回 true。
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

  /**
   * 生成授权记录的键：subjectType:subjectId:permission。
   * 用于 grants Map 的键生成，在 grant、revoke、check 中调用。
   */
  private grantKey(
    subjectType: string,
    subjectId: string,
    permission: string,
  ): string {
    return `${this.subjectKey(subjectType, subjectId)}:${permission}`;
  }

  /**
   * 生成主体键：subjectType:subjectId。
   * 用于 fileRoots、policies 的键生成。
   */
  private subjectKey(subjectType: string, subjectId: string): string {
    return `${subjectType}:${subjectId}`;
  }

  /**
   * 深拷贝 PermissionGrantRecord。
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
   * 深拷贝 PermissionConsentRequest。
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
   * 深拷贝 PermissionAuditRecord。
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
   * 深拷贝 PermissionPolicyRecord。
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
   * 深拷贝 PermissionCheckResult。
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
