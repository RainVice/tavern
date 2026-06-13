import type {
  ConnectionHeaderRecord,
} from '../connection/ConnectionProfileModels';
import { ConnectionProfileRuntime } from '../connection/ConnectionProfileRuntime';
import type { SecretAccessOptions } from '../secret/SecretModels';
import { SecretRuntime } from '../secret/SecretRuntime';
import type { NetworkHeaderOverrideRule } from './NetworkModels';

export class NetworkService {
  private connections: ConnectionProfileRuntime;
  private secrets: SecretRuntime;
  private overrideRules: Array<NetworkHeaderOverrideRule> = new Array<NetworkHeaderOverrideRule>();

  constructor(connections: ConnectionProfileRuntime, secrets: SecretRuntime) {
    this.connections = connections;
    this.secrets = secrets;
  }

  setOverrideHeaders(rules: Array<NetworkHeaderOverrideRule>): void {
    this.overrideRules = this.cloneRules(rules);
  }

  resolveHeadersForProfile(profileId: string, serverUrl?: string): Array<ConnectionHeaderRecord> {
    const profile = this.connections.getProfile(profileId);
    const result = new Array<ConnectionHeaderRecord>();
    const secretValue = this.readSecretValue(profile.secretRef);
    this.appendProviderHeaders(result, profile.apiType, secretValue);
    this.appendHeaders(result, profile.additionalHeaders, false);
    this.appendOverrideHeaders(result, serverUrl ?? profile.serverUrl);
    return this.cloneHeaders(result, false);
  }

  previewHeadersForProfile(profileId: string, serverUrl?: string): Array<ConnectionHeaderRecord> {
    const resolved = this.resolveHeadersForProfile(profileId, serverUrl);
    return this.cloneHeaders(resolved, true);
  }

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

  private appendBearerAuth(result: Array<ConnectionHeaderRecord>, secretValue: string): void {
    if (secretValue.length === 0) {
      return;
    }
    this.upsertHeader(result, 'Authorization', `Bearer ${secretValue}`, true);
  }

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

  private extractHostname(host: string): string {
    const colonIndex = host.indexOf(':');
    if (colonIndex < 0) {
      return host;
    }
    return host.substring(0, colonIndex);
  }

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
