import type { PresetKind } from '../contracts/PublicContracts';

/**
 * 描述预设模块在运行时交换的数据结构。
 */
export interface PresetField {
  /**
   * 名称。
   */
  name: string;
  /**
   * 字段值。
   */
  value: string;
  /**
   * value Type 值，由当前实例内部维护。
   */
  valueType: string;
}

/**
 * 描述调用预设能力时需要传入的参数。
 */
export interface PresetCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * kind 值，由当前实例内部维护。
   */
  kind: PresetKind;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * version 值，由当前实例内部维护。
   */
  version: number;
  /**
   * fields 列表，由当前实例内部维护。
   */
  fields: Array<PresetField>;
  /**
   * migrated From 值，由当前实例内部维护。
   */
  migratedFrom: string;
}

/**
 * 描述调用预设能力时需要传入的参数。
 */
export interface PresetUpdateParams {
  /**
   * 名称。
   */
  name: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * version 值，由当前实例内部维护。
   */
  version: number;
  /**
   * fields 列表，由当前实例内部维护。
   */
  fields: Array<PresetField>;
  /**
   * migrated From 值，由当前实例内部维护。
   */
  migratedFrom: string;
}

/**
 * 描述预设持久化或内存索引中的一条记录。
 */
export interface PresetRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * kind 值，由当前实例内部维护。
   */
  kind: PresetKind;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * version 值，由当前实例内部维护。
   */
  version: number;
  /**
   * fields 列表，由当前实例内部维护。
   */
  fields: Array<PresetField>;
  /**
   * migrated From 值，由当前实例内部维护。
   */
  migratedFrom: string;
}

/**
 * 描述预设持久化或内存索引中的一条记录。
 */
export interface PresetBindingRecord {
  /**
   * owner Type 值，由当前实例内部维护。
   */
  ownerType: string;
  /**
   * owner 标识。
   */
  ownerId: string;
  /**
   * preset Kind 值，由当前实例内部维护。
   */
  presetKind: PresetKind;
  /**
   * preset 标识。
   */
  presetId: string;
}

/**
 * 描述预设模块在运行时交换的数据结构。
 */
export interface PresetExportData {
  /**
   * preset 值，由当前实例内部维护。
   */
  preset: PresetRecord;
}

/**
 * 描述预设事件发布时携带的数据结构。
 */
export interface PresetEventPayload {
  /**
   * preset 值，由当前实例内部维护。
   */
  preset: PresetRecord;
}

/**
 * 描述预设事件发布时携带的数据结构。
 */
export interface PresetDeletedPayload {
  /**
   * preset 标识。
   */
  presetId: string;
  /**
   * kind 值，由当前实例内部维护。
   */
  kind: PresetKind;
}

/**
 * 描述预设事件发布时携带的数据结构。
 */
export interface PresetBoundPayload {
  /**
   * binding 值，由当前实例内部维护。
   */
  binding: PresetBindingRecord;
}

/**
 * 描述预设事件发布时携带的数据结构。
 */
export interface PresetMigratedPayload {
  /**
   * preset 值，由当前实例内部维护。
   */
  preset: PresetRecord;
  /**
   * from Version 值，由当前实例内部维护。
   */
  fromVersion: number;
  /**
   * to Version 值，由当前实例内部维护。
   */
  toVersion: number;
}
