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
 * 本地化系统支持多语言切换、翻译包注册、模板参数插值和缺失翻译记录，
 * 应用 UI 层可通过该模块实现界面文本的多语言显示。
 */
export class I18nRuntime {
  /**
   * 事件总线，用于在语言切换、翻译包注册和缺失翻译记录时向 UI 层和其他模块广播事件。
   */
  private events: EventBus;
  /**
   * 默认语言区域代码，当当前语言区域找不到翻译时使用此语言作为回退。
   */
  private defaultLocale: string;
  /**
   * 当前活动语言区域代码，影响 translate 方法查找翻译时的首选区域。
   */
  private currentLocale: string;
  /**
   * 翻译记录的内存索引，键为 '{locale}:{key}' 格式的复合键，
   * 用于快速按区域和键名查找翻译文本。
   */
  private records: Map<string, I18nTranslationRecord> = new Map<string, I18nTranslationRecord>();
  /**
   * 缺失翻译记录的内存索引，键为 '{locale}:{key}' 复合键，
   * 用于记录被 translate 查询但未找到的条目，辅助翻译补全。
   */
  private missing: Map<string, I18nMissingRecord> = new Map<string, I18nMissingRecord>();

  /**
   * 初始化本地化运行时，设置默认语言区域并从事件总线注入依赖。
   * @param events 事件总线实例，用于发布语言切换、包注册和缺失事件。
   * @param defaultLocale 默认语言区域代码，在当前区域找不到翻译时作为回退使用，
   *                      同时也在初始化时作为 currentLocale 的初始值。
   */
  constructor(events: EventBus, defaultLocale: string) {
    this.events = events;
    this.defaultLocale = this.normalizeLocale(defaultLocale);
    this.currentLocale = this.defaultLocale;
  }

  /**
   * 返回当前活动的语言区域代码。
   * UI 层在初始化时调用此方法确定界面应该使用哪种语言显示。
   * @returns 当前语言区域代码字符串（如 'zh-cn'、'en-us'）。
   */
  getCurrentLocale(): string {
    return this.currentLocale;
  }

  /**
   * 切换当前语言区域，并发布语言变更事件。
   * 在用户通过设置界面切换语言时由宿主或 UI 层调用，触发界面文本刷新。
   * @param locale 目标语言区域代码（如 'zh-cn'），会经过 normalizeLocale 规范化处理后设置。
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
   * 注册一个本地化包，将包内所有翻译条目插入索引，并发布注册事件。
   * 在应用启动时加载内置翻译包或插件注册自定义翻译时调用。
   * @param bundle 待注册的本地化包，包含语言区域、来源标识和翻译条目列表，
   *               如果 allowOverride 为 true（来自 registerBundle），已有条目会被覆盖。
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
   * 添加指定语言区域的翻译数据，跳过已存在的条目，并发布新条目注册事件。
   * 在用户自定义翻译或插件补充翻译时调用，不会覆盖已有翻译。
   * @param locale 目标语言区域代码，指定添加的翻译所属语言。
   * @param source 翻译来源标识（如 'user'、'plugin'），标记条目来源。
   * @param entries 待添加的翻译条目列表，已存在的键名将被跳过。
   */
  addLocaleData(locale: string, source: string, entries: Array<I18nEntry>): void {
    const normalized = this.normalizeLocale(locale);
    const accepted = new Array<I18nEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      // 复合键：'{locale}:{key}'，用于唯一标识一条翻译记录
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
   * 翻译指定键名的文本：优先查找当前区域，未找到则回退到默认区域，均未找到则记录缺失并返回备选文本。
   * 在 UI 层需要显示本地化文本时调用，是国际化支持的核心方法。
   * @param key 翻译键名（如 'general.save'），用于在 records 索引中查找对应的翻译文本。
   * @param fallback 找不到翻译时使用的备选文本，同时作为缺失记录的 fallback 值。
   * @param params 模板参数列表，用于在 interpolate 中替换翻译文本中的 '${name}' 占位符。
   * @returns 翻译后的文本，如果未找到则返回插值后的备选文本。
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
   * 列出指定语言区域的所有翻译记录副本。
   * 在翻译管理界面或调试工具展示某一语言的全部翻译时调用。
   * @param locale 目标语言区域代码，用于在 records 中筛选该区域的翻译记录。
   * @returns 翻译记录列表，按键名字母序排序，每个条目均为副本。
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
   * 列出指定语言区域所有缺失翻译记录副本。
   * 在翻译补全界面显示哪些翻译键尚未配置时调用。
   * @param locale 目标语言区域代码，用于在 missing 索引中筛选该区域的缺失记录。
   * @returns 缺失记录列表，按键名字母序排序，每个条目均为副本。
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
   * 插入或更新一条翻译记录。如果 allowOverride 为 false 且条目已存在，则返回已有记录不覆盖。
   * @param locale 语言区域代码。
   * @param source 翻译来源标识。
   * @param entry 待插入的翻译条目。
   * @param allowOverride 是否允许覆盖已有的翻译记录。
   * @returns 插入或已存在的翻译条目（不含来源和时间戳等内部字段）。
   */
  private upsertEntry(locale: string, source: string, entry: I18nEntry, allowOverride: boolean): I18nEntry {
    // 复合键：'{locale}:{key}'，用于唯一标识一条翻译记录
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
   * 在翻译记录中按语言区域和键名查找条目，未找到时返回 undefined。
   * @param locale 语言区域代码。
   * @param key 翻译键名。
   */
  private findRecord(locale: string, key: string): I18nTranslationRecord | undefined {
    return this.records.get(this.recordKey(this.normalizeLocale(locale), key));
  }

  /**
   * 记录某个翻译键在当前语言区域缺失的情况，更新缺失计数器并发布缺失事件。
   * @param locale 语言区域代码。
   * @param key 缺失的键名。
   * @param fallback 使用的备选文本。
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
   * 深拷贝翻译记录，防止外部代码修改内部状态。
   * @param record 要复制的原始翻译记录。
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
   * 深拷贝缺失记录，防止外部代码修改内部状态。
   * @param record 要复制的原始缺失记录。
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
   * 生成复合键 '{locale}:{key}'，用于唯一标识一条翻译记录。
   * @param locale 语言区域代码。
   * @param key 翻译键名。
   */
  private recordKey(locale: string, key: string): string {
    return `${locale}:${key}`;
  }

  /**
   * 规范化语言区域代码，统一转为小写以保证比较一致性。
   */
  private normalizeLocale(locale: string): string {
    return locale.toLowerCase();
  }
}
