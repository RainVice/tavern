import { EventBus } from '../runtime/EventBus';
import type {
  NetworkPolicyAllowedPayload,
  NetworkPolicyBlockedPayload,
  NetworkPolicyDecision,
  NetworkPolicyOptions,
} from './NetworkPolicyModels';

/**
 * 提供网络策略相关的无 UI 运行时能力，负责 DNS 级别的网络请求策略评估、白名单匹配及事件发布。
 * 调用方（如 HTTP 客户端）在发起网络请求前通过此运行时判决请求是否允许访问目标主机。
 */
export class NetworkPolicyRuntime {
  /**
   * 事件总线，用于在策略判决后按配置发布允许或阻断事件，通知监听方（如 UI、日志系统）。
   */
  private events: EventBus;
  /**
   * 配置选项，包含策略开关、白名单列表和日志开关。
   * 由构造函数初始化，在 evaluateHost 中用于控制判决逻辑。
   */
  private options: NetworkPolicyOptions;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例，用于后续策略事件发布。
   * @param options 网络策略配置选项，未传入时使用默认配置（启用、白名单为空、允许未解析主机为 false）。
   */
  constructor(events: EventBus, options?: NetworkPolicyOptions) {
    this.events = events;
    this.options = this.mergeOptions(options);
  }

  /**
   * 根据网络策略判断目标主机地址是否允许访问，并按配置发布允许或阻断事件。
   * 调用方（如 HTTP 客户端）在每次网络请求的 DNS 解析阶段调用此方法，根据返回的
   * NetworkPolicyDecision 决定是否放行该请求。
   * @param host 目标主机名，由 HTTP 客户端传入。
   * @param address 解析后的 IP 地址，由 DNS 解析结果提供，空字符串表示解析失败。
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
   * 在构造函数中调用，确保 options 的 whitelist 数组不被外部修改影响。
   * @param options 可选的网络策略配置，不传入时使用默认值。
   * @returns 合并后的配置对象。
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
   * 发布允许访问决策并返回 NetworkPolicyDecision，按配置选择是否发布事件。
   * 在 evaluateHost 的各种允许分支中调用，统一构建允许判决结果。
   * @param host 目标主机名。
   * @param address 解析后的 IP 地址。
   * @param reason 允许的原因描述。
   * @param matchedRule 命中的白名单或策略规则。
   * @returns 网络策略判决结果。
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
   * 发布拦截决策并返回 NetworkPolicyDecision，按配置选择是否发布事件。
   * 在 evaluateHost 的各种阻断分支中调用，统一构建阻断判决结果。
   * @param host 目标主机名。
   * @param address 解析后的 IP 地址。
   * @param reason 拦截的原因描述。
   * @param matchedRule 命中的策略规则。
   * @returns 网络策略判决结果。
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
   * 在 evaluateHost 中识别到私有地址后调用，支持精确匹配和 CIDR 匹配。
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
   * 判断 IPv4 地址是否命中指定 CIDR 子网规则（如 10.0.0.0/8）。
   * 在 matchWhitelist 中用于白名单条目的 CIDR 比对。
   * @param address 待判断的 IPv4 地址字符串。
   * @param rule CIDR 规则字符串。
   * @returns 地址在 CIDR 范围内返回 true。
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
   * 在 matchesCidr 中用于解析 CIDR 规则中的前缀长度部分。
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
   * 在 matchesCidr 和 inIpv4Range 中根据前缀长度计算子网掩码数值。
   * @param prefix CIDR 前缀长度。
   */
  private prefixMask(prefix: number): number {
    if (prefix === 0) {
      return 0;
    }
    return (0xffffffff << (32 - prefix)) >>> 0;
  }

  /**
   * 判断地址是否属于私网、环回或链路本地地址（IPv4/IPv6）。
   * 在 evaluateHost 中用于识别私有地址以触发白名单匹配或阻断。
   * @param address 解析后的 IP 地址字符串。
   * @returns 是私网或特殊用途地址时返回 true。
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
   * 判断地址是否为当前网络策略能识别的地址族（IPv4 或 IPv6）。
   * 在 evaluateHost 中作为前置校验，跳过无法识别的地址格式。
   * @param address 解析后的 IP 地址字符串。
   * @returns 能被识别时返回 true。
   */
  private isKnownAddressFamily(address: string): boolean {
    if (this.parseIpv4(address) !== -1) {
      return true;
    }
    return address.indexOf(':') >= 0;
  }

  /**
   * 判断 IPv6 地址是否属于本地、私有或链路本地范围（fc00::/7, fe80::/10, ::1）。
   * 在 isPrivateAddress 中用于 IPv6 地址的私有性检查。
   * @param address 解析后的 IP 地址字符串（IPv6）。
   * @returns 是私有 IPv6 地址时返回 true。
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
   * 判断 IPv4 数值是否落在指定 CIDR 地址段内。
   * 在 isPrivateAddress 中用于各私网段的比对。
   * @param value 已转换成数值的 IPv4 地址。
   * @param baseAddress CIDR 基准地址字符串（如 10.0.0.0）。
   * @param prefix CIDR 前缀长度。
   * @returns 在范围内返回 true。
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
   * 解析 IPv4 点分十进制字符串为数值，非法输入返回 -1。
   * 在 matchesCidr、isPrivateAddress、inIpv4Range 中用于将 IP 字符串转为数值比对。
   * @param address IPv4 地址字符串（如 192.168.1.1）。
   * @returns 数值形式的 IPv4 地址，解析失败返回 -1。
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
   * 判断字符串是否只包含十进制数字（0-9）。
   * 在 parseIpv4 和 parsePrefix 中用于确保输入为合规数字串。
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
}
