/**
 * 描述调用主题能力时需要传入的参数。
 */
export interface ThemeSaveParams {
  /**
   * 名称。
   */
  name: string;
  /**
   * content JSON 字符串。
   */
  contentJson: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 描述主题持久化或内存索引中的一条记录。
 */
export interface ThemeRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 名称。
   */
  name: string;
  /**
   * 路径。
   */
  path: string;
  /**
   * content JSON 字符串。
   */
  contentJson: string;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
  /**
   * active 值，由当前实例内部维护。
   */
  active: boolean;
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
 * 描述主题持久化或内存索引中的一条记录。
 */
export interface ThemeStateRecord {
  /**
   * active Theme 名称。
   */
  activeThemeName: string;
  /**
   * active Background 值，由当前实例内部维护。
   */
  activeBackground: string;
}

/**
 * 描述主题模块在运行时交换的数据结构。
 */
export interface ThemeExportData {
  /**
   * themes 列表，由当前实例内部维护。
   */
  themes: Array<ThemeRecord>;
  /**
   * state 值，由当前实例内部维护。
   */
  state: ThemeStateRecord;
}

/**
 * 描述主题事件发布时携带的数据结构。
 */
export interface ThemeActivatedPayload {
  /**
   * theme 名称。
   */
  themeName: string;
  /**
   * theme 值，由当前实例内部维护。
   */
  theme: ThemeRecord;
}

/**
 * 描述主题事件发布时携带的数据结构。
 */
export interface ThemeSavedPayload {
  /**
   * theme 值，由当前实例内部维护。
   */
  theme: ThemeRecord;
}

/**
 * 描述主题事件发布时携带的数据结构。
 */
export interface ThemeDeletedPayload {
  /**
   * theme 名称。
   */
  themeName: string;
}

/**
 * 描述主题事件发布时携带的数据结构。
 */
export interface ThemeBackgroundChangedPayload {
  /**
   * background 值，由当前实例内部维护。
   */
  background: string;
}
