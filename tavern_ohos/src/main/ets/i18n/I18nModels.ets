import type { RuntimeSource } from '../contracts/PublicContracts';

/**
 * 描述本地化持久化或内存索引中的一条记录。
 */
export interface I18nEntry {
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * 字段值。
   */
  value: string;
  /**
   * category 值，由当前实例内部维护。
   */
  category: string;
}

/**
 * 描述本地化模块在运行时交换的数据结构。
 */
export interface I18nBundle {
  /**
   * locale 值，由当前实例内部维护。
   */
  locale: string;
  /**
   * 来源类型，由当前实例内部维护。
   */
  source: RuntimeSource;
  /**
   * 条目列表，由当前实例内部维护。
   */
  entries: Array<I18nEntry>;
}

/**
 * 描述本地化模块在运行时交换的数据结构。
 */
export interface I18nParam {
  /**
   * 名称。
   */
  name: string;
  /**
   * 字段值。
   */
  value: string;
}

/**
 * 描述本地化持久化或内存索引中的一条记录。
 */
export interface I18nTranslationRecord {
  /**
   * locale 值，由当前实例内部维护。
   */
  locale: string;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * 字段值。
   */
  value: string;
  /**
   * category 值，由当前实例内部维护。
   */
  category: string;
  /**
   * 来源类型，由当前实例内部维护。
   */
  source: RuntimeSource;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述本地化持久化或内存索引中的一条记录。
 */
export interface I18nMissingRecord {
  /**
   * locale 值，由当前实例内部维护。
   */
  locale: string;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * fallback 值，由当前实例内部维护。
   */
  fallback: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * count 值，由当前实例内部维护。
   */
  count: number;
}

/**
 * 描述本地化事件发布时携带的数据结构。
 */
export interface I18nLocaleChangedPayload {
  /**
   * locale 值，由当前实例内部维护。
   */
  locale: string;
  /**
   * previous Locale 值，由当前实例内部维护。
   */
  previousLocale: string;
}

/**
 * 描述本地化事件发布时携带的数据结构。
 */
export interface I18nBundleRegisteredPayload {
  /**
   * bundle 值，由当前实例内部维护。
   */
  bundle: I18nBundle;
}

/**
 * 描述本地化事件发布时携带的数据结构。
 */
export interface I18nMissingPayload {
  /**
   * locale 值，由当前实例内部维护。
   */
  locale: string;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * fallback 值，由当前实例内部维护。
   */
  fallback: string;
}
