import { EventBus } from '../runtime/EventBus';
import type {
  I18nBundle,
  I18nBundleRegisteredPayload,
  I18nEntry,
  I18nLocaleChangedPayload,
  I18nMissingPayload,
  I18nMissingRecord,
  I18nParam,
  I18nTranslationRecord,
} from './I18nModels';

/**
 * 提供本地化相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class I18nRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * default Locale 值，由当前实例内部维护。
   */
  private defaultLocale: string;
  /**
   * current Locale 值，由当前实例内部维护。
   */
  private currentLocale: string;
  /**
   * 记录副本列表，由当前实例内部维护。
   */
  private records: Map<string, I18nTranslationRecord> = new Map<string, I18nTranslationRecord>();
  /**
   * missing 值，由当前实例内部维护。
   */
  private missing: Map<string, I18nMissingRecord> = new Map<string, I18nMissingRecord>();

  /**
   * 注入本地化运行时依赖并初始化实例状态。
   * @param events 事件总线。
   */
  constructor(events: EventBus, defaultLocale: string) {
    this.events = events;
    this.defaultLocale = this.normalizeLocale(defaultLocale);
    this.currentLocale = this.defaultLocale;
  }

  /**
   * 读取指定CurrentLocale，不存在时抛出错误。
   * @returns 更新或读取后的记录副本。
   */
  getCurrentLocale(): string {
    return this.currentLocale;
  }

  /**
   * 设置语言区域，用于切换运行时状态或保存配置。

   */
  setLocale(locale: string): void {
    const normalized = this.normalizeLocale(locale);
    const previous = this.currentLocale;
    this.currentLocale = normalized;
    const payload: I18nLocaleChangedPayload = {
      locale: normalized,
      previousLocale: previous,
    };
    this.events.publish<I18nLocaleChangedPayload>('i18n.locale.changed', payload);
  }

  /**
   * 注册Bundle 值，使其可被后续运行时流程使用。

   */
  registerBundle(bundle: I18nBundle): void {
    const normalized = this.normalizeLocale(bundle.locale);
    const entries = new Array<I18nEntry>();
    for (let index = 0; index < bundle.entries.length; index += 1) {
      entries.push(this.upsertEntry(normalized, bundle.source, bundle.entries[index], true));
    }
    const payload: I18nBundleRegisteredPayload = {
      bundle: {
        locale: normalized,
        source: bundle.source,
        entries: entries,
      },
    };
    this.events.publish<I18nBundleRegisteredPayload>('i18n.bundle.registered', payload);
  }

  /**
   * 创建或写入LocaleData，完成持久化后返回可供调用方使用的结果。

   * @param source 来源类型。
   * @param entries 条目列表。
   */
  addLocaleData(locale: string, source: string, entries: Array<I18nEntry>): void {
    const normalized = this.normalizeLocale(locale);
    const accepted = new Array<I18nEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      // 键名。
      const key = this.recordKey(normalized, entries[index].key);
      if (this.records.has(key)) {
        continue;
      }
      accepted.push(this.upsertEntry(normalized, source, entries[index], false));
    }
    const payload: I18nBundleRegisteredPayload = {
      bundle: {
        locale: normalized,
        source: source,
        entries: accepted,
      },
    };
    this.events.publish<I18nBundleRegisteredPayload>('i18n.bundle.registered', payload);
  }

  /**
   * 执行 translate 的内部处理步骤，供当前模块复用。
   * @param key 键名。

   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  translate(key: string, fallback: string, params: Array<I18nParam>): string {
    const record = this.findRecord(this.currentLocale, key);
    if (record !== undefined) {
      return this.interpolate(record.value, params);
    }
    const defaultRecord = this.findRecord(this.defaultLocale, key);
    if (defaultRecord !== undefined) {
      return this.interpolate(defaultRecord.value, params);
    }
    this.recordMissing(this.currentLocale, key, fallback);
    return this.interpolate(fallback, params);
  }

  /**
   * 读取Locale列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listLocale(locale: string): Array<I18nTranslationRecord> {
    const normalized = this.normalizeLocale(locale);
    const result = new Array<I18nTranslationRecord>();
    const values = Array.from(this.records.values());
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].locale === normalized) {
        result.push(this.copyRecord(values[index]));
      }
    }
    result.sort((left: I18nTranslationRecord, right: I18nTranslationRecord) => left.key.localeCompare(right.key));
    return result;
  }

  /**
   * 读取Missing列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listMissing(locale: string): Array<I18nMissingRecord> {
    const normalized = this.normalizeLocale(locale);
    const result = new Array<I18nMissingRecord>();
    const values = Array.from(this.missing.values());
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].locale === normalized) {
        result.push(this.copyMissing(values[index]));
      }
    }
    result.sort((left: I18nMissingRecord, right: I18nMissingRecord) => left.key.localeCompare(right.key));
    return result;
  }

  /**
   * 创建或写入条目，完成持久化后返回可供调用方使用的结果。

   * @param source 来源类型。
   * @param entry 条目记录。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  private upsertEntry(locale: string, source: string, entry: I18nEntry, allowOverride: boolean): I18nEntry {
    // 键名。
    const key = this.recordKey(locale, entry.key);
    const existing = this.records.get(key);
    if (existing !== undefined && !allowOverride) {
      return {
        key: existing.key,
        value: existing.value,
        category: existing.category,
      };
    }
    const now = Date.now();
    const record: I18nTranslationRecord = {
      locale: locale,
      key: entry.key,
      value: entry.value,
      category: entry.category,
      source: source,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.records.set(key, record);
    return {
      key: record.key,
      value: record.value,
      category: record.category,
    };
  }

  /**
   * 在当前集合中查找Record 值，未命中时返回空值或默认位置。

   * @param key 键名。
   */
  private findRecord(locale: string, key: string): I18nTranslationRecord | undefined {
    return this.records.get(this.recordKey(this.normalizeLocale(locale), key));
  }

  /**
   * 创建或写入Missing，完成持久化后返回可供调用方使用的结果。

   * @param key 键名。

   */
  private recordMissing(locale: string, key: string, fallback: string): void {
    const normalized = this.normalizeLocale(locale);
    const missingKey = this.recordKey(normalized, key);
    const existing = this.missing.get(missingKey);
    if (existing === undefined) {
      const record: I18nMissingRecord = {
        locale: normalized,
        key: key,
        fallback: fallback,
        createdAt: Date.now(),
        count: 1,
      };
      this.missing.set(missingKey, record);
    } else {
      existing.count += 1;
    }
    const payload: I18nMissingPayload = {
      locale: normalized,
      key: key,
      fallback: fallback,
    };
    this.events.publish<I18nMissingPayload>('i18n.missing', payload);
  }
  private interpolate(text: string, params: Array<I18nParam>): string {
    let output = text;
    for (let index = 0; index < params.length; index += 1) {
      output = this.replaceAll(output, '${' + params[index].name + '}', params[index].value);
      output = this.replaceAll(output, '${' + index + '}', params[index].value);
    }
    return output;
  }
  private replaceAll(input: string, needle: string, value: string): string {
    if (needle.length === 0) {
      return input;
    }
    let output = input;
    let index = output.indexOf(needle);
    while (index >= 0) {
      output = output.substring(0, index) + value + output.substring(index + needle.length);
      index = output.indexOf(needle, index + value.length);
    }
    return output;
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private copyRecord(record: I18nTranslationRecord): I18nTranslationRecord {
    return {
      locale: record.locale,
      key: record.key,
      value: record.value,
      category: record.category,
      source: record.source,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  /**
   * 复制Missing 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private copyMissing(record: I18nMissingRecord): I18nMissingRecord {
    return {
      locale: record.locale,
      key: record.key,
      fallback: record.fallback,
      createdAt: record.createdAt,
      count: record.count,
    };
  }

  /**
   * 创建或写入Key，完成持久化后返回可供调用方使用的结果。

   * @param key 键名。
   */
  private recordKey(locale: string, key: string): string {
    return `${locale}:${key}`;
  }

  /**
   * 规范化Locale 值，保证后续比较和存储使用一致格式。
   */
  private normalizeLocale(locale: string): string {
    return locale.toLowerCase();
  }
}
