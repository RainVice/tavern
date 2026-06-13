import { EventBus } from '../runtime/EventBus';
import type {
  NetworkPolicyAllowedPayload,
  NetworkPolicyBlockedPayload,
  NetworkPolicyDecision,
  NetworkPolicyOptions,
} from './NetworkPolicyModels';

export class NetworkPolicyRuntime {
  private events: EventBus;
  private options: NetworkPolicyOptions;

  constructor(events: EventBus, options?: NetworkPolicyOptions) {
    this.events = events;
    this.options = this.mergeOptions(options);
  }

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

  private mergeOptions(options?: NetworkPolicyOptions): NetworkPolicyOptions {
    return {
      enabled: options?.enabled ?? true,
      whitelist: options?.whitelist === undefined ? new Array<string>() : options.whitelist.slice(),
      allowUnresolvedHosts: options?.allowUnresolvedHosts ?? false,
      logAllowed: options?.logAllowed ?? false,
      logBlocked: options?.logBlocked ?? false,
    };
  }

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

  private prefixMask(prefix: number): number {
    if (prefix === 0) {
      return 0;
    }
    return (0xffffffff << (32 - prefix)) >>> 0;
  }

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

  private isKnownAddressFamily(address: string): boolean {
    if (this.parseIpv4(address) !== -1) {
      return true;
    }
    return address.indexOf(':') >= 0;
  }

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

  private inIpv4Range(value: number, baseAddress: string, prefix: number): boolean {
    const base = this.parseIpv4(baseAddress);
    if (base === -1) {
      return false;
    }
    const mask = this.prefixMask(prefix);
    return (value & mask) === (base & mask);
  }

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
