import type {
  ConnectionHeaderRecord,
} from '../connection/ConnectionProfileModels';
import { ConnectionProfileRuntime } from '../connection/ConnectionProfileRuntime';
import type { SecretAccessOptions } from '../secret/SecretModels';
import { SecretRuntime } from '../secret/SecretRuntime';
import type { NetworkHeaderOverrideRule } from './NetworkModels';

/**
 * 提供网络请求头服务，封装跨 Runtime 的协作逻辑。
 */
export class NetworkService {
  /**
   * connections 列表，由当前实例内部维护。
   */
  private connections: ConnectionProfileRuntime;
  /**
   * secrets 列表，由当前实例内部维护。
   */
  private secrets: SecretRuntime;
  /**
   * override Rules 列表，由当前实例内部维护。
   */
  private overrideRules: Array<NetworkHeaderOverrideRule> = new Array<NetworkHeaderOverrideRule>();

  /**
   * 注入网络请求头运行时依赖并初始化实例状态。
   */
  constructor(connections: ConnectionProfileRuntime, secrets: SecretRuntime) {
    this.connections = connections;
    this.secrets = secrets;
  }

  /**
   * 设置请求头覆盖规则列表，用于切换运行时状态或保存配置。

   */
  setOverrideHeaders(rules: Array<NetworkHeaderOverrideRule>): void {
    this.overrideRules = this.cloneRules(rules);
  }

  /**
   * 根据当前上下文解析Headers For Profile 值，返回实际可用值。
   * @param profileId 目标连接或预设配置标识。
   * @param serverUrl 服务地址。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  resolveHeadersForProfile(profileId: string, serverUrl?: string): Array<ConnectionHeaderRecord> {
    const profile = this.connections.getProfile(profileId);
    const result = new Array<ConnectionHeaderRecord>();
    const secretValue = this.readSecretValue(profile.secretRef);
    this.appendProviderHeaders(result, profile.apiType, secretValue);
    this.appendHeaders(result, profile.additionalHeaders, false);
    this.appendOverrideHeaders(result, serverUrl ?? profile.serverUrl);
    return this.cloneHeaders(result, false);
  }

  /**
   * 执行 previewHeadersForProfile 的内部处理步骤，供当前模块复用。
   * @param profileId 目标连接或预设配置标识。
   * @param serverUrl 服务地址。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  previewHeadersForProfile(profileId: string, serverUrl?: string): Array<ConnectionHeaderRecord> {
    const resolved = this.resolveHeadersForProfile(profileId, serverUrl);
    return this.cloneHeaders(resolved, true);
  }

  /**
   * 追加Provider Headers 列表，保留既有内容并写入新增片段。
   * @param result 返回结果。


   */
  private appendProviderHeaders(result: Array<ConnectionHeaderRecord>, apiType: string, secretValue: string): void {
    const normalized = apiType.toLowerCase();
    if (normalized === 'openrouter') {
      this.upsertHeader(result, 'HTTP-Referer', 'https://sillytavern.app', false);
      this.upsertHeader(result, 'X-Title', 'SillyTavern', false);
      this.appendBearerAuth(result, secretValue);
      return;
    }
    if (normalized === 'featherless') {
      this.upsertHeader(result, 'HTTP-Referer', 'https://sillytavern.app', false);
      this.upsertHeader(result, 'X-Title', 'SillyTavern', false);
      this.appendBearerAuth(result, secretValue);
      return;
    }
    if (normalized === 'mancer' || normalized === 'aphrodite') {
      if (secretValue.length > 0) {
        this.upsertHeader(result, 'X-API-KEY', secretValue, true);
      }
      this.appendBearerAuth(result, secretValue);
      return;
    }
    if (normalized === 'tabby') {
      if (secretValue.length > 0) {
        this.upsertHeader(result, 'x-api-key', secretValue, true);
      }
      this.appendBearerAuth(result, secretValue);
      return;
    }
    if (
      normalized === 'vllm'
      || normalized === 'togetherai'
      || normalized === 'infermaticai'
      || normalized === 'dreamgen'
      || normalized === 'ooba'
      || normalized === 'koboldcpp'
      || normalized === 'llamacpp'
      || normalized === 'huggingface'
      || normalized === 'generic'
    ) {
      this.appendBearerAuth(result, secretValue);
    }
  }

  /**
   * 追加Bearer Auth 值，保留既有内容并写入新增片段。
   * @param result 返回结果。

   */
  private appendBearerAuth(result: Array<ConnectionHeaderRecord>, secretValue: string): void {
    if (secretValue.length === 0) {
      return;
    }
    this.upsertHeader(result, 'Authorization', `Bearer ${secretValue}`, true);
  }

  /**
   * 追加Headers 列表，保留既有内容并写入新增片段。
   * @param result 返回结果。
   * @param headers 请求头列表。
   */
  private appendHeaders(
    result: Array<ConnectionHeaderRecord>,
    headers: Array<ConnectionHeaderRecord>,
    masked: boolean,
  ): void {
    for (let index = 0; index < headers.length; index += 1) {
      const value = masked && headers[index].secret ? 'redacted' : headers[index].value;
      this.upsertHeader(result, headers[index].name, value, headers[index].secret);
    }
  }

  /**
   * 追加Override Headers 列表，保留既有内容并写入新增片段。
   * @param result 返回结果。
   * @param serverUrl 服务地址。
   */
  private appendOverrideHeaders(result: Array<ConnectionHeaderRecord>, serverUrl: string): void {
    const host = this.extractHost(serverUrl);
    if (host.length === 0) {
      return;
    }
    for (let index = 0; index < this.overrideRules.length; index += 1) {
      if (this.matchesHost(this.overrideRules[index], host)) {
        this.appendHeaders(result, this.overrideRules[index].headers, false);
      }
    }
  }

  /**
   * 检查主机是否满足当前规则。
   * @param rule 待匹配的策略规则。
   * @param host 目标主机名。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  private matchesHost(rule: NetworkHeaderOverrideRule, host: string): boolean {
    const normalizedHost = host.toLowerCase();
    const normalizedHostname = this.extractHostname(normalizedHost);
    for (let index = 0; index < rule.hosts.length; index += 1) {
      const ruleHost = rule.hosts[index].toLowerCase();
      if (ruleHost === normalizedHost || ruleHost === normalizedHostname) {
        return true;
      }
    }
    return false;
  }

  /**
   * 解析或导入Hostname数据，转换为当前 SDK 可使用的结构。
   * @param host 目标主机名。
   */
  private extractHostname(host: string): string {
    const colonIndex = host.indexOf(':');
    if (colonIndex < 0) {
      return host;
    }
    return host.substring(0, colonIndex);
  }

  /**
   * 解析或导入主机数据，转换为当前 SDK 可使用的结构。
   * @param serverUrl 服务地址。
   */
  private extractHost(serverUrl: string): string {
    const schemeIndex = serverUrl.indexOf('://');
    if (schemeIndex < 0) {
      return '';
    }
    const remainder = serverUrl.substring(schemeIndex + 3);
    if (remainder.length === 0) {
      return '';
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
    return remainder.substring(0, endIndex).toLowerCase();
  }

  /**
   * 创建或写入Header，完成持久化后返回可供调用方使用的结果。
   * @param result 返回结果。
   * @param name 显示名称或注册名称。
   * @param value 要保存或比较的字段值。

   */
  private upsertHeader(result: Array<ConnectionHeaderRecord>, name: string, value: string, secret: boolean): void {
    for (let index = 0; index < result.length; index += 1) {
      if (result[index].name.toLowerCase() === name.toLowerCase()) {
        result[index] = {
          name: name,
          value: value,
          secret: secret,
        };
        return;
      }
    }
    result.push({
      name: name,
      value: value,
      secret: secret,
    });
  }

  /**
   * 读取Secret Value 值，并转换为运行时使用的数据结构。
   * @param secretRef 密钥引用。
   */
  private readSecretValue(secretRef: string): string {
    if (secretRef.length === 0) {
      return '';
    }
    const access: SecretAccessOptions = {
      requesterId: 'network-service',
      permissions: ['secret:read'],
    };
    return this.secrets.readSecret(secretRef, access);
  }

  /**
   * 复制Rules 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneRules(rules: Array<NetworkHeaderOverrideRule>): Array<NetworkHeaderOverrideRule> {
    const result = new Array<NetworkHeaderOverrideRule>();
    for (let index = 0; index < rules.length; index += 1) {
      result.push({
        hosts: rules[index].hosts.slice(),
        headers: this.cloneHeaders(rules[index].headers, false),
      });
    }
    return result;
  }

  /**
   * 复制Headers 列表，避免外部修改内部状态。
   * @param headers 请求头列表。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  private cloneHeaders(headers: Array<ConnectionHeaderRecord>, masked: boolean): Array<ConnectionHeaderRecord> {
    const result = new Array<ConnectionHeaderRecord>();
    for (let index = 0; index < headers.length; index += 1) {
      result.push({
        name: headers[index].name,
        value: masked && headers[index].secret ? 'redacted' : headers[index].value,
        secret: headers[index].secret,
      });
    }
    return result;
  }
}
