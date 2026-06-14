import type {
  SettingValueType,
  TavernScope,
} from '../contracts/PublicContracts';

/**
 * 描述调用设置能力时需要传入的参数。
 */
export interface SettingSchemaCreateParams {
  /**
   * 要注册的设置键名。
   */
  key: string;
  /**
   * 该设置项未显式赋值时的默认值。
   */
  defaultValue: string;
  /**
   * 值的类型标识，用于序列化与校验。
   */
  valueType: SettingValueType;
  /**
   * 当前 schema 的版本号，用于迁移追踪。
   */
  schemaVersion: number;
  /**
   * 该设置项的作用说明。
   */
  description: string;
}

/**
 * 描述一条设置 schema 的元数据定义记录。
 */
export interface SettingSchemaRecord {
  /**
   * 设置键名。
   */
  key: string;
  /**
   * 该设置项未显式赋值时的默认值。
   */
  defaultValue: string;
  /**
   * 值的类型标识。
   */
  valueType: SettingValueType;
  /**
   * 当前 schema 的版本号。
   */
  schemaVersion: number;
  /**
   * 该设置项的用途说明。
   */
  description: string;
}

/**
 * 描述一条具体的设置键值对记录。
 */
export interface SettingEntry {
  /**
   * 该记录所属的作用域（global/character/chat 等）。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 设置键名。
   */
  key: string;
  /**
   * 设置值。
   */
  value: string;
  /**
   * 该记录对应的 schema 版本号。
   */
  schemaVersion: number;
  /**
   * 该记录最后更新的时间戳。
   */
  updatedAt: number;
}

/**
 * 描述设置事件发布时携带的数据结构。
 */
export interface SettingChangedPayload {
  /**
   * 变更发生的作用域。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 发生变更的设置键名。
   */
  key: string;
  /**
   * 变更前的旧值。
   */
  oldValue: string;
  /**
   * 变更后的新值。
   */
  newValue: string;
  /**
   * 该设置对应的 schema 版本号。
   */
  schemaVersion: number;
}

/**
 * 描述一次设置键迁移的历史记录。
 */
export interface SettingMigrationRecord {
  /**
   * 迁移发生时的作用域。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 迁移前的原始键名。
   */
  fromKey: string;
  /**
   * 迁移后的目标键名。
   */
  toKey: string;
  /**
   * 迁移前 fromKey 对应的 schema 版本号。
   */
  fromVersion: number;
  /**
   * 迁移后 toKey 对应的 schema 版本号。
   */
  toVersion: number;
  /**
   * 迁移完成的时间戳。
   */
  migratedAt: number;
}

/**
 * 描述设置模块在某一时刻的快照，包含所有当前有效的配置数据。
 */
export interface SettingSnapshot {
  /**
   * 快照中包含的最大 schema 版本号。
   */
  schemaVersion: number;
  /**
   * 快照中包含的所有设置条目。
   */
  entries: Array<SettingEntry>;
  /**
   * 快照中包含的历史迁移记录。
   */
  migrationMetadata: Array<SettingMigrationRecord>;
}
