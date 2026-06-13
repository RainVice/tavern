export interface I18nEntry {
  key: string;
  value: string;
  category: string;
}

export interface I18nBundle {
  locale: string;
  source: string;
  entries: Array<I18nEntry>;
}

export interface I18nParam {
  name: string;
  value: string;
}

export interface I18nTranslationRecord {
  locale: string;
  key: string;
  value: string;
  category: string;
  source: string;
  createdAt: number;
  updatedAt: number;
}

export interface I18nMissingRecord {
  locale: string;
  key: string;
  fallback: string;
  createdAt: number;
  count: number;
}

export interface I18nLocaleChangedPayload {
  locale: string;
  previousLocale: string;
}

export interface I18nBundleRegisteredPayload {
  bundle: I18nBundle;
}

export interface I18nMissingPayload {
  locale: string;
  key: string;
  fallback: string;
}
