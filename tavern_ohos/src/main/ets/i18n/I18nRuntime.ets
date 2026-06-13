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

export class I18nRuntime {
  private events: EventBus;
  private defaultLocale: string;
  private currentLocale: string;
  private records: Map<string, I18nTranslationRecord> = new Map<string, I18nTranslationRecord>();
  private missing: Map<string, I18nMissingRecord> = new Map<string, I18nMissingRecord>();

  constructor(events: EventBus, defaultLocale: string) {
    this.events = events;
    this.defaultLocale = this.normalizeLocale(defaultLocale);
    this.currentLocale = this.defaultLocale;
  }

  getCurrentLocale(): string {
    return this.currentLocale;
  }

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

  addLocaleData(locale: string, source: string, entries: Array<I18nEntry>): void {
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

  private upsertEntry(locale: string, source: string, entry: I18nEntry, allowOverride: boolean): I18nEntry {
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

  private findRecord(locale: string, key: string): I18nTranslationRecord | undefined {
    return this.records.get(this.recordKey(this.normalizeLocale(locale), key));
  }

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

  private copyMissing(record: I18nMissingRecord): I18nMissingRecord {
    return {
      locale: record.locale,
      key: record.key,
      fallback: record.fallback,
      createdAt: record.createdAt,
      count: record.count,
    };
  }

  private recordKey(locale: string, key: string): string {
    return `${locale}:${key}`;
  }

  private normalizeLocale(locale: string): string {
    return locale.toLowerCase();
  }
}
