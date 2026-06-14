import type { RuntimeSource } from '../contracts/PublicContracts';

/**
 * 描述本地化持久化或内存索引中的一条条目记录。
 */
export interface I18nEntry {
  /**
   * 翻译键名，在同一个 locale 内唯一。
   */
  key: string;
  /**
   * 翻译文本内容。
   */
  value: string;
  /**
   * 分类标签，用于对翻译条目分组归类。
   */
  category: string;
}

/**
 * 描述本地化模块在运行时交换的一整包数据，包含 locale、来源和条目列表。
 */
export interface I18nBundle {
  /**
   * 语言区域标识（如 "zh-CN"、"en-US"），传入后自动规范化。
   */
  locale: string;
  /**
   * 来源类型，标记该包来自内置资源还是用户配置。
   */
  source: RuntimeSource;
  /**
   * 翻译条目列表。
   */
  entries: Array<I18nEntry>;
}

/**
 * 描述文本插值所需的命名参数对。
 */
export interface I18nParam {
  /**
   * 参数名，匹配翻译模板中的 ${name} 占位符。
   */
  name: string;
  /**
   * 替换到占位符中的文本值。
   */
  value: string;
}

/**
 * 描述一条已注册到索引中的完整翻译记录，包含元信息。
 */
export interface I18nTranslationRecord {
  /**
   * 语言区域标识。
   */
  locale: string;
  /**
   * 翻译键名。
   */
  key: string;
  /**
   * 翻译文本内容。
   */
  value: string;
  /**
   * 分类标签。
   */
  category: string;
  /**
   * 来源类型，标记该记录的来源。
   */
  source: RuntimeSource;
  /**
   * 记录创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 记录最近更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述某条未找到的翻译记录的缺失情况。
 */
export interface I18nMissingRecord {
  /**
   * 语言区域标识。
   */
  locale: string;
  /**
   * 缺失的翻译键名。
   */
  key: string;
  /**
   * 本次查询使用的回退文本。
   */
  fallback: string;
  /**
   * 首次缺失记录的时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 缺失记录累计命中次数。
   */
  count: number;
}

/**
 * 描述语言区域切换事件携带的数据。
 */
export interface I18nLocaleChangedPayload {
  /**
   * 切换后的语言区域标识。
   */
  locale: string;
  /**
   * 切换前的语言区域标识。
   */
  previousLocale: string;
}

/**
 * 描述 Bundle 注册成功事件携带的数据。
 */
export interface I18nBundleRegisteredPayload {
  /**
   * 注册成功的 Bundle 数据。
   */
  bundle: I18nBundle;
}

/**
 * 描述翻译缺失事件携带的数据。
 */
export interface I18nMissingPayload {
  /**
   * 缺失翻译时的语言区域标识。
   */
  locale: string;
  /**
   * 缺失的翻译键名。
   */
  key: string;
  /**
   * 此次查询使用的回退文本。
   */
  fallback: string;
}
