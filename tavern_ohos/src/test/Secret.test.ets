import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  SecretRuntime,
  type RuntimeEvent,
  type SecretAccessOptions,
  type SecretCreateParams,
  type SecretEventPayload,
  type SecretExportRecord,
  type SecretRecord,
  type SecretRotatedPayload,
  type SecretStateRecord,
} from '../../Index';

export default function secretUnitTest() {
  describe('secret runtime', () => {
    it('creates secret refs, masks state, and gates plaintext reads by permission', 0, () => {
      // 运行时实例。
      const runtime = new SecretRuntime(new EventBus());
      const created = runtime.createSecret(makeSecret('secret-1', 'openai', 'profile-1', 'sk-openai-secret'));
      const states: Array<SecretStateRecord> = runtime.listSecretStates('openai');
      const allowedValue = runtime.readSecret(created.secretRef, makeAccess(true));
      const deniedValue = runtime.readSecret(created.secretRef, makeAccess(false));
      const exported: Array<SecretExportRecord> = runtime.exportIndex();

      expect(created.secretRef).assertEqual('secret:openai:secret-1');
      expect(states.length).assertEqual(1);
      expect(states[0].maskedValue).assertEqual('*******ret');
      expect(allowedValue).assertEqual('sk-openai-secret');
      expect(deniedValue).assertEqual('');
      expect(exported[0].maskedValue).assertEqual('*******ret');
    });

    it('rotates active provider secrets and emits secret.rotated', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SecretRuntime(bus);
      const rotatedRefs = new Array<string>();
      bus.subscribe<SecretRotatedPayload>('secret.rotated', (event: RuntimeEvent<SecretRotatedPayload>) => {
        rotatedRefs.push(event.payload.secret.secretRef);
      });
      runtime.createSecret(makeSecret('secret-2', 'openai', 'profile-1', 'old-value'));
      const rotated: SecretRecord = runtime.rotateSecret('openai', 'profile', 'profile-1', 'secret-3', 'new-value', 'Rotated');

      expect(rotated.secretRef).assertEqual('secret:openai:secret-3');
      expect(runtime.readSecret('secret:openai:secret-2', makeAccess(true))).assertEqual('old-value');
      expect(runtime.readActiveSecret('openai', 'profile', 'profile-1', makeAccess(true))).assertEqual('new-value');
      expect(runtime.listSecretStates('openai')[0].active).assertFalse();
      expect(runtime.listSecretStates('openai')[1].active).assertTrue();
      expect(rotatedRefs.length).assertEqual(1);
      expect(rotatedRefs[0]).assertEqual('secret:openai:secret-3');
    });

    it('updates labels and deletes secrets without leaking values', 0, () => {
      // 运行时实例。
      const runtime = new SecretRuntime(new EventBus());
      const created = runtime.createSecret(makeSecret('secret-4', 'claude', 'profile-2', 'claude-key'));
      const updated = runtime.updateSecret(created.secretRef, 'Claude Key', true);

      runtime.deleteSecret(created.secretRef);

      expect(updated.label).assertEqual('Claude Key');
      expect(runtime.readSecret(created.secretRef, makeAccess(true))).assertEqual('');
      expect(runtime.listSecretStates('claude').length).assertEqual(0);
    });

    it('throws when deleting a missing secret', 0, () => {
      // 运行时实例。
      const runtime = new SecretRuntime(new EventBus());
      let thrown = false;
      try {
        runtime.deleteSecret('secret:missing:missing');
      } catch (error) {
        thrown = true;
      }
      expect(thrown).assertTrue();
    });

    it('rejects duplicate secret refs without overwriting existing values', 0, () => {
      // 运行时实例。
      const runtime = new SecretRuntime(new EventBus());
      const created = runtime.createSecret(makeSecret('secret-duplicate', 'openai', 'profile-dup', 'first-value'));
      let thrown = false;
      try {
        runtime.createSecret(makeSecret('secret-duplicate', 'openai', 'profile-dup', 'second-value'));
      } catch (error) {
        thrown = true;
      }

      expect(thrown).assertTrue();
      expect(runtime.readSecret(created.secretRef, makeAccess(true))).assertEqual('first-value');
    });

    it('does not expose internal secret records through returns or events', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SecretRuntime(bus);
      bus.subscribe<SecretEventPayload>('secret.created', (event: RuntimeEvent<SecretEventPayload>) => {
        event.payload.secret.label = 'event-mutated';
      });
      const created = runtime.createSecret(makeSecret('secret-copy', 'openai', 'profile-copy', 'secret-value'));
      created.label = 'external';
      expect(runtime.listSecretStates('openai')[0].label).assertEqual('openai');
      const updated = runtime.updateSecret(created.secretRef, 'Updated', true);
      updated.label = 'external-updated';
      expect(runtime.listSecretStates('openai')[0].label).assertEqual('Updated');
      const rotated = runtime.rotateSecret('openai', 'profile', 'profile-copy', 'secret-copy-2', 'new-value', 'Rotated');
      rotated.label = 'external-rotated';
      expect(runtime.listSecretStates('openai')[1].label).assertEqual('Rotated');
    });
  });
}

/**
 * 封装单元测试中的 makeSecret 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param providerId Provider 标识。
 * @param scopeId 作用域下的具体对象标识。
 * @param value 要保存或比较的字段值。
 */
function makeSecret(id: string, providerId: string, scopeId: string, value: string): SecretCreateParams {
  return {
    id: id,
    providerId: providerId,
    scope: 'profile',
    scopeId: scopeId,
    label: providerId,
    value: value,
    active: true,
  };
}

/**
 * 封装单元测试中的 makeAccess 步骤，供公开方法复用。

 * @returns 条件命中时返回 true，否则返回 false。
 */
function makeAccess(allowed: boolean): SecretAccessOptions {
  const permissions = new Array<string>();
  /**
   * 封装单元测试中的 if 步骤，供公开方法复用。
   */
  if (allowed) {
    permissions.push('secret:read');
  }
  return {
    requesterId: 'provider-runtime',
    permissions: permissions,
  };
}
