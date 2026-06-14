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
 * 在对话流程中被各 Runtime 模块调用以读取应用配置（getSetting / getEffectiveSetting），
 * 由 UI 层调用以修改配置（setSetting / registerSchema）或执行键迁移（migrateSetting）。
 */
export class SettingsRuntime {
  private events: EventBus;
  private files: TavernFileStore | undefined = undefined;
  private rootPath: string = 'tavern-data';
  private userId: string = 'default';
  private schemas: Map<string, SettingSchemaRecord> = new Map<string, SettingSchemaRecord>();
  private entries: Map<string, SettingEntry> = new Map<string, SettingEntry>();
  private migrations: Array<SettingMigrationRecord> = new Array<SettingMigrationRecord>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例，用于在设置值变更时发布 "settings.changed" 事件。
   * @param files 文件存储适配器，非必选；传入时支持 saveToStore / loadFromStore 持久化，未传入时仅使用内存态。
   * @param rootPath 数据根路径，默认为 "tavern-data"，用于拼接文件存储路径。
   * @param userId 用户标识，默认为 "default"，用于拼接文件存储路径以隔离多用户设置数据。
   */
  constructor(events: EventBus, files?: TavernFileStore, rootPath: string = 'tavern-data', userId: string = 'default') {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从 SDK 内部文件存储恢复设置 schema、条目和迁移记录。
   * 由宿主在应用启动时调用，从持久化文件中加载之前保存的所有设置数据。
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
   * 由宿主在设置发生变更后调用，持久化当前内存中的全部设置数据。
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
   * 注册一个设置 schema，定义键名、默认值、类型等信息，使其可被后续使用。
   * 由各模块在初始化时调用，注册自身所需的设置项定义，
   * 注册后 setSetting / getSetting / getEffectiveSetting 才能识别该设置项。
   * @param params 设置 schema 的创建参数，包含键名、默认值、类型标识、版本号和说明文字。
   * @returns 注册后的 schema 记录副本。
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
   * 设置指定作用域下的配置项值，并发布变更事件。
   * 由 UI 层在用户修改配置时调用，存储设置值并通知宿主刷新。
   * @param scope 设置的作用域（如 "global"、"character"），限定设置的生效范围。
   * @param scopeId 作用域下的具体对象标识，与 scope 配合定位条目。
   * @param key 设置项的键名，需已通过 registerSchema 注册。
   * @param value 要设置的值，存储在 entries 映射中。
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
   * 获取指定作用域下的设置项值，不存在时返回 schema 中定义的默认值。
   * 由各 Runtime 模块在需要读取配置时调用。
   * @param scope 设置的作用域，用于定位设置条目。
   * @param scopeId 作用域下的具体对象标识，与 scope 配合定位条目。
   * @param key 设置项的键名。
   * @returns 存储的值或 schema 默认值；均不存在时返回空字符串。
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
   * 获取有效设置值：优先查找作用域级设置，未找到时回退到全局级设置，最后回退到 schema 默认值。
   * 由各 Runtime 模块在需要获取最终生效的配置值时调用，实现设置的作用域层级覆盖。
   * 例如：当 scope 为 "character" 时，优先取角色级设置，未设置则取全局级设置，再未设置则取 schema 默认值。
   * @param scope 作用域（如 "character"），优先在该作用域下查找。
   * @param scopeId 作用域下的具体对象标识。
   * @param key 设置项的键名。
   * @returns 有效的设置值。
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
   * 将设置项从旧键迁移到新键，并记录迁移历史。
   * 由各模块在 schema 版本升级时调用（如配置项重命名或数据结构变更），
   * 自动将旧键的自定义值转移到新键下并记录迁移历史。
   * @param scope 作用域，标识待迁移的设置项所属作用域。
   * @param scopeId 作用域下的具体对象标识，与 scope 配合定位条目。
   * @param fromKey 要迁移的旧键名，迁移后从 entries 中删除。
   * @param toKey 迁移后的新键名，迁移后指向原值。
   * @param targetVersion 迁移目标 schema 版本号。
   * @returns 迁移后的完整设置快照。
   */
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

  /**
   * 生成当前设置状态的完整快照，包含条目和迁移记录。
   * 由 migrateSetting 和外部模块调用，用于备份恢复或数据迁移验证。
   * @returns 当前设置快照。
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
   * 返回所有已注册的设置 schema 列表。
   * 由 UI 层在设置管理界面初始化时调用，展示所有可配置的设置项定义。
   * @returns schema 记录列表副本。
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
   * 返回指定作用域下的所有设置条目。
   * 由 UI 层在展示特定作用域的设置列表时调用（如某个人物的设置页）。
   * @param scope 作用域（如 "character"），限定条目的范围。
   * @param scopeId 作用域下的具体对象标识（如角色 ID），限定条目的具体对象。
   * @returns 设置条目列表副本。
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
   * 根据键名查找 schema，不存在时抛出异常。
   * @param key 设置项的键名。
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
   * 深拷贝 schema 记录。
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
   * 深拷贝设置条目。
   * @param entry 待拷贝的设置条目。
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
   * 深拷贝设置条目列表。
   * @param entries 待拷贝的条目列表。
   * @returns 新的条目列表副本。
   */
  private cloneEntries(entries: Array<SettingEntry>): Array<SettingEntry> {
    const result = new Array<SettingEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      result.push(this.cloneEntry(entries[index]));
    }
    return result;
  }

  /**
   * 深拷贝单条迁移记录。
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
   * 深拷贝迁移记录列表。
   * @param migrations 待拷贝的迁移记录列表。
   * @returns 新的迁移记录列表副本。
   */
  private cloneMigrations(migrations: Array<SettingMigrationRecord>): Array<SettingMigrationRecord> {
    const result = new Array<SettingMigrationRecord>();
    for (let index = 0; index < migrations.length; index += 1) {
      result.push(this.cloneMigration(migrations[index]));
    }
    return result;
  }
}
