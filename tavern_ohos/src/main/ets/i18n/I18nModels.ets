/**
 * 描述本地化持久化或内存索引中的一条记录，
 * 用于在 I18nRuntime 的条目索引中存储单条翻译数据，供 translate 查找。
 */
export interface I18nEntry {
  /**
   * 翻译键名，用于在 translate 时查找对应的翻译文本，
   * 格式通常为 'module.component.description' 的点分隔命名。
   */
  key: string;
  /**
   * 翻译文本值，即该键名对应的目标语言文本内容。
   */
  value: string;
  /**
   * 翻译条目所属分类，如 'general'（通用）、'ui'（界面）、'error'（错误提示），
   * 用于在 listLocale 时对翻译条目进行分类管理和筛选。
   */
  category: string;
}

/**
 * 描述本地化模块在运行时交换的数据结构，
 * 用于在注册语言包（registerBundle / addLocaleData）时承载一批翻译条目。
 */
export interface I18nBundle {
  /**
   * 语言区域代码，如 'zh-cn'、'en-us'，
   * 用于在运行时中按区域隔离翻译数据。
   */
  locale: string;
  /**
   * 翻译来源标识，标明该条目的来源，如 'builtin'（内置）、'user'（用户自定义）、'plugin'（插件提供），
   * 用于在多条相同键名的翻译记录中决定覆盖优先级。
   */
  source: string;
  /**
   * 翻译条目列表，包含该语言包中所有待注册的键值对。
   */
  entries: Array<I18nEntry>;
}

/**
 * 描述本地化模块在运行时交换的数据结构，
 * 用于在 translate 流程中替换翻译文本中的模板占位符。
 */
export interface I18nParam {
  /**
   * 参数名称，用于模板字符串中的占位符替换，
   * 格式为 '${name}'，在 interpolate 方法中被替换为对应的 value。
   */
  name: string;
  /**
   * 参数值，在 translate 的 interpolate 阶段替换模板中的同名占位符。
   */
  value: string;
}

/**
 * 描述本地化持久化或内存索引中的一条记录，
 * 用于在 I18nRuntime 的 records 索引中存储单条翻译记录的完整信息（含来源和时间戳）。
 */
export interface I18nTranslationRecord {
  /**
   * 语言区域代码，如 'zh-cn'、'en-us'，
   * 用于在 records 索引中与 key 拼合为复合键 '{locale}:{key}'。
   */
  locale: string;
  /**
   * 翻译键名，用于查找对应的翻译文本。
   */
  key: string;
  /**
   * 翻译文本值。
   */
  value: string;
  /**
   * 翻译条目所属分类，用于在 listLocale 时分类筛选。
   */
  category: string;
  /**
   * 翻译来源标识，如 'builtin'、'user'、'plugin'，
   * 用于在 upsertEntry 时决定是否允许覆盖。
   */
  source: string;
  /**
   * 翻译记录创建时间戳（毫秒），首次插入时设置。
   */
  createdAt: number;
  /**
   * 翻译记录最后更新时间戳（毫秒），覆盖更新时刷新。
   */
  updatedAt: number;
}

/**
 * 描述本地化持久化或内存索引中的一条记录，
 * 用于在 I18nRuntime 的 missing 索引中记录被查询但未找到的翻译键，辅助翻译补全。
 */
export interface I18nMissingRecord {
  /**
   * 缺失翻译的语言区域代码，用于在 listMissing 时按区域筛选。
   */
  locale: string;
  /**
   * 缺失翻译的键名，用于标识哪条翻译未配置对应区域的语言。
   */
  key: string;
  /**
   * 缺失翻译时使用的备用文本，即 translate 传入的 fallback 值。
   */
  fallback: string;
  /**
   * 缺失记录创建时间戳（毫秒），首次记录缺失时设置。
   */
  createdAt: number;
  /**
   * 该键被查询到缺失的次数累计，每次 translate 未找到该区域的该键名时自增。
   */
  count: number;
}

/**
 * 描述本地化事件发布时携带的数据结构，
 * 用于在 setLocale 切换语言后通过 EventBus 通知 UI 层刷新界面文本。
 */
export interface I18nLocaleChangedPayload {
  /**
   * 变更后的语言区域代码，UI 层应据此重新加载对应语言的字符串。
   */
  locale: string;
  /**
   * 变更前的语言区域代码，用于跟踪语言切换的历史。
   */
  previousLocale: string;
}

/**
 * 描述本地化事件发布时携带的数据结构，
 * 用于在 registerBundle 或 addLocaleData 注册语言包后通知其他模块。
 */
export interface I18nBundleRegisteredPayload {
  /**
   * 已注册的本地化包数据，
   * 供监听方（如翻译管理界面）获知新注册的翻译条目。
   */
  bundle: I18nBundle;
}

/**
 * 描述本地化事件发布时携带的数据结构，
 * 用于在 translate 找不到当前语言的翻译时通知监听方记录缺失翻译。
 */
export interface I18nMissingPayload {
  /**
   * 缺失翻译的语言区域代码，标识哪个语言缺少该翻译。
   */
  locale: string;
  /**
   * 缺失翻译的键名，标识哪条翻译未配置。
   */
  key: string;
  /**
   * 缺失时使用的备用文本，即 fallback 参数值。
   */
  fallback: string;
}
