import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  SettingChangedPayload,
  SettingEntry,
  SettingMigrationRecord,
  SettingSchemaCreateParams,
  SettingSchemaRecord,
  SettingSnapshot,
} from './SettingsModels';

interface SettingsStorageSnapshot {
  schemaVersion: number;
  schemas: Array<SettingSchemaRecord>;
  entries: Array<SettingEntry>;
  migrationMetadata: Array<SettingMigrationRecord>;
}

/**
 * 提供设置相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class SettingsRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 文件存储适配器；未传入时仅使用内存态。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 用户标识。
   */
  private userId: string = 'default';
  /**
   * schemas 列表，由当前实例内部维护。
   */
  private schemas: Map<string, SettingSchemaRecord> = new Map<string, SettingSchemaRecord>();
  /**
   * 条目列表，由当前实例内部维护。
   */
  private entries: Map<string, SettingEntry> = new Map<string, SettingEntry>();
  /**
   * migrations 列表，由当前实例内部维护。
   */
  private migrations: Array<SettingMigrationRecord> = new Array<SettingMigrationRecord>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus, files?: TavernFileStore, rootPath: string = 'tavern-data', userId: string = 'default') {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从 SDK 内部文件存储恢复设置 schema、条目和迁移记录。
   */
  async loadFromStore(): Promise<void> {
    const store = new JsonStore<SettingsStorageSnapshot>(this.requireFiles(), this.storagePath());
    const snapshot = await store.read(this.defaultStorageSnapshot());
    this.schemas.clear();
    this.entries.clear();
    this.migrations = this.cloneMigrations(snapshot.migrationMetadata);
    for (let index = 0; index < snapshot.schemas.length; index += 1) {
      const schema = this.cloneSchema(snapshot.schemas[index]);
      this.schemas.set(schema.key, schema);
    }
    for (let index = 0; index < snapshot.entries.length; index += 1) {
      const entry = this.cloneEntry(snapshot.entries[index]);
      this.entries.set(this.entryKey(entry.scope, entry.scopeId, entry.key), entry);
    }
  }

  /**
   * 把当前设置 schema、条目和迁移记录写入 SDK 内部文件存储。
   */
  async saveToStore(): Promise<void> {
    const schemas = this.cloneSchemas(Array.from(this.schemas.values()));
    const entries = this.cloneEntries(Array.from(this.entries.values()));
    const migrations = this.cloneMigrations(this.migrations);
    const schemaVersion = this.maxSchemaVersion(entries);
    const snapshot: SettingsStorageSnapshot = {
      schemaVersion: schemaVersion,
      schemas: schemas,
      entries: entries,
      migrationMetadata: migrations,
    };
    await new JsonStore<SettingsStorageSnapshot>(this.requireFiles(), this.storagePath()).write(snapshot);
  }

  /**
   * 注册Schema 值，使其可被后续运行时流程使用。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
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

  /**
   * 设置配置项，用于切换运行时状态或保存配置。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param key 键名。
   * @param value 要保存或比较的字段值。
   */
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

  /**
   * 读取指定设置项，不存在时抛出错误。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param key 键名。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 读取指定设置项，不存在时抛出错误。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param key 键名。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 执行 migrateSetting 的内部处理步骤，供当前模块复用。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   */
  migrateSetting(scope: string, scopeId: string, fromKey: string, toKey: string, targetVersion: number): SettingSnapshot {
    const fromSchema = this.requireSchema(fromKey);
    const toSchema = this.requireSchema(toKey);
    const sourceKey = this.entryKey(scope, scopeId, fromKey);
    // 来源类型。
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

  /**
   * 执行 snapshot 的内部处理步骤，供当前模块复用。
   */
  snapshot(): SettingSnapshot {
    const entries = this.cloneEntries(Array.from(this.entries.values()));
    const maxVersion = this.maxSchemaVersion(entries);
    const snapshotEntries = this.cloneEntries(entries);
    const migrationMetadata = this.cloneMigrations(this.migrations);
    const snapshot: SettingSnapshot = {
      schemaVersion: maxVersion,
      entries: snapshotEntries,
      migrationMetadata: migrationMetadata,
    };
    return snapshot;
  }

  /**
   * 读取Schemas列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listSchemas(): Array<SettingSchemaRecord> {
    const result = new Array<SettingSchemaRecord>();
    const schemas = Array.from(this.schemas.values());
    for (let index = 0; index < schemas.length; index += 1) {
      result.push(this.cloneSchema(schemas[index]));
    }
    return result;
  }

  /**
   * 读取条目列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 读取必须存在的Schema 值，缺失时抛出错误。
   * @param key 键名。
   */
  private requireSchema(key: string): SettingSchemaRecord {
    const schema = this.schemas.get(key);
    if (schema === undefined) {
      throw new Error(`Setting schema not found: ${key}`);
    }
    return schema;
  }

  private requireFiles(): TavernFileStore {
    if (this.files === undefined) {
      throw new Error('SettingsRuntime storage is not configured.');
    }
    return this.files;
  }

  private storagePath(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/settings.json`;
  }

  private defaultStorageSnapshot(): SettingsStorageSnapshot {
    return {
      schemaVersion: 1,
      schemas: new Array<SettingSchemaRecord>(),
      entries: new Array<SettingEntry>(),
      migrationMetadata: new Array<SettingMigrationRecord>(),
    };
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

  /**
   * 复制Schema 值，避免外部修改内部状态。
   */
  private cloneSchema(schema: SettingSchemaRecord): SettingSchemaRecord {
    return {
      key: schema.key,
      defaultValue: schema.defaultValue,
      valueType: schema.valueType,
      schemaVersion: schema.schemaVersion,
      description: schema.description,
    };
  }

  private cloneSchemas(schemas: Array<SettingSchemaRecord>): Array<SettingSchemaRecord> {
    const result = new Array<SettingSchemaRecord>();
    for (let index = 0; index < schemas.length; index += 1) {
      result.push(this.cloneSchema(schemas[index]));
    }
    return result;
  }

  /**
   * 复制Entry 值，避免外部修改内部状态。
   * @param entry 条目记录。
   */
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

  /**
   * 复制Entries 列表，避免外部修改内部状态。
   * @param entries 条目列表。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneEntries(entries: Array<SettingEntry>): Array<SettingEntry> {
    const result = new Array<SettingEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      result.push(this.cloneEntry(entries[index]));
    }
    return result;
  }

  /**
   * 复制Migration 值，避免外部修改内部状态。
   */
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

  /**
   * 复制Migrations 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneMigrations(migrations: Array<SettingMigrationRecord>): Array<SettingMigrationRecord> {
    const result = new Array<SettingMigrationRecord>();
    for (let index = 0; index < migrations.length; index += 1) {
      result.push(this.cloneMigration(migrations[index]));
    }
    return result;
  }
}
