/**
 * 描述调用设置能力时需要传入的参数。
 * 用于注册一个新的设置 schema（registerSchema），定义键名、默认值、类型和版本信息。
 */
export interface SettingSchemaCreateParams {
  /**
   * 设置项的键名，在 schemas 映射表中作为唯一键，
   * 也用于拼接待查询键 "scope:scopeId:key"。
   */
  key: string;
  /**
   * 设置项的默认值，当 getSetting 未找到自定义值时作为回退值返回。
   */
  defaultValue: string;
  /**
   * 设置值的类型标识（如 "string"、"number"、"boolean"），
   * 用于在 UI 层选择对应类型的输入控件。
   */
  valueType: string;
  /**
   * 设置 schema 的版本号，用于 detect 和执行设置迁移（migrateSetting），
   * 当 schema 被更新时可依据版本号判断是否需要迁移旧值。
   */
  schemaVersion: number;
  /**
   * 设置项的说明文字，供 UI 层在设置列表中展示该项的用途描述。
   */
  description: string;
}

/**
 * 描述设置持久化或内存索引中的一条记录。
 * 由 registerSchema 创建并存储，定义设置项的元信息。
 */
export interface SettingSchemaRecord {
  /**
   * 设置项的键名，在 schemas 映射表中作为唯一键，用于查找默认值和类型信息。
   */
  key: string;
  /**
   * 设置项的默认值，在 getSetting 中当用户未设置自定义值时作为回退值返回。
   */
  defaultValue: string;
  /**
   * 设置值的类型标识，供 UI 层选择对应的控件类型。
   */
  valueType: string;
  /**
   * 设置 schema 版本号，在 migrateSetting 中用于检测是否需要迁移。
   */
  schemaVersion: number;
  /**
   * 设置项的说明文字，供 UI 展示。
   */
  description: string;
}

/**
 * 描述设置持久化或内存索引中的一条记录。
 * 由 setSetting 创建并存储在 entries 映射中，通过 getSetting / getEffectiveSetting 读取使用。
 */
export interface SettingEntry {
  /**
   * 设置项的作用域（如 "global"、"character"、"chat"），
   * 在 entries 映射中与 scopeId + key 拼接待查询键，用于按作用域隔离设置值，
   * 在 getEffectiveSetting 中实现作用域级回退逻辑。
   */
  scope: string;
  /**
   * 作用域下的具体对象标识（如角色 ID、聊天 ID），
   * 与 scope 配合定位具体的设置条目。空字符串表示作用域本身。
   */
  scopeId: string;
  /**
   * 设置项的键名，对应已注册 schema 的 key，在 getSetting / getEffectiveSetting 中作为查找条件。
   */
  key: string;
  /**
   * 设置项的当前值，由用户在 UI 中配置，通过 setSetting 保存，通过 getSetting 读取使用。
   */
  value: string;
  /**
   * 当前值对应的 schema 版本号，用于 migrateSetting 判断是否需要将当前值迁移到新版本。
   */
  schemaVersion: number;
  /**
   * 设置项最近更新时的时间戳（毫秒），用于追踪配置变更时间。
   */
  updatedAt: number;
}

/**
 * 描述设置事件发布时携带的数据结构。
 * 当 setSetting 方法修改了设置值时，通过事件总线通知宿主或其他模块。
 */
export interface SettingChangedPayload {
  /**
   * 设置项的作用域，用于标识变更发生的作用域层级（如 "global"、"character"、"chat"）。
   */
  scope: string;
  /**
   * 作用域下的具体对象标识，用于标识变更发生的具体对象。
   */
  scopeId: string;
  /**
   * 发生变化的设置项键名，用于定位具体是哪个设置项发生了变化。
   */
  key: string;
  /**
   * 变化前的旧值，供宿主决定是否需要根据旧值执行额外逻辑或回滚。
   */
  oldValue: string;
  /**
   * 变化后的新值，宿主可据此更新 UI 或触发后续操作。
   */
  newValue: string;
  /**
   * 变化时对应的 schema 版本号，用于追踪变更发生在哪个 schema 版本下。
   */
  schemaVersion: number;
}

/**
 * 描述设置持久化或内存索引中的一条记录。
 * 由 migrateSetting 方法创建并存储在 migrations 列表中，记录一次键或 schema 版本迁移的元信息。
 */
export interface SettingMigrationRecord {
  /**
   * 作用域，标识发生迁移的设置项所属作用域。
   */
  scope: string;
  /**
   * 作用域下的具体对象标识，标识迁移发生的具体对象。
   */
  scopeId: string;
  /**
   * 迁移前的旧键名，在 migrateSetting 的查找阶段使用。
   */
  fromKey: string;
  /**
   * 迁移后的新键名，在 migrateSetting 中替换旧键后存储。
   */
  toKey: string;
  /**
   * 迁移前的 schema 版本号，记录旧值所基于的版本。
   */
  fromVersion: number;
  /**
   * 迁移后的 schema 版本号，记录新值应基于的目标版本。
   */
  toVersion: number;
  /**
   * 迁移发生时的时间戳（毫秒），用于追踪迁移时间。
   */
  migratedAt: number;
}

/**
 * 描述设置模块在运行时交换的数据结构。
 * 由 migrateSetting 和 snapshot 方法构建，代表当前所有设置的完整快照，
 * 用于备份恢复、UI 展示或数据迁移验证。
 */
export interface SettingSnapshot {
  /**
   * 快照的数据 schema 版本号，取 entries 中各条目的最大 schemaVersion。
   */
  schemaVersion: number;
  /**
   * 快照中包含的所有设置条目，是当前生效的所有设置值列表。
   */
  entries: Array<SettingEntry>;
  /**
   * 快照中包含的设置迁移记录，供审计或历史追溯使用。
   */
  migrationMetadata: Array<SettingMigrationRecord>;
}
