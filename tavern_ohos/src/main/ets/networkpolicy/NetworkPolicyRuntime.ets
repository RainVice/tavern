import { EventBus } from '../runtime/EventBus';
import type {
  NetworkPolicyAllowedPayload,
  NetworkPolicyBlockedPayload,
  NetworkPolicyDecision,
  NetworkPolicyOptions,
} from './NetworkPolicyModels';

/**
 * 提供网络策略相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class NetworkPolicyRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 配置选项。
   */
  private options: NetworkPolicyOptions;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   * @param options 配置选项。
   */
  constructor(events: EventBus, options?: NetworkPolicyOptions) {
    this.events = events;
    this.options = this.mergeOptions(options);
  }

  /**
   * 根据网络策略判断目标主机地址是否允许访问，并按配置发布允许或阻断事件。
   * @param host 目标主机名。
   * @param address 解析后的 IP 地址。
   * @returns 包含是否放行、决策原因及命中规则的评估结果。
   */
  evaluateHost(host: string, address: string): NetworkPolicyDecision {
    if (!this.options.enabled) {
      return this.publishAllowed(host, address, 'disabled', 'disabled');
    }

    if (address.length === 0) {
      if (this.options.allowUnresolvedHosts) {
        return this.publishAllowed(host, address, 'unresolved-host', 'allow-unresolved-host');
      }
      return this.publishBlocked(host, address, 'unresolved-host', 'block-unresolved-host');
    }

    if (!this.isKnownAddressFamily(address)) {
      return this.publishBlocked(host, address, 'invalid-address', 'invalid-address');
    }

    if (!this.isPrivateAddress(address)) {
      return this.publishAllowed(host, address, 'public-address', 'public-address');
    }
    const matchedRule = this.matchWhitelist(address);
    if (matchedRule.length > 0) {
      return this.publishAllowed(host, address, 'whitelisted-private-address', matchedRule);
    }

    return this.publishBlocked(host, address, 'private-address', 'private-address');
  }

  /**
   * 合并调用方配置和默认配置，避免外部数组被运行时直接持有。
   * @param options 可选的用户配置，缺失字段将回退为默认值。
   */
  private mergeOptions(options?: NetworkPolicyOptions): NetworkPolicyOptions {
    return {
      enabled: options?.enabled ?? true,
      whitelist: options?.whitelist === undefined ? new Array<string>() : options.whitelist.slice(),
      allowUnresolvedHosts: options?.allowUnresolvedHosts ?? false,
      logAllowed: options?.logAllowed ?? false,
      logBlocked: options?.logBlocked ?? false,
    };
  }

  /**
   * 构造允许决策并可选地在事件总线上发布 {@link NetworkPolicyAllowedPayload} 事件。
   * @param host 目标主机名。
   * @param address 解析后的 IP 地址。
   * @param reason 放行的策略原因标识（如 "disabled"、"public-address" 等）。
   * @param matchedRule 命中的白名单规则，无规则命中时传空字符串或标识码。
   */
  private publishAllowed(host: string, address: string, reason: string, matchedRule: string): NetworkPolicyDecision {
    const decision: NetworkPolicyDecision = {
      host: host,
      address: address,
      allowed: true,
      reason: reason,
      matchedRule: matchedRule,
    };
    const payload: NetworkPolicyAllowedPayload = {
      host: host,
      address: address,
      reason: reason,
      matchedRule: matchedRule,
    };
    if (this.options.logAllowed) {
      this.events.publish<NetworkPolicyAllowedPayload>('network.request.allowed', payload);
    }
    return decision;
  }

  /**
   * 构造阻断决策并可选地在事件总线上发布 {@link NetworkPolicyBlockedPayload} 事件。
   * @param host 目标主机名。
   * @param address 解析后的 IP 地址。
   * @param reason 阻断的策略原因标识（如 "private-address"、"block-unresolved-host" 等）。
   * @param matchedRule 命中的白名单规则，无规则命中时传空字符串或标识码。
   */
  private publishBlocked(host: string, address: string, reason: string, matchedRule: string): NetworkPolicyDecision {
    const decision: NetworkPolicyDecision = {
      host: host,
      address: address,
      allowed: false,
      reason: reason,
      matchedRule: matchedRule,
    };
    const payload: NetworkPolicyBlockedPayload = {
      host: host,
      address: address,
      reason: reason,
      matchedRule: matchedRule,
    };
    if (this.options.logBlocked) {
      this.events.publish<NetworkPolicyBlockedPayload>('network.request.blocked', payload);
    }
    return decision;
  }

  /**
   * 在白名单中查找能匹配当前地址的规则，找不到时返回空字符串。
   * @param address 解析后的 IP 地址。
   */
  private matchWhitelist(address: string): string {
    for (let index = 0; index < this.options.whitelist.length; index += 1) {
      const rule = this.options.whitelist[index].trim();
      if (rule.length === 0) {
        continue;
      }
      if (rule === address) {
        return rule;
      }
      if (this.matchesCidr(address, rule)) {
        return rule;
      }
    }
    return '';
  }

  /**
   * 判断 IPv4 地址是否命中指定 CIDR 规则。
   * @param address 解析后的 IP 地址。
   * @param rule 待匹配的策略规则。
   * @returns 地址匹配指定 CIDR 规则时返回 true。
   */
  private matchesCidr(address: string, rule: string): boolean {
    if (rule.indexOf('/') < 0) {
      return false;
    }
    const parts = rule.split('/');
    if (parts.length !== 2) {
      return false;
    }
    const base = this.parseIpv4(parts[0]);
    if (base === -1) {
      return false;
    }
    const value = this.parseIpv4(address);
    if (value === -1) {
      return false;
    }
    const prefix = this.parsePrefix(parts[1]);
    if (prefix === -1) {
      return false;
    }
    const mask = this.prefixMask(prefix);
    return (value & mask) === (base & mask);
  }

  /**
   * 解析 CIDR 前缀长度，非法或越界时返回 -1。
   * @param value 待解析的前缀长度字符串。
   */
  private parsePrefix(value: string): number {
    if (!this.isDecimalDigits(value)) {
      return -1;
    }
    const parsed = Number.parseInt(value, 10);
    if (Number.isNaN(parsed) || parsed < 0 || parsed > 32) {
      return -1;
    }
    return parsed;
  }

  /**
   * 根据 CIDR 前缀长度生成 IPv4 掩码。
   * @param prefix CIDR 前缀长度。
   */
  private prefixMask(prefix: number): number {
    if (prefix === 0) {
      return 0;
    }
    return (0xffffffff << (32 - prefix)) >>> 0;
  }

  /**
   * 判断地址是否属于私网、环回或链路本地地址。
   * @param address 解析后的 IP 地址。
   * @returns 地址属于私网、环回或链路本地范围时返回 true。
   */
  private isPrivateAddress(address: string): boolean {
    if (this.isPrivateIpv6(address)) {
      return true;
    }
    const value = this.parseIpv4(address);
    if (value === -1) {
      return false;
    }
    return this.inIpv4Range(value, '127.0.0.0', 8)
      || this.inIpv4Range(value, '10.0.0.0', 8)
      || this.inIpv4Range(value, '172.16.0.0', 12)
      || this.inIpv4Range(value, '192.168.0.0', 16)
      || this.inIpv4Range(value, '169.254.0.0', 16);
  }

  /**
   * 判断地址是否属于当前策略能够识别的地址族。
   * @param address 解析后的 IP 地址。
   * @returns 地址属于当前策略可识别的地址族（IPv4 或含冒号的地址）时返回 true。
   */
  private isKnownAddressFamily(address: string): boolean {
    if (this.parseIpv4(address) !== -1) {
      return true;
    }
    return address.indexOf(':') >= 0;
  }

  /**
   * 判断 IPv6 地址是否属于本地、私有或链路本地范围。
   * @param address 解析后的 IP 地址。
   * @returns 地址属于本地/私有/链路本地 IPv6 范围时返回 true。
   */
  private isPrivateIpv6(address: string): boolean {
    const normalized = address.toLowerCase();
    return normalized === '::1'
      || normalized.startsWith('fc')
      || normalized.startsWith('fd')
      || normalized.startsWith('fe8')
      || normalized.startsWith('fe9')
      || normalized.startsWith('fea')
      || normalized.startsWith('feb');
  }

  /**
   * 判断 IPv4 地址是否落在指定地址段内。
   * @param value 已转换成数值的 IPv4 地址。
   * @param baseAddress CIDR 或地址段的基准地址。
   * @param prefix CIDR 前缀长度。
   * @returns 地址落在指定 CIDR 地址段内时返回 true。
   */
  private inIpv4Range(value: number, baseAddress: string, prefix: number): boolean {
    const base = this.parseIpv4(baseAddress);
    if (base === -1) {
      return false;
    }
    const mask = this.prefixMask(prefix);
    return (value & mask) === (base & mask);
  }

  /**
   * 解析 IPv4 地址，非法输入返回 -1。
   * @param address 解析后的 IP 地址。
   */
  private parseIpv4(address: string): number {
    const parts = address.split('.');
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
    return value >>> 0;
  }

  /**
   * 判断字符串是否只包含十进制数字。
   * @param value 待检查的字符串。
   * @returns 字符串仅由十进制数字组成时返回 true。
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
}
