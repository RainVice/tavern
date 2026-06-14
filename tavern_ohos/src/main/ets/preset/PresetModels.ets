import type { PresetKind } from '../contracts/PublicContracts';

/**
 * 描述预设模块在运行时交换的数据结构。
 */
export interface PresetField {
  /**
   * 字段名称，作为键用于索引和匹配。
   */
  name: string;
  /**
   * 字段的字符串值。
   */
  value: string;
  /**
   * 存储值的类型名称。
   */
  valueType: string;
}

/**
 * 创建预设时需要传入的参数。
 */
export interface PresetCreateParams {
  /**
   * 预设唯一标识。
   */
  id: string;
  /**
   * 预设名称。
   */
  name: string;
  /**
   * 预设类型标识。
   */
  kind: PresetKind;
  /**
   * 预设是否启用，未启用时不会在运行时生效。
   */
  enabled: boolean;
  /**
   * 预设的版本号，用于迁移和兼容性检查。
   */
  version: number;
  /**
   * 预设的字段列表，用于存储采样参数和配置项键值对。
   */
  fields: Array<PresetField>;
  /**
   * 迁移来源的预设标识，记录本次创建是从哪个旧预设升级而来。
   */
  migratedFrom: string;
}

/**
 * 更新预设时需要传入的参数。与创建参数相比不包含 id，因为 id 通过方法参数单独传递。
 */
export interface PresetUpdateParams {
  /**
   * 预设名称。
   */
  name: string;
  /**
   * 预设是否启用，未启用时不会在运行时生效。
   */
  enabled: boolean;
  /**
   * 预设的版本号，用于迁移和兼容性检查。
   */
  version: number;
  /**
   * 预设的字段列表，用于存储采样参数和配置项键值对。
   */
  fields: Array<PresetField>;
  /**
   * 迁移来源的预设标识，记录本次更新是从哪个旧预设升级而来。
   */
  migratedFrom: string;
}

/**
 * 预设持久化或内存索引中的一条完整记录。
 */
export interface PresetRecord {
  /**
   * 预设唯一标识。
   */
  id: string;
  /**
   * 预设名称。
   */
  name: string;
  /**
   * 预设类型标识。
   */
  kind: PresetKind;
  /**
   * 预设是否启用，未启用时不会在运行时生效。
   */
  enabled: boolean;
  /**
   * 预设的版本号，用于迁移和兼容性检查。
   */
  version: number;
  /**
   * 预设的字段列表，用于存储采样参数和配置项键值对。
   */
  fields: Array<PresetField>;
  /**
   * 迁移来源的预设标识，记录该预设是从哪个旧版本预设升级而来。
   */
  migratedFrom: string;
}

/**
 * 预设与作用域之间的绑定关系记录。
 */
export interface PresetBindingRecord {
  /**
   * 绑定所属者的类型名称（如 chat/character），标记作用域的来源种类。
   */
  ownerType: string;
  /**
   * 绑定所属者的唯一标识。
   */
  ownerId: string;
  /**
   * 被绑定的预设类型，指定预设的种类归属。
   */
  presetKind: PresetKind;
  /**
   * 被绑定预设的唯一标识。
   */
  presetId: string;
}

/**
 * 预设导出时携带的数据结构，用于备份或 SillyTavern 互通。
 */
export interface PresetExportData {
  /**
   * 导出的预设记录。
   */
  preset: PresetRecord;
}

/**
 * 预设变更事件发布时携带的数据结构。
 */
export interface PresetEventPayload {
  /**
   * 发生变更的预设记录。
   */
  preset: PresetRecord;
}

/**
 * 预设被删除时事件发布携带的数据结构。
 */
export interface PresetDeletedPayload {
  /**
   * 被删除的预设标识。
   */
  presetId: string;
  /**
   * 被删除预设的类型，用于事件消费者过滤和界面刷新。
   */
  kind: PresetKind;
}

/**
 * 预设绑定成功时事件发布携带的数据结构。
 */
export interface PresetBoundPayload {
  /**
   * 绑定关系记录。
   */
  binding: PresetBindingRecord;
}

/**
 * 预设迁移时事件发布携带的数据结构，包含版本变化信息。
 */
export interface PresetMigratedPayload {
  /**
   * 迁移后的预设记录。
   */
  preset: PresetRecord;
  /**
   * 迁移前的版本号。
   */
  fromVersion: number;
  /**
   * 迁移后的目标版本号。
   */
  toVersion: number;
}
