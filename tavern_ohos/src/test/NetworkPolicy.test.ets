import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  NetworkPolicyRuntime,
  type NetworkPolicyAllowedPayload,
  type NetworkPolicyBlockedPayload,
  type NetworkPolicyDecision,
  type RuntimeEvent,
} from '../../Index';

export default function networkPolicyUnitTest() {
  describe('network policy runtime', () => {
    it('blocks private addresses by default', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new NetworkPolicyRuntime(bus, {
        enabled: true,
        whitelist: new Array<string>(),
        allowUnresolvedHosts: false,
        logBlocked: true,
      });
      const blocked = new Array<string>();
      bus.subscribe<NetworkPolicyBlockedPayload>('network.request.blocked', (event: RuntimeEvent<NetworkPolicyBlockedPayload>) => {
        blocked.push(`${event.payload.host}:${event.payload.address}`);
      });
      const decision: NetworkPolicyDecision = runtime.evaluateHost('127.0.0.1', '127.0.0.1');

      expect(decision.allowed).assertFalse();
      expect(decision.reason).assertEqual('private-address');
      expect(blocked[0]).assertEqual('127.0.0.1:127.0.0.1');
    });

    it('allows public addresses and whitelisted private ranges', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new NetworkPolicyRuntime(bus, {
        enabled: true,
        whitelist: ['192.168.1.0/24', '10.0.0.8'],
        allowUnresolvedHosts: false,
        logAllowed: true,
      });
      const allowed = new Array<string>();
      bus.subscribe<NetworkPolicyAllowedPayload>('network.request.allowed', (event: RuntimeEvent<NetworkPolicyAllowedPayload>) => {
        allowed.push(`${event.payload.host}:${event.payload.address}:${event.payload.reason}`);
      });
      const publicDecision = runtime.evaluateHost('openai.com', '8.8.8.8');
      const privateDecision = runtime.evaluateHost('printer.local', '192.168.1.23');

      expect(publicDecision.allowed).assertTrue();
      expect(publicDecision.reason).assertEqual('public-address');
      expect(privateDecision.allowed).assertTrue();
      expect(privateDecision.reason).assertEqual('whitelisted-private-address');
      expect(allowed.length).assertEqual(2);
    });

    it('respects unresolved-host policy and disabled mode', 0, () => {
      const strictRuntime = new NetworkPolicyRuntime(new EventBus(), {
        enabled: true,
        whitelist: new Array<string>(),
        allowUnresolvedHosts: false,
      });
      const relaxedRuntime = new NetworkPolicyRuntime(new EventBus(), {
        enabled: false,
        whitelist: new Array<string>(),
        allowUnresolvedHosts: true,
      });
      const unresolved = strictRuntime.evaluateHost('missing.internal', '');
      const disabled = relaxedRuntime.evaluateHost('127.0.0.1', '127.0.0.1');

      expect(unresolved.allowed).assertFalse();
      expect(unresolved.reason).assertEqual('unresolved-host');
      expect(disabled.allowed).assertTrue();
      expect(disabled.reason).assertEqual('disabled');
    });

    it('does not keep caller-owned whitelist arrays', 0, () => {
      const whitelist = ['10.0.0.8'];
      // 运行时实例。
      const runtime = new NetworkPolicyRuntime(new EventBus(), {
        enabled: true,
        whitelist: whitelist,
        allowUnresolvedHosts: false,
      });
      whitelist.push('192.168.1.0/24');
      const original = runtime.evaluateHost('api.local', '10.0.0.8');
      const mutated = runtime.evaluateHost('printer.local', '192.168.1.23');

      expect(original.allowed).assertTrue();
      expect(mutated.allowed).assertFalse();
    });

    it('rejects malformed IPv4 addresses and CIDR rules instead of partially parsing them', 0, () => {
      // 运行时实例。
      const runtime = new NetworkPolicyRuntime(new EventBus(), {
        enabled: true,
        whitelist: ['192.168.1.0/24x', '10.0.0.8x'],
        allowUnresolvedHosts: false,
      });
      const malformedAddress = runtime.evaluateHost('printer.local', '192.168.1.23x');
      const malformedCidr = runtime.evaluateHost('printer.local', '192.168.1.23');
      const malformedExact = runtime.evaluateHost('api.local', '10.0.0.8');

      expect(malformedAddress.allowed).assertFalse();
      expect(malformedAddress.reason).assertEqual('invalid-address');
      expect(malformedCidr.allowed).assertFalse();
      expect(malformedCidr.reason).assertEqual('private-address');
      expect(malformedExact.allowed).assertFalse();
      expect(malformedExact.reason).assertEqual('private-address');
    });

    it('publishes policy events only when logging is enabled', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new NetworkPolicyRuntime(bus, {
        enabled: true,
        whitelist: new Array<string>(),
        allowUnresolvedHosts: false,
      });
      const allowed = new Array<string>();
      const blocked = new Array<string>();
      bus.subscribe<NetworkPolicyAllowedPayload>('network.request.allowed', (event: RuntimeEvent<NetworkPolicyAllowedPayload>) => {
        allowed.push(event.payload.host);
      });
      bus.subscribe<NetworkPolicyBlockedPayload>('network.request.blocked', (event: RuntimeEvent<NetworkPolicyBlockedPayload>) => {
        blocked.push(event.payload.host);
      });

      runtime.evaluateHost('openai.com', '8.8.8.8');
      runtime.evaluateHost('127.0.0.1', '127.0.0.1');

      expect(allowed.length).assertEqual(0);
      expect(blocked.length).assertEqual(0);
    });
  });
}
