/**
 * 预设中的一个字段条目。
 * 用于 PresetRuntime 中存储预设的各配置项，如温度、top_p 等模型参数。
 */
export interface PresetField {
  /**
   * 字段名称，用于标识预设中的某个配置项（如 temperature、max_tokens）。
   */
  name: string;
  /**
   * 字段值，存储对应配置项的具体数值或文本。
   */
  value: string;
  /**
   * 字段值的类型标识（如 string、number、json），用于在反序列化时确定值的处理方式。
   */
  valueType: string;
}

/**
 * 创建预设时所需的参数。
 * 用于 PresetRuntime.createPreset 方法，定义预设的完整信息。
 */
export interface PresetCreateParams {
  /**
   * 预设的唯一标识，用于在运行时索引和定位预设。
   */
  id: string;
  /**
   * 预设的显示名称，用于在 UI 中展示。
   */
  name: string;
  /**
   * 预设的种类标识（如 completion、chat、instruct），用于在 listPresets 时按种类过滤。
   */
  kind: string;
  /**
   * 预设是否启用，启用时可在对应场景中自动应用。
   */
  enabled: boolean;
  /**
   * 预设的格式版本号，用于支持预设格式的版本迁移（migratePreset）。
   */
  version: number;
  /**
   * 预设的字段列表，存储各配置项的具体值。
   */
  fields: Array<PresetField>;
  /**
   * 迁移来源（上一版本的预设 ID 或版本号），用于追踪预设版本变迁历史。
   */
  migratedFrom: string;
}

/**
 * 更新预设时所需的参数。
 * 用于 PresetRuntime.updatePreset 方法，定义需要更新的字段。
 */
export interface PresetUpdateParams {
  /**
   * 预设的显示名称。
   */
  name: string;
  /**
   * 预设是否启用。
   */
  enabled: boolean;
  /**
   * 预设的格式版本号。
   */
  version: number;
  /**
   * 预设的字段列表。
   */
  fields: Array<PresetField>;
  /**
   * 迁移来源，用于记录本次更新是否来自版本迁移。
   */
  migratedFrom: string;
}

/**
 * 预设的持久化记录。
 * 由 PresetRuntime 管理，存储预设的完整数据。
 */
export interface PresetRecord {
  /**
   * 预设的唯一标识。
   */
  id: string;
  /**
   * 预设的显示名称。
   */
  name: string;
  /**
   * 预设的种类标识。
   */
  kind: string;
  /**
   * 预设是否启用。
   */
  enabled: boolean;
  /**
   * 预设的格式版本号。
   */
  version: number;
  /**
   * 预设的字段列表。
   */
  fields: Array<PresetField>;
  /**
   * 迁移来源信息。
   */
  migratedFrom: string;
}

/**
 * 预设与作用域的绑定记录。
 * 用于将预设绑定到特定角色或聊天，通过 getBinding 可按作用域解析出对应的预设。
 */
export interface PresetBindingRecord {
  /**
   * 绑定的所有者类型（如 character、chat），用于在获取绑定时确定范围。
   */
  ownerType: string;
  /**
   * 所有者的标识，与 ownerType 组合形成唯一绑定键。
   */
  ownerId: string;
  /**
   * 绑定的预设种类，用于在同一所有者绑定不同种类（如 completion vs chat）的预设。
   */
  presetKind: string;
  /**
   * 绑定的预设标识，用于定位被绑定的预设记录。
   */
  presetId: string;
}

/**
 * 预设的导出/导入格式。
 * 用于序列化预设数据以便备份恢复或在不同运行环境间迁移。
 */
export interface PresetExportData {
  /**
   * 要导出或导入的预设记录，包含完整的预设数据。
   */
  preset: PresetRecord;
}

/**
 * 预设事件统一的数据载荷（创建、更新、导入等）。
 * 由 publishPresetEvent 方法统一构建，在 createPreset、updatePreset、importPreset 中发布。
 */
export interface PresetEventPayload {
  /**
   * 关联的预设记录，供监听方获取预设详情。
   */
  preset: PresetRecord;
}

/**
 * 预设被删除时通过事件总线发布的数据载荷。
 * 由 deletePreset 发布，通知监听方（如 UI 层）移除预设显示。
 */
export interface PresetDeletedPayload {
  /**
   * 被删除的预设标识，供监听方清理引用。
   */
  presetId: string;
  /**
   * 被删除预设的种类标识，供监听方按种类刷新显示。
   */
  kind: string;
}

/**
 * 预设绑定完成时通过事件总线发布的数据载荷。
 * 由 bindPreset 发布，通知监听方（如 UI 层）更新绑定关系的显示。
 */
export interface PresetBoundPayload {
  /**
   * 创建的绑定记录，供监听方获取绑定详情。
   */
  binding: PresetBindingRecord;
}

/**
 * 预设迁移完成时通过事件总线发布的数据载荷。
 * 由 migratePreset 发布，通知监听方（如 UI 层）预设版本已更新。
 */
export interface PresetMigratedPayload {
  /**
   * 迁移后的预设记录，供监听方获取更新后的预设详情。
   */
  preset: PresetRecord;
  /**
   * 迁移前的版本号，用于记录迁移的历史路径。
   */
  fromVersion: number;
  /**
   * 迁移后的版本号，用于标识迁移的目标版本。
   */
  toVersion: number;
}
