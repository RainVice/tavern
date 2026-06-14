import type {
  SettingValueType,
  TavernScope,
} from '../contracts/PublicContracts';

/**
 * 描述调用设置能力时需要传入的参数。
 */
export interface SettingSchemaCreateParams {
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * default Value 值，由当前实例内部维护。
   */
  defaultValue: string;
  /**
   * value Type 值，由当前实例内部维护。
   */
  valueType: SettingValueType;
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
}

/**
 * 描述设置持久化或内存索引中的一条记录。
 */
export interface SettingSchemaRecord {
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * default Value 值，由当前实例内部维护。
   */
  defaultValue: string;
  /**
   * value Type 值，由当前实例内部维护。
   */
  valueType: SettingValueType;
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
}

/**
 * 描述设置持久化或内存索引中的一条记录。
 */
export interface SettingEntry {
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * 字段值。
   */
  value: string;
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述设置事件发布时携带的数据结构。
 */
export interface SettingChangedPayload {
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * old Value 值，由当前实例内部维护。
   */
  oldValue: string;
  /**
   * new Value 值，由当前实例内部维护。
   */
  newValue: string;
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
}

/**
 * 描述设置持久化或内存索引中的一条记录。
 */
export interface SettingMigrationRecord {
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * from Key 值，由当前实例内部维护。
   */
  fromKey: string;
  /**
   * to Key 值，由当前实例内部维护。
   */
  toKey: string;
  /**
   * from Version 值，由当前实例内部维护。
   */
  fromVersion: number;
  /**
   * to Version 值，由当前实例内部维护。
   */
  toVersion: number;
  /**
   * migrated At 值，由当前实例内部维护。
   */
  migratedAt: number;
}

/**
 * 描述设置模块在运行时交换的数据结构。
 */
export interface SettingSnapshot {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 条目列表，由当前实例内部维护。
   */
  entries: Array<SettingEntry>;
  /**
   * migration Metadata 值，由当前实例内部维护。
   */
  migrationMetadata: Array<SettingMigrationRecord>;
}
