import type {
  ConnectionHeaderRecord,
} from '../connection/ConnectionProfileModels';
import { ConnectionProfileRuntime } from '../connection/ConnectionProfileRuntime';
import type { SecretAccessOptions } from '../secret/SecretModels';
import { SecretRuntime } from '../secret/SecretRuntime';
import type { NetworkHeaderOverrideRule } from './NetworkModels';

/**
 * 提供网络请求头服务，封装跨 Runtime 的协作逻辑。
 * 调用方（如 API 客户端）在发起网络请求前通过此服务解析目标连接所需的完整请求头，
 * 包含 provider 特有的头、附加头、覆盖规则头，以及密钥注入和预览掩盖。
 */
export class NetworkService {
  /**
   * 连接配置运行时，用于读取 profile 的连接信息和 API 类型。
   * 在 resolveHeadersForProfile 中根据 profileId 获取连接配置，决定附加哪些 provider 特定头。
   */
  private connections: ConnectionProfileRuntime;
  /**
   * 密钥管理运行时，用于读取密钥值注入到请求头中。
   * 在 resolveHeadersForProfile 中根据 profile 的 secretRef 读取密钥值，用于 Bearer Token 等认证场景。
   */
  private secrets: SecretRuntime;
  /**
   * 按 host 匹配的请求头覆盖规则列表，由 setOverrideHeaders 设置。
   * 在 resolveHeadersForProfile 中根据服务器 URL 的 host 匹配规则，追加自定义请求头。
   */
  private overrideRules: Array<NetworkHeaderOverrideRule> = new Array<NetworkHeaderOverrideRule>();

  /**
   * 注入网络请求头运行时依赖并初始化实例状态。
   * 调用方在创建 NetworkService 时需传入已初始化的 ConnectionProfileRuntime 和 SecretRuntime，
   * 这两个运行时分别负责读取连接配置和密钥存储。
   */
  constructor(connections: ConnectionProfileRuntime, secrets: SecretRuntime) {
    this.connections = connections;
    this.secrets = secrets;
  }

  /**
   * 设置请求头覆盖规则列表，用于按 host 自动追加自定义请求头。
   * 调用方（如配置页面）在管理网络规则时使用此方法更新覆盖规则，后续 resolveHeaders 会应用新规则。
   * @param rules 请求头覆盖规则列表。
   */
  setOverrideHeaders(rules: Array<NetworkHeaderOverrideRule>): void {
    this.overrideRules = this.cloneRules(rules);
  }

  /**
   * 根据 profileId 和可选的 serverUrl 解析出该连接的实际请求头列表，包含 provider 特定头、附加头和覆盖规则头。
   * 调用方（如 API 客户端）在发起网络请求前调用此方法组装最终的请求头。
   * @param profileId 目标连接配置标识，用于从 ConnectionProfileRuntime 读取 profile 信息。
   * @param serverUrl 可选的服务地址，用于匹配覆盖规则。未传入时使用 profile 中的 serverUrl。
   * @returns 解析后的请求头列表副本。
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
   * 预览指定连接的请求头，与 resolveHeadersForProfile 的区别在于密钥值会被掩盖。
   * 调用方（如配置界面）在用户查看连接详情时使用此方法展示请求头预览，防止密钥明文泄露。
   * @param profileId 目标连接配置标识。
   * @param serverUrl 可选的服务地址，用于匹配覆盖规则。
   * @returns 预览用请求头列表副本（密钥值已掩盖）。
   */
  previewHeadersForProfile(profileId: string, serverUrl?: string): Array<ConnectionHeaderRecord> {
    const resolved = this.resolveHeadersForProfile(profileId, serverUrl);
    return this.cloneHeaders(resolved, true);
  }

  /**
   * 根据 API 类型追加 provider 特定的请求头（如 OpenRouter 的 HTTP-Referer、Mancer 的 X-API-KEY 等）。
   * 在 resolveHeadersForProfile 中根据 profile.apiType 自动调用，为不同 provider 注入必要的认证和标识头。
   * @param result 待填充的请求头列表。
   * @param apiType API 类型标识（如 openrouter、mancer 等），决定追加哪些特定请求头。
   * @param secretValue 从密钥存储读取的密钥值，用于各 provider 的认证头填充。
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
   * 向请求头列表中追加 Bearer Authentication 头（Authorization: Bearer <secretValue>）。
   * 在 appendProviderHeaders 中根据 API 类型自动调用，用于通用的 Bearer Token 认证方式。
   * @param result 待填充的请求头列表。
   * @param secretValue 密钥值，为空时不追加。
   */
  private appendBearerAuth(result: Array<ConnectionHeaderRecord>, secretValue: string): void {
    if (secretValue.length === 0) {
      return;
    }
    this.upsertHeader(result, 'Authorization', `Bearer ${secretValue}`, true);
  }

  /**
   * 将指定的请求头列表追加到 result 中，如果 masked 为 true 则掩盖 secret 头的值。
   * 在 resolveHeadersForProfile 和 appendOverrideHeaders 中分别用于合并用户附加头和覆盖规则头。
   * @param result 待填充的请求头列表。
   * @param headers 要追加的请求头列表。
   * @param masked 是否掩盖密钥值（用于预览模式）。
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
   * 从服务器 URL 中提取 host，并在覆盖规则列表中查找匹配项，追加命中规则的请求头。
   * 在 resolveHeadersForProfile 中调用，用于实现基于 host 的自定义请求头覆盖功能。
   * @param result 待填充的请求头列表。
   * @param serverUrl 服务地址，用于提取 host 进行规则匹��。
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
   * 判断 host 是否命中指定规则中的任意条目（支持精确匹配和无端口比对）。
   * 在 appendOverrideHeaders 中遍历规则时调用。
   * @param rule 请求头覆盖规则。
   * @param host 待匹配的 host 字符串。
   * @returns 命中任一规则条目时返回 true。
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
   * 从 host 字符串中提取主机名部分（去除端口号）。
   * 在 matchesHost 中用于去除端口后与规则 host 进行无端口比对。
   * @param host 带端口或不带端口的主机名。
   * @returns 纯主机名字符串。
   */
  private extractHostname(host: string): string {
    const colonIndex = host.indexOf(':');
    if (colonIndex < 0) {
      return host;
    }
    return host.substring(0, colonIndex);
  }

  /**
   * 从 serverUrl 中提取 host（域名/IP），去除协议、路径、查询参数和锚点。
   * 在 appendOverrideHeaders 中从服务器 URL 提取 host，用于覆盖规则的匹配判断。
   * @param serverUrl 完整的服务 URL。
   * @returns 提取后的 host，提取失败返回空字符串。
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
   * 创建或更新请求头。如果同名（忽略大小写）头已存在则替换，否则追加。
   * 在 appendProviderHeaders、appendHeaders、appendBearerAuth 中用于向结果列表写入单条请求头。
   * @param result 待操作的请求头列表。
   * @param name 请求头名称。
   * @param value 请求头值。
   * @param secret 是否为密钥字段，true 时在预览模式下会被掩盖。
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
   * 根据 secretRef 从密钥运行时中读取密钥值。
   * 在 resolveHeadersForProfile 中调用，用于获取认证所需的密钥值注入到请求头中。
   * @param secretRef 密钥引用标识。
   * @returns 解密后的密钥字符串，secretRef 为空时返回空字符串。
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
   * 深拷贝请求头覆盖规则列表，防止外部修改影响内部状态。
   * 在 setOverrideHeaders 中调用，确保外部传入的规则数组变更不会波及运行时的内部规则状态。
   * @returns 规则列表的深拷贝副本。
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
   * 深拷贝请求头列表，masked 为 true 时掩盖 secret 头的值（用于预览）。
   * 在 resolveHeadersForProfile、previewHeadersForProfile 以及 cloneRules 中调用。
   * @param headers 待拷贝的请求头列表。
   * @param masked 是否掩盖密钥值。
   * @returns 请求头列表的深拷贝副本。
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
