import { EventBus } from '../runtime/EventBus';
import type { RuntimeSource } from '../contracts/PublicContracts';
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
   * 事件总线，用于发布 locale 切换、bundle 注册、翻译缺失等事件。
   */
  private events: EventBus;
  /**
   * 兜底语言区域标识，当指定语言找不到翻译时回退到此值。
   */
  private defaultLocale: string;
  /**
   * 当前生效的语言区域标识。
   */
  private currentLocale: string;
  /**
   * 已注册的全部翻译记录，键为 "${locale}:${key}"。
   */
  private records: Map<string, I18nTranslationRecord> = new Map<string, I18nTranslationRecord>();
  /**
   * 已记录的缺失翻译记录，键为 "${locale}:${key}"。
   */
  private missing: Map<string, I18nMissingRecord> = new Map<string, I18nMissingRecord>();

  /**
   * 注入本地化运行时依赖并初始化实例状态。
   * @param events 事件总线。
   * @param defaultLocale 兜底语言区域标识。
   */
  constructor(events: EventBus, defaultLocale: string) {
    this.events = events;
    this.defaultLocale = this.normalizeLocale(defaultLocale);
    this.currentLocale = this.defaultLocale;
  }

  /**
   * 获取当前生效的语言区域标识。
   * @returns 当前语言区域的小写形式。
   */
  getCurrentLocale(): string {
    return this.currentLocale;
  }

  /**
   * 设置语言区域并发布 locale 切换事件。
   * @param locale 新的语言区域标识。
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
   * 注册一组翻译条目并发布 bundle 注册事件。
   * 已存在的条目会被覆盖。
   * @param bundle 待注册的翻译数据包。
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
   * 向指定语言区域添加新翻译条目，跳过已存在的键名。
   * @param locale 目标语言区域标识。
   * @param source 来源类型。
   * @param entries 待添加的条目列表。
   */
  addLocaleData(locale: string, source: RuntimeSource, entries: Array<I18nEntry>): void {
    const normalized = this.normalizeLocale(locale);
    const accepted = new Array<I18nEntry>();
    for (let index = 0; index < entries.length; index += 1) {
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
   * 翻译指定键名：优先查找当前 locale，未命中则回退到兜底 locale，
   * 仍未命中则记录缺失并返回回退文本。结果中的 ${name} 占位符会被 params 替换。
   * @param key 翻译键名。
   * @param fallback 键名不存在时返回的回退文本。
   * @param params 插值参数列表。
   * @returns 翻译后的文本。
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
   * 查询指定语言区域的所有已注册翻译记录。
   * @param locale 目标语言区域标识。
   * @returns 翻译记录列表的副本，按键名排序。
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
   * 查询指定语言区域的所有缺失翻译记录。
   * @param locale 目标语言区域标识。
   * @returns 缺失记录列表的副本，按键名排序。
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
   * 创建或更新一条翻译记录。若已存在且 allowOverride 为 false，则保留原值。
   * @param locale 语言区域标识。
   * @param source 来源类型。
   * @param entry 待写入的条目。
   * @param allowOverride 是否允许覆盖已有值。
   * @returns 写入后的条目（仅含 key / value / category）。
   */
  private upsertEntry(locale: string, source: RuntimeSource, entry: I18nEntry, allowOverride: boolean): I18nEntry {
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
   * 在 records 中查找指定 locale 和键名的翻译记录。
   * @param locale 语言区域标识。
   * @param key 翻译键名。
   * @returns 找到的记录，未命中时返回 undefined。
   */
  private findRecord(locale: string, key: string): I18nTranslationRecord | undefined {
    return this.records.get(this.recordKey(this.normalizeLocale(locale), key));
  }

  /**
   * 记录一次翻译缺失：首次缺失创建新记录，后续缺失累加计数。
   * 同时发布 i18n.missing 事件。
   * @param locale 语言区域标识。
   * @param key 缺失的翻译键名。
   * @param fallback 本次使用的回退文本。
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

  /**
   * 对文本执行参数插值，替换 ${name} 和 ${index} 占位符。
   * @param text 包含占位符的原始文本。
   * @param params 参数列表，按 name 和索引匹配占位符。
   * @returns 插值后的文本。
   */
  private interpolate(text: string, params: Array<I18nParam>): string {
    let output = text;
    for (let index = 0; index < params.length; index += 1) {
      output = this.replaceAll(output, '${' + params[index].name + '}', params[index].value);
      output = this.replaceAll(output, '${' + index + '}', params[index].value);
    }
    return output;
  }

  /**
   * 替换字符串中所有匹配的子串。
   * @param input 原始字符串。
   * @param needle 要查找的子串。
   * @param value 替换文本。
   * @returns 替换后的字符串。
   */
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
   * 深拷贝一条翻译记录，避免外部调用修改内部状态。
   * @param record 原始记录。
   * @returns 新创建的记录副本。
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
   * 深拷贝一条缺失记录，避免外部调用修改内部状态。
   * @param record 原始记录。
   * @returns 新创建的记录副本。
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
   * 根据语言区域和键名生成内部存储键。
   * @param locale 语言区域标识。
   * @param key 翻译键名。
   * @returns 格式为 "${locale}:${key}" 的合成键。
   */
  private recordKey(locale: string, key: string): string {
    return `${locale}:${key}`;
  }

  /**
   * 将语言区域标识转换为小写，保证后续比较和存储的格式一致。
   * @param locale 原始语言区域标识。
   * @returns 规范化后的小写形式。
   */
  private normalizeLocale(locale: string): string {
    return locale.toLowerCase();
  }
}
