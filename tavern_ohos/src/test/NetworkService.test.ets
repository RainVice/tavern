import { describe, it, expect } from '@ohos/hypium';
import {
  ConnectionProfileRuntime,
  EventBus,
  NetworkService,
  SecretRuntime,
  type ConnectionHeaderRecord,
  type ConnectionProfileCreateParams,
  type NetworkHeaderOverrideRule,
  type SecretCreateParams,
} from '../../Index';

export default function networkServiceUnitTest() {
  describe('network service', () => {
    it('resolves provider headers, static headers, and custom profile headers', 0, () => {
      const events = new EventBus();
      const connections = new ConnectionProfileRuntime(events);
      const secrets = new SecretRuntime(events);
      const service = new NetworkService(connections, secrets);
      const secret = secrets.createSecret(makeSecret('openrouter-secret', 'openrouter', 'profile-openrouter', 'sk-openrouter'));
      connections.createProfile(makeProfile(
        'profile-openrouter',
        'OpenRouter',
        'openrouter',
        secret.secretRef,
        [makeHeader('X-Custom', 'custom-value', false)],
      ));
      const headers = service.resolveHeadersForProfile('profile-openrouter');

      expect(findHeaderValue(headers, 'Authorization')).assertEqual('Bearer sk-openrouter');
      expect(findHeaderValue(headers, 'HTTP-Referer')).assertEqual('https://sillytavern.app');
      expect(findHeaderValue(headers, 'X-Title')).assertEqual('SillyTavern');
      expect(findHeaderValue(headers, 'X-Custom')).assertEqual('custom-value');
    });

    it('applies host override headers and masks secret values in preview', 0, () => {
      const events = new EventBus();
      const connections = new ConnectionProfileRuntime(events);
      const secrets = new SecretRuntime(events);
      const service = new NetworkService(connections, secrets);
      const secret = secrets.createSecret(makeSecret('mancer-secret', 'mancer', 'profile-mancer', 'sk-mancer'));
      connections.createProfile(makeProfile(
        'profile-mancer',
        'Mancer',
        'mancer',
        secret.secretRef,
        [makeHeader('X-Private', 'profile-secret', true)],
      ));
      const rules: Array<NetworkHeaderOverrideRule> = [
        {
          hosts: ['api.example.test'],
          headers: [makeHeader('X-Override', 'override-value', false)],
        },
      ];
      service.setOverrideHeaders(rules);
      const preview = service.previewHeadersForProfile('profile-mancer', 'https://api.example.test/v1');

      expect(findHeaderValue(preview, 'Authorization')).assertEqual('redacted');
      expect(findHeaderValue(preview, 'X-API-KEY')).assertEqual('redacted');
      expect(findHeaderValue(preview, 'X-Private')).assertEqual('redacted');
      expect(findHeaderValue(preview, 'X-Override')).assertEqual('override-value');
    });

    it('ignores invalid override urls and preserves exact header matching by host', 0, () => {
      const events = new EventBus();
      const connections = new ConnectionProfileRuntime(events);
      const secrets = new SecretRuntime(events);
      const service = new NetworkService(connections, secrets);
      connections.createProfile(makeProfile(
        'profile-generic',
        'Generic',
        'generic',
        '',
        [makeHeader('X-Plain', 'plain', false)],
      ));
      service.setOverrideHeaders([
        {
          hosts: ['good.example.test'],
          headers: [makeHeader('X-Scoped', 'scoped', false)],
        },
      ]);
      const invalidHeaders = service.resolveHeadersForProfile('profile-generic', 'not-a-url');
      const matchedHeaders = service.resolveHeadersForProfile('profile-generic', 'https://good.example.test/api');
      const portMatchedHeaders = service.resolveHeadersForProfile('profile-generic', 'https://good.example.test:8443/api');

      expect(findHeaderValue(invalidHeaders, 'X-Scoped')).assertEqual('');
      expect(findHeaderValue(matchedHeaders, 'X-Scoped')).assertEqual('scoped');
      expect(findHeaderValue(portMatchedHeaders, 'X-Scoped')).assertEqual('scoped');
      expect(findHeaderValue(matchedHeaders, 'X-Plain')).assertEqual('plain');
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
 * 封装单元测试中的 makeProfile 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param name 显示名称或注册名称。

 * @param secretRef 密钥引用。
 */
function makeProfile(
  id: string,
  name: string,
  apiType: string,
  secretRef: string,
  additionalHeaders: Array<ConnectionHeaderRecord>,
): ConnectionProfileCreateParams {
  return {
    id: id,
    name: name,
    apiType: apiType,
    model: 'test-model',
    serverUrl: 'https://provider.example.test/v1',
    secretRef: secretRef,
    generationPresetId: '',
    systemPromptPresetId: '',
    contextTemplateId: '',
    instructTemplateId: '',
    tokenizer: 'openai',
    stopStrings: new Array<string>(),
    reasoningFormat: '',
    toolCallingEnabled: true,
    proxyUrl: '',
    additionalHeaders: additionalHeaders,
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

/**
 * 在当前集合中查找Header Value 值，未命中时返回空值或默认位置。
 * @param headers 请求头列表。
 * @param name 显示名称或注册名称。
 * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
 */
function findHeaderValue(headers: Array<ConnectionHeaderRecord>, name: string): string {
  /**
   * 封装单元测试中的 for 步骤，供公开方法复用。
   */
  for (let index = 0; index < headers.length; index += 1) {
    if (headers[index].name === name) {
      return headers[index].value;
    }
  }
  return '';
}
