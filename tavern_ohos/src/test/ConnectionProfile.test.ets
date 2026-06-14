import { describe, it, expect } from '@ohos/hypium';
import {
  ConnectionApiTypes,
  ConnectionProfileRuntime,
  EventBus,
  InMemoryFileStore,
  ReasoningFormats,
  SecretRefs,
  TavernScopes,
  TokenizerStrategies,
  type ConnectionApiType,
  type ConnectionHeaderRecord,
  type ConnectionProfileCreateParams,
  type ConnectionProfileRecord,
  type ConnectionProfileUpdatedPayload,
  type ConnectionProviderRequest,
  type ConnectionResolvedProfile,
  type RuntimeEvent,
} from '../../Index';

export default function connectionProfileUnitTest() {
  describe('connection profile runtime', () => {
    it('creates, updates, lists, and deletes connection profiles', 0, () => {
      // 运行时实例。
      const runtime = new ConnectionProfileRuntime(new EventBus());
      const created = runtime.createProfile(makeProfile('profile-1', 'OpenAI', ConnectionApiTypes.OPENAI, 'gpt-4o'));
      const updated = runtime.updateProfile(
        created.id,
        makeProfile('profile-1', 'OpenAI Updated', ConnectionApiTypes.OPENAI, 'gpt-4.1'),
      );
      runtime.createProfile(makeProfile('profile-2', 'Claude', 'anthropic', 'claude-3-5'));
      const openaiProfiles: Array<ConnectionProfileRecord> = runtime.listProfiles(ConnectionApiTypes.OPENAI);
      const allProfiles: Array<ConnectionProfileRecord> = runtime.listProfiles('');

      expect(updated.name).assertEqual('OpenAI Updated');
      expect(runtime.getProfile('profile-1').model).assertEqual('gpt-4.1');
      expect(openaiProfiles.length).assertEqual(1);
      expect(allProfiles.length).assertEqual(2);
      runtime.deleteProfile('profile-1');
      expect(runtime.listProfiles(ConnectionApiTypes.OPENAI).length).assertEqual(0);
    });

    it('sets active profile by scope and resolves provider request metadata', 0, () => {
      // 运行时实例。
      const runtime = new ConnectionProfileRuntime(new EventBus());
      runtime.createProfile(makeProfile('profile-3', 'Chat Provider', ConnectionApiTypes.OPENAI_COMPATIBLE, 'local-model'));
      const active = runtime.setActiveProfile(TavernScopes.CHAT, 'chat-1', 'profile-3');
      const resolved: ConnectionResolvedProfile = runtime.resolveActiveProfile(TavernScopes.CHAT, 'chat-1');
      const request: ConnectionProviderRequest = runtime.toProviderRequest('profile-3');

      expect(active.profileId).assertEqual('profile-3');
      expect(resolved.profile.id).assertEqual('profile-3');
      expect(resolved.secretRef).assertEqual(SecretRefs.create('openai', 'secret-1'));
      expect(request.apiType).assertEqual(ConnectionApiTypes.OPENAI_COMPATIBLE);
      expect(request.model).assertEqual('local-model');
      expect(request.stopStrings.length).assertEqual(2);
      expect(request.generationPresetId).assertEqual('preset-generation');
      expect(request.additionalHeaders[0].value).assertEqual('redacted');
    });

    it('rejects duplicate profile ids during create', 0, () => {
      // 运行时实例。
      const runtime = new ConnectionProfileRuntime(new EventBus());
      runtime.createProfile(makeProfile('profile-duplicate', 'Original', ConnectionApiTypes.OPENAI, 'gpt-4o'));
      let thrown = false;

      try {
        runtime.createProfile(makeProfile('profile-duplicate', 'Replacement', ConnectionApiTypes.OPENAI, 'gpt-4.1'));
      } catch (error) {
        thrown = true;
      }

      expect(thrown).assertTrue();
      expect(runtime.getProfile('profile-duplicate').name).assertEqual('Original');
      expect(runtime.getProfile('profile-duplicate').model).assertEqual('gpt-4o');
    });

    it('emits profile update events', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ConnectionProfileRuntime(bus);
      const updatedIds = new Array<string>();
      bus.subscribe<ConnectionProfileUpdatedPayload>(
        'connectionProfile.updated',
        (event: RuntimeEvent<ConnectionProfileUpdatedPayload>) => {
          updatedIds.push(event.payload.profile.id);
        },
      );

      runtime.createProfile(makeProfile('profile-4', 'Event Profile', ConnectionApiTypes.OPENAI, 'gpt-4o'));
      runtime.updateProfile('profile-4', makeProfile('profile-4', 'Event Updated', ConnectionApiTypes.OPENAI, 'gpt-4o-mini'));

      expect(updatedIds.length).assertEqual(1);
      expect(updatedIds[0]).assertEqual('profile-4');
    });

    it('persists connection profiles and active bindings', 0, async () => {
      // 文件存储实例。
      const files = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new ConnectionProfileRuntime(new EventBus(), files, 'tavern-data', 'default');
      runtime.createProfile(makeProfile('profile-persist', 'Persistent OpenAI', ConnectionApiTypes.OPENAI, 'gpt-4.1'));
      runtime.setActiveProfile(TavernScopes.CHAT, 'chat-persist', 'profile-persist');
      await runtime.saveToStore();

      const restored = new ConnectionProfileRuntime(new EventBus(), files, 'tavern-data', 'default');
      await restored.loadFromStore();
      const request = restored.toProviderRequest('profile-persist');

      expect(await files.exists('tavern-data/users/default/connection-profiles/index.json')).assertTrue();
      expect(restored.resolveActiveProfile(TavernScopes.CHAT, 'chat-persist').profile.name).assertEqual('Persistent OpenAI');
      expect(request.additionalHeaders[0].value).assertEqual('redacted');
    });

    it('does not expose internal profiles or active bindings', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ConnectionProfileRuntime(bus);
      bus.subscribe<ConnectionProfileUpdatedPayload>(
        'connectionProfile.updated',
        (event: RuntimeEvent<ConnectionProfileUpdatedPayload>) => {
          event.payload.profile.model = 'event-mutated';
        },
      );
      const created = runtime.createProfile(makeProfile('profile-copy', 'Copy', ConnectionApiTypes.OPENAI, 'gpt-4o'));
      created.stopStrings.push('external-stop');
      created.additionalHeaders[0].value = 'external-header';
      expect(runtime.getProfile('profile-copy').stopStrings.length).assertEqual(2);
      expect(runtime.getProfile('profile-copy').additionalHeaders[0].value).assertEqual('should-not-leak');

      runtime.updateProfile('profile-copy', makeProfile('profile-copy', 'Copy Updated', ConnectionApiTypes.OPENAI, 'gpt-4.1'));
      expect(runtime.getProfile('profile-copy').model).assertEqual('gpt-4.1');
      const listed = runtime.listProfiles('');
      listed[0].model = 'list-mutated';
      const active = runtime.setActiveProfile(TavernScopes.CHAT, 'chat-copy', 'profile-copy');
      active.profileId = 'external-profile';
      const resolved = runtime.resolveActiveProfile(TavernScopes.CHAT, 'chat-copy');
      resolved.profile.model = 'resolved-mutated';
      resolved.binding.profileId = 'resolved-binding';

      expect(runtime.getProfile('profile-copy').model).assertEqual('gpt-4.1');
      expect(runtime.resolveActiveProfile(TavernScopes.CHAT, 'chat-copy').binding.profileId).assertEqual('profile-copy');

      { let thrown=false; try { runtime.deleteProfile('missing-profile'); } catch(e) { thrown=true; } expect(thrown).assertTrue(); };
    });
  });
}

/**
 * 封装单元测试中的 makeProfile 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param name 显示名称或注册名称。

 * @param model 模型名称。
 */
function makeProfile(id: string, name: string, apiType: ConnectionApiType, model: string): ConnectionProfileCreateParams {
  return {
    id: id,
    name: name,
    apiType: apiType,
    model: model,
    serverUrl: 'https://example.test/v1',
    secretRef: SecretRefs.create('openai', 'secret-1'),
    generationPresetId: 'preset-generation',
    systemPromptPresetId: 'preset-system',
    contextTemplateId: 'preset-context',
    instructTemplateId: 'preset-instruct',
    tokenizer: TokenizerStrategies.OPENAI,
    stopStrings: ['</s>', '<|end|>'],
    reasoningFormat: ReasoningFormats.TAGGED,
    toolCallingEnabled: true,
    proxyUrl: 'http://127.0.0.1:8080',
    additionalHeaders: [
      makeHeader('x-api-key', 'should-not-leak', true),
    ],
    enabled: true,
  };
}

/**
 * 封装单元测试中的 makeHeader 步骤，供公开方法复用。
 * @param name 显示名称或注册名称。
 * @param value 要保存或比较的字段值。

 * @returns 条件命中时返回 true，否则返回 false。
 */
function makeHeader(name: string, value: string, secret: boolean): ConnectionHeaderRecord {
  return {
    name: name,
    value: value,
    secret: secret,
  };
}
