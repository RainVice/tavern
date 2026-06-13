import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  PermissionRuntime,
  type PermissionAuditRecord,
  type PermissionCheckedPayload,
  type PermissionCheckResult,
  type PermissionConsentPayload,
  type PermissionConsentRequest,
  type PermissionGrantedPayload,
  type PermissionGrantParams,
  type PermissionPolicyRecord,
  type RuntimeEvent,
} from '../../Index';

export default function permissionUnitTest() {
  describe('permission runtime', () => {
    it('grants plugin, command, tool, secret, storage, file, media, and network permissions with audit', 0, () => {
      const bus = new EventBus();
      const runtime = new PermissionRuntime(bus);
      const granted = new Array<string>();
      bus.subscribe<PermissionGrantedPayload>('permission.granted', (event: RuntimeEvent<PermissionGrantedPayload>) => {
        granted.push(`${event.payload.grant.subjectType}:${event.payload.grant.permission}`);
      });

      runtime.grant(makeGrant('plugin', 'plugin-a', 'network:https'));
      runtime.grant(makeGrant('command', 'cmd-a', 'command:execute'));
      runtime.grant(makeGrant('tool', 'tool-a', 'tool:call'));
      runtime.grant(makeGrant('secret', 'secret-a', 'secret:read'));
      runtime.grant(makeGrant('storage', 'store-a', 'storage:write'));
      runtime.grant(makeGrant('file', 'file-a', 'file:read'));
      runtime.grant(makeGrant('media', 'media-a', 'media:play'));
      const check: PermissionCheckResult = runtime.check('plugin', 'plugin-a', 'network:https', 'https://api.example.com');
      const denied: PermissionCheckResult = runtime.check('plugin', 'plugin-a', 'network:private', 'http://127.0.0.1');

      expect(check.allowed).assertTrue();
      expect(denied.allowed).assertFalse();
      expect(denied.reason).assertContain('permission');
      const audit: Array<PermissionAuditRecord> = runtime.listAudit();
      expect(granted.length).assertEqual(7);
      expect(audit.length).assertEqual(9);
    });

    it('handles user consent requests and resolved grants', 0, () => {
      const runtime = new PermissionRuntime(new EventBus());
      const request: PermissionConsentRequest = runtime.requestConsent('plugin', 'plugin-b', 'file:write', 'Write export file');
      const approved = runtime.resolveConsent(request.id, true);
      const deniedRequest = runtime.requestConsent('plugin', 'plugin-b', 'secret:read', 'Read provider key');
      const denied = runtime.resolveConsent(deniedRequest.id, false);

      expect(approved.resolved).assertTrue();
      expect(approved.approved).assertTrue();
      expect(runtime.check('plugin', 'plugin-b', 'file:write', 'exports/out.json').allowed).assertTrue();
      expect(denied.approved).assertFalse();
      expect(runtime.check('plugin', 'plugin-b', 'secret:read', 'secret://openai').allowed).assertFalse();
    });

    it('enforces network policy, file policy, dangerous API blocklist, timeout, and crash isolation', 0, () => {
      const runtime = new PermissionRuntime(new EventBus());
      runtime.grant(makeGrant('plugin', 'plugin-c', 'network:https'));
      runtime.addAllowedFileRoot('plugin', 'plugin-c', 'exports/');
      runtime.blockDangerousApi('eval');
      const timeout: PermissionPolicyRecord = runtime.setExecutionTimeout('plugin', 'plugin-c', 3000);

      const publicNetwork = runtime.checkNetworkAccess('plugin', 'plugin-c', 'https://api.example.com');
      const privateNetwork = runtime.checkNetworkAccess('plugin', 'plugin-c', 'http://192.168.0.2');
      const allowedFile = runtime.checkFileAccess('plugin', 'plugin-c', 'exports/data.json');
      const deniedFile = runtime.checkFileAccess('plugin', 'plugin-c', '../secret.txt');
      const blockedApi = runtime.checkDangerousApi('plugin', 'plugin-c', 'eval');
      runtime.recordPluginCrash('plugin-c');
      runtime.recordPluginCrash('plugin-c');
      runtime.recordPluginCrash('plugin-c');

      expect(timeout.value).assertEqual('3000');
      expect(publicNetwork.allowed).assertTrue();
      expect(privateNetwork.allowed).assertFalse();
      expect(allowedFile.allowed).assertTrue();
      expect(deniedFile.allowed).assertFalse();
      expect(blockedApi.allowed).assertFalse();
      expect(runtime.isPluginIsolated('plugin-c')).assertTrue();
    });

    it('matches allowed file roots on path boundaries', 0, () => {
      const runtime = new PermissionRuntime(new EventBus());
      runtime.addAllowedFileRoot('plugin', 'plugin-root', '/data/app');

      const exact = runtime.checkFileAccess('plugin', 'plugin-root', '/data/app');
      const child = runtime.checkFileAccess('plugin', 'plugin-root', '/data/app/file.txt');
      const sibling = runtime.checkFileAccess('plugin', 'plugin-root', '/data/app2/file.txt');

      expect(exact.allowed).assertTrue();
      expect(child.allowed).assertTrue();
      expect(sibling.allowed).assertFalse();
    });

    it('classifies private network checks by parsed host instead of full URL text', 0, () => {
      const runtime = new PermissionRuntime(new EventBus());
      runtime.grant(makeGrant('plugin', 'plugin-net', 'network:https'));
      runtime.grant(makeGrant('plugin', 'plugin-net', 'network:http'));

      const publicWithPrivateQuery = runtime.checkNetworkAccess(
        'plugin',
        'plugin-net',
        'https://api.example.com/path?next=http://127.0.0.1',
      );
      const ipv6Loopback = runtime.checkNetworkAccess('plugin', 'plugin-net', 'http://[::1]/status');
      const ulaIpv6 = runtime.checkNetworkAccess('plugin', 'plugin-net', 'http://[fd00::1]/status');
      const privateLikeHostname = runtime.checkNetworkAccess('plugin', 'plugin-net', 'https://10.0.0.1.example.com');

      expect(publicWithPrivateQuery.allowed).assertTrue();
      expect(publicWithPrivateQuery.permission).assertEqual('network:https');
      expect(ipv6Loopback.allowed).assertFalse();
      expect(ipv6Loopback.permission).assertEqual('network:private');
      expect(ulaIpv6.allowed).assertFalse();
      expect(ulaIpv6.permission).assertEqual('network:private');
      expect(privateLikeHostname.allowed).assertTrue();
      expect(privateLikeHostname.permission).assertEqual('network:https');
    });

    it('does not expose internal grants, consent requests, audits, policies, or check results', 0, () => {
      const bus = new EventBus();
      const runtime = new PermissionRuntime(bus);
      bus.subscribe<PermissionGrantedPayload>('permission.granted', (event: RuntimeEvent<PermissionGrantedPayload>) => {
        event.payload.grant.permission = 'event-mutated';
      });
      bus.subscribe<PermissionCheckedPayload>('permission.checked', (event: RuntimeEvent<PermissionCheckedPayload>) => {
        event.payload.result.allowed = false;
      });
      bus.subscribe<PermissionConsentPayload>('permission.consent.requested', (event: RuntimeEvent<PermissionConsentPayload>) => {
        event.payload.request.permission = 'event-mutated';
      });

      const grant = runtime.grant(makeGrant('plugin', 'plugin-copy', 'network:https'));
      grant.permission = 'return-mutated';
      const check = runtime.check('plugin', 'plugin-copy', 'network:https', 'https://api.example.com');
      check.allowed = false;

      const request = runtime.requestConsent('plugin', 'plugin-copy', 'file:write', 'Write export file');
      const requestId = request.id;
      request.permission = 'return-mutated';
      const approved = runtime.resolveConsent(requestId, true);
      approved.permission = 'return-mutated';

      const timeout = runtime.setExecutionTimeout('plugin', 'plugin-copy', 3000);
      timeout.value = '1';
      const policies = runtime.listPolicies('plugin', 'plugin-copy');
      policies[0].value = '2';
      const audit = runtime.listAudit();
      audit[0].reason = 'external';

      expect(runtime.check('plugin', 'plugin-copy', 'network:https', 'https://api.example.com').allowed).assertTrue();
      expect(runtime.check('plugin', 'plugin-copy', 'file:write', 'exports/out.json').allowed).assertTrue();
      expect(runtime.listPolicies('plugin', 'plugin-copy')[0].value).assertEqual('3000');
      expect(runtime.listAudit()[0].reason).assertEqual('granted');
    });
  });
}

function makeGrant(subjectType: string, subjectId: string, permission: string): PermissionGrantParams {
  return {
    subjectType: subjectType,
    subjectId: subjectId,
    permission: permission,
    scope: '',
    expiresAt: 0,
  };
}
