/**
 * 描述调用主题能力时需要传入的参数。
 */
export interface ThemeSaveParams {
  /**
   * 主题名称。
   */
  name: string;
  /**
   * 主题内容 JSON 字符串。
   */
  contentJson: string;
  /**
   * 主题元数据 JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 描述主题持久化或内存索引中的一条记录。
 */
export interface ThemeRecord {
  /**
   * Schema 版本号。
   */
  schemaVersion: number;
  /**
   * 主题名称。
   */
  name: string;
  /**
   * 主题文件存储路径。
   */
  path: string;
  /**
   * 主题内容 JSON 字符串。
   */
  contentJson: string;
  /**
   * 主题元数据 JSON 字符串。
   */
  metadataJson: string;
  /**
   * 是否当前活跃主题。
   */
  active: boolean;
  /**
   * 记录创建时间戳（单位 ms）。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（单位 ms）。
   */
  updatedAt: number;
}

/**
 * 描述主题模块当前的活跃状态快照。
 */
export interface ThemeStateRecord {
  /**
   * 当前活跃的主题名称。
   */
  activeThemeName: string;
  /**
   * 当前背景标识。
   */
  activeBackground: string;
}

/**
 * 描述主题模块在运行时交换的数据结构。
 */
export interface ThemeExportData {
  /**
   * 所有主题记录列表。
   */
  themes: Array<ThemeRecord>;
  /**
   * 主题模块当前状态。
   */
  state: ThemeStateRecord;
}

/**
 * 描述主题激活事件发布时携带的数据结构。
 */
export interface ThemeActivatedPayload {
  /**
   * 被激活的主题名称。
   */
  themeName: string;
  /**
   * 被激活的主题记录。
   */
  theme: ThemeRecord;
}

/**
 * 描述主题保存事件发布时携带的数据结构。
 */
export interface ThemeSavedPayload {
  /**
   * 被保存的主题记录。
   */
  theme: ThemeRecord;
}

/**
 * 描述主题删除事件发布时携带的数据结构。
 */
export interface ThemeDeletedPayload {
  /**
   * 被删除的主题名称。
   */
  themeName: string;
}

/**
 * 描述主题背景变更事件发布时携带的数据结构。
 */
export interface ThemeBackgroundChangedPayload {
  /**
   * 新的背景标识。
   */
  background: string;
}
