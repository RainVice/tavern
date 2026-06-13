import { EventBus } from '../runtime/EventBus';
import type {
  SettingChangedPayload,
  SettingEntry,
  SettingMigrationRecord,
  SettingSchemaCreateParams,
  SettingSchemaRecord,
  SettingSnapshot,
} from './SettingsModels';

export class SettingsRuntime {
  private events: EventBus;
  private schemas: Map<string, SettingSchemaRecord> = new Map<string, SettingSchemaRecord>();
  private entries: Map<string, SettingEntry> = new Map<string, SettingEntry>();
  private migrations: Array<SettingMigrationRecord> = new Array<SettingMigrationRecord>();

  constructor(events: EventBus) {
    this.events = events;
  }

  registerSchema(params: SettingSchemaCreateParams): SettingSchemaRecord {
    const schema: SettingSchemaRecord = {
      key: params.key,
      defaultValue: params.defaultValue,
      valueType: params.valueType,
      schemaVersion: params.schemaVersion,
      description: params.description,
    };
    this.schemas.set(schema.key, this.cloneSchema(schema));
    return this.cloneSchema(schema);
  }

  setSetting(scope: string, scopeId: string, key: string, value: string): SettingEntry {
    const schema = this.requireSchema(key);
    const oldValue = this.getSetting(scope, scopeId, key);
    const entry: SettingEntry = {
      scope: scope,
      scopeId: scopeId,
      key: key,
      value: value,
      schemaVersion: schema.schemaVersion,
      updatedAt: Date.now(),
    };
    this.entries.set(this.entryKey(scope, scopeId, key), this.cloneEntry(entry));
    const payload: SettingChangedPayload = {
      scope: scope,
      scopeId: scopeId,
      key: key,
      oldValue: oldValue,
      newValue: value,
      schemaVersion: schema.schemaVersion,
    };
    this.events.publish<SettingChangedPayload>('settings.changed', payload);
    return this.cloneEntry(entry);
  }

  getSetting(scope: string, scopeId: string, key: string): string {
    const entry = this.entries.get(this.entryKey(scope, scopeId, key));
    if (entry !== undefined) {
      return entry.value;
    }
    const schema = this.schemas.get(key);
    if (schema !== undefined) {
      return schema.defaultValue;
    }
    return '';
  }

  getEffectiveSetting(scope: string, scopeId: string, key: string): string {
    const scoped = this.entries.get(this.entryKey(scope, scopeId, key));
    if (scoped !== undefined) {
      return scoped.value;
    }
    if (scope !== 'global') {
      const global = this.entries.get(this.entryKey('global', '', key));
      if (global !== undefined) {
        return global.value;
      }
    }
    return this.getSetting(scope, scopeId, key);
  }

  migrateSetting(scope: string, scopeId: string, fromKey: string, toKey: string, targetVersion: number): SettingSnapshot {
    const fromSchema = this.requireSchema(fromKey);
    const toSchema = this.requireSchema(toKey);
    const sourceKey = this.entryKey(scope, scopeId, fromKey);
    const source = this.entries.get(sourceKey);
    const value = source === undefined ? fromSchema.defaultValue : source.value;
    if (source !== undefined) {
      this.entries.delete(sourceKey);
    }
    const entry: SettingEntry = {
      scope: scope,
      scopeId: scopeId,
      key: toKey,
      value: value,
      schemaVersion: targetVersion,
      updatedAt: Date.now(),
    };
    this.entries.set(this.entryKey(scope, scopeId, toKey), this.cloneEntry(entry));
    const migration: SettingMigrationRecord = {
      scope: scope,
      scopeId: scopeId,
      fromKey: fromKey,
      toKey: toKey,
      fromVersion: fromSchema.schemaVersion,
      toVersion: targetVersion > toSchema.schemaVersion ? targetVersion : toSchema.schemaVersion,
      migratedAt: Date.now(),
    };
    this.migrations.push(migration);
    return this.snapshot();
  }

  snapshot(): SettingSnapshot {
    const entries = this.cloneEntries(Array.from(this.entries.values()));
    const maxVersion = this.maxSchemaVersion(entries);
    const snapshot: SettingSnapshot = {
      schemaVersion: maxVersion,
      entries: this.cloneEntries(entries),
      migrationMetadata: this.cloneMigrations(this.migrations),
    };
    return snapshot;
  }

  listSchemas(): Array<SettingSchemaRecord> {
    const result = new Array<SettingSchemaRecord>();
    const schemas = Array.from(this.schemas.values());
    for (let index = 0; index < schemas.length; index += 1) {
      result.push(this.cloneSchema(schemas[index]));
    }
    return result;
  }

  listEntries(scope: string, scopeId: string): Array<SettingEntry> {
    const result = new Array<SettingEntry>();
    const entries = Array.from(this.entries.values());
    for (let index = 0; index < entries.length; index += 1) {
      const entry = entries[index];
      if (entry.scope === scope && entry.scopeId === scopeId) {
        result.push(this.cloneEntry(entry));
      }
    }
    return result;
  }

  private requireSchema(key: string): SettingSchemaRecord {
    const schema = this.schemas.get(key);
    if (schema === undefined) {
      throw new Error(`Setting schema not found: ${key}`);
    }
    return schema;
  }

  private maxSchemaVersion(entries: Array<SettingEntry>): number {
    let version = 0;
    const schemas = Array.from(this.schemas.values());
    for (let index = 0; index < schemas.length; index += 1) {
      if (schemas[index].schemaVersion > version) {
        version = schemas[index].schemaVersion;
      }
    }
    for (let index = 0; index < entries.length; index += 1) {
      if (entries[index].schemaVersion > version) {
        version = entries[index].schemaVersion;
      }
    }
    return version;
  }

  private entryKey(scope: string, scopeId: string, key: string): string {
    return `${scope}:${scopeId}:${key}`;
  }

  private cloneSchema(schema: SettingSchemaRecord): SettingSchemaRecord {
    return {
      key: schema.key,
      defaultValue: schema.defaultValue,
      valueType: schema.valueType,
      schemaVersion: schema.schemaVersion,
      description: schema.description,
    };
  }

  private cloneEntry(entry: SettingEntry): SettingEntry {
    return {
      scope: entry.scope,
      scopeId: entry.scopeId,
      key: entry.key,
      value: entry.value,
      schemaVersion: entry.schemaVersion,
      updatedAt: entry.updatedAt,
    };
  }

  private cloneEntries(entries: Array<SettingEntry>): Array<SettingEntry> {
    const result = new Array<SettingEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      result.push(this.cloneEntry(entries[index]));
    }
    return result;
  }

  private cloneMigration(migration: SettingMigrationRecord): SettingMigrationRecord {
    return {
      scope: migration.scope,
      scopeId: migration.scopeId,
      fromKey: migration.fromKey,
      toKey: migration.toKey,
      fromVersion: migration.fromVersion,
      toVersion: migration.toVersion,
      migratedAt: migration.migratedAt,
    };
  }

  private cloneMigrations(migrations: Array<SettingMigrationRecord>): Array<SettingMigrationRecord> {
    const result = new Array<SettingMigrationRecord>();
    for (let index = 0; index < migrations.length; index += 1) {
      result.push(this.cloneMigration(migrations[index]));
    }
    return result;
  }
}
