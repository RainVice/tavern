import { EventBus } from '../runtime/EventBus';
import type {
  SecretAccessOptions,
  SecretCreateParams,
  SecretDeletedPayload,
  SecretEventPayload,
  SecretExportRecord,
  SecretRecord,
  SecretRotatedPayload,
  SecretStateRecord,
  SecretValueRecord,
} from './SecretModels';

export class SecretRuntime {
  private events: EventBus;
  private records: Map<string, SecretRecord> = new Map<string, SecretRecord>();
  private values: Map<string, SecretValueRecord> = new Map<string, SecretValueRecord>();

  constructor(events: EventBus) {
    this.events = events;
  }

  createSecret(params: SecretCreateParams): SecretRecord {
    const now = Date.now();
    const secretRef = this.makeSecretRef(params.providerId, params.id);
    if (this.records.has(secretRef)) {
      throw new Error(`Secret already exists: ${secretRef}`);
    }
    if (params.active) {
      this.deactivateProviderScope(params.providerId, params.scope, params.scopeId);
    }
    const record: SecretRecord = {
      id: params.id,
      secretRef: secretRef,
      providerId: params.providerId,
      scope: params.scope,
      scopeId: params.scopeId,
      label: params.label,
      active: params.active,
      createdAt: now,
      updatedAt: now,
    };
    const valueRecord: SecretValueRecord = {
      secretRef: secretRef,
      value: params.value,
    };
    this.records.set(secretRef, this.cloneRecord(record));
    this.values.set(secretRef, valueRecord);
    this.publishSecretEvent('secret.created', record);
    return this.cloneRecord(record);
  }

  updateSecret(secretRef: string, label: string, active: boolean): SecretRecord {
    const record = this.requireRecord(secretRef);
    if (active) {
      this.deactivateProviderScope(record.providerId, record.scope, record.scopeId);
    }
    record.label = label;
    record.active = active;
    record.updatedAt = Date.now();
    this.publishSecretEvent('secret.updated', record);
    return this.cloneRecord(record);
  }

  deleteSecret(secretRef: string): void {
    const record = this.requireRecord(secretRef);
    this.records.delete(secretRef);
    this.values.delete(secretRef);
    const payload: SecretDeletedPayload = {
      secretRef: secretRef,
      providerId: record.providerId,
    };
    this.events.publish<SecretDeletedPayload>('secret.deleted', payload);
  }

  rotateSecret(
    providerId: string,
    scope: string,
    scopeId: string,
    id: string,
    value: string,
    label: string,
  ): SecretRecord {
    const previousSecretRef = this.findActiveSecretRef(providerId, scope, scopeId);
    const params: SecretCreateParams = {
      id: id,
      providerId: providerId,
      scope: scope,
      scopeId: scopeId,
      label: label,
      value: value,
      active: true,
    };
    const record = this.createSecret(params);
    const payload: SecretRotatedPayload = {
      secret: this.cloneRecord(record),
      previousSecretRef: previousSecretRef,
    };
    this.events.publish<SecretRotatedPayload>('secret.rotated', payload);
    return this.cloneRecord(record);
  }

  readSecret(secretRef: string, options: SecretAccessOptions): string {
    if (!this.canRead(options)) {
      return '';
    }
    const value = this.values.get(secretRef);
    if (value === undefined) {
      return '';
    }
    return value.value;
  }

  readActiveSecret(providerId: string, scope: string, scopeId: string, options: SecretAccessOptions): string {
    const secretRef = this.findActiveSecretRef(providerId, scope, scopeId);
    if (secretRef.length === 0) {
      return '';
    }
    return this.readSecret(secretRef, options);
  }

  listSecretStates(providerId: string): Array<SecretStateRecord> {
    const result = new Array<SecretStateRecord>();
    const records = Array.from(this.records.values());
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      if (providerId.length === 0 || record.providerId === providerId) {
        result.push(this.toState(record));
      }
    }
    return result;
  }

  exportIndex(): Array<SecretExportRecord> {
    const result = new Array<SecretExportRecord>();
    const records = Array.from(this.records.values());
    for (let index = 0; index < records.length; index += 1) {
      const state = this.toState(records[index]);
      const exported: SecretExportRecord = {
        id: state.id,
        secretRef: state.secretRef,
        providerId: state.providerId,
        scope: state.scope,
        scopeId: state.scopeId,
        label: state.label,
        maskedValue: state.maskedValue,
        active: state.active,
        updatedAt: state.updatedAt,
      };
      result.push(exported);
    }
    return result;
  }

  maskValue(value: string): string {
    const threshold = 10;
    const exposedChars = 3;
    if (value.length === 0) {
      return '';
    }
    if (value.length <= threshold) {
      return '**********';
    }
    const visibleEnd = value.substring(value.length - exposedChars);
    return `*******${visibleEnd}`;
  }

  private requireRecord(secretRef: string): SecretRecord {
    const record = this.records.get(secretRef);
    if (record === undefined) {
      throw new Error(`Secret not found: ${secretRef}`);
    }
    return record;
  }

  private canRead(options: SecretAccessOptions): boolean {
    for (let index = 0; index < options.permissions.length; index += 1) {
      if (options.permissions[index] === 'secret:read') {
        return true;
      }
    }
    return false;
  }

  private toState(record: SecretRecord): SecretStateRecord {
    const value = this.values.get(record.secretRef);
    const rawValue = value === undefined ? '' : value.value;
    const state: SecretStateRecord = {
      id: record.id,
      secretRef: record.secretRef,
      providerId: record.providerId,
      scope: record.scope,
      scopeId: record.scopeId,
      label: record.label,
      maskedValue: this.maskValue(rawValue),
      active: record.active,
      updatedAt: record.updatedAt,
    };
    return state;
  }

  private deactivateProviderScope(providerId: string, scope: string, scopeId: string): void {
    const records = Array.from(this.records.values());
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      if (record.providerId === providerId && record.scope === scope && record.scopeId === scopeId) {
        record.active = false;
        record.updatedAt = Date.now();
      }
    }
  }

  private findActiveSecretRef(providerId: string, scope: string, scopeId: string): string {
    const records = Array.from(this.records.values());
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      if (record.providerId === providerId && record.scope === scope && record.scopeId === scopeId && record.active) {
        return record.secretRef;
      }
    }
    return '';
  }

  private makeSecretRef(providerId: string, id: string): string {
    return `secret:${providerId}:${id}`;
  }

  private publishSecretEvent(eventName: string, secret: SecretRecord): void {
    const payload: SecretEventPayload = {
      secret: this.cloneRecord(secret),
    };
    this.events.publish<SecretEventPayload>(eventName, payload);
  }

  private cloneRecord(record: SecretRecord): SecretRecord {
    return {
      id: record.id,
      secretRef: record.secretRef,
      providerId: record.providerId,
      scope: record.scope,
      scopeId: record.scopeId,
      label: record.label,
      active: record.active,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }
}
