/**
 * 描述调用主题能力时需要传入的参数。
 * 在保存主题时传入，包含主题的名称、样式配置和元数据。
 */
export interface ThemeSaveParams {
  /**
   * 主题名称，用于在 ThemeRuntime 中唯一标识一个主题记录。
   */
  name: string;
  /**
   * 主题样式配置的 JSON 字符串，包含 UI 组件的颜色、字体、间距等样式定义。
   */
  contentJson: string;
  /**
   * 主题元数据的 JSON 字符串，包含版本、作者、描述等非样式信息。
   */
  metadataJson: string;
}

/**
 * 描述主题持久化或内存索引中的一条记录。
 * 在主题管理流程中，用于存储和管理 UI 主题的完整信息。
 */
export interface ThemeRecord {
  /**
   * 主题 schema 版本号，用于数据迁移和兼容性判断。
   */
  schemaVersion: number;
  /**
   * 主题名称，在 ThemeRuntime 中作为唯一标识和查找键。
   */
  name: string;
  /**
   * 主题文件存储路径，保存主题样式配置的 JSON 文件位置。
   */
  path: string;
  /**
   * 主题样式配置的 JSON 字符串，直接写入文件的内容。
   */
  contentJson: string;
  /**
   * 主题元数据的 JSON 字符串。
   */
  metadataJson: string;
  /**
   * 是否为当前激活的主题，由 activateTheme 设置，用于 UI 标记当前使用的主题。
   */
  active: boolean;
  /**
   * 创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 最近更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述主题持久化或内存索引中的一条记录。
 * 用于记录当前主题状态（激活主题和背景），在应用启动时从文件还原。
 */
export interface ThemeStateRecord {
  /**
   * 当前激活的主题名称，用于应用启动时自动恢复主题样式。
   */
  activeThemeName: string;
  /**
   * 当前激活的背景图片标识，用于应用启动时自动恢复背景。
   */
  activeBackground: string;
}

/**
 * 描述主题导出数据的结构，用于备份和迁移。
 * 在导入/导出主题配置时使用，包含所有主题记录和当前状态。
 */
export interface ThemeExportData {
  /**
   * 所有主题记录的列表。
   */
  themes: Array<ThemeRecord>;
  /**
   * 主题状态记录。
   */
  state: ThemeStateRecord;
}

/**
 * 描述主题激活事件发布时携带的数据结构。
 * ThemeRuntime 在 activateTheme 后发布 theme.activated 事件，通知宿主 UI 刷新主题样式。
 */
export interface ThemeActivatedPayload {
  /**
   * 被激活的主题名称。
   */
  themeName: string;
  /**
   * 激活的主题记录。
   */
  theme: ThemeRecord;
}

/**
 * 描述主题事件发布时携带的数据结构。
 * ThemeRuntime 在 saveTheme 后发布 theme.saved 事件，通知宿主 UI 主题列表已更新。
 */
export interface ThemeSavedPayload {
  /**
   * 已保存的主题记录。
   */
  theme: ThemeRecord;
}

/**
 * 描述主题删除事件发布时携带的数据结构。
 * ThemeRuntime 在 deleteTheme 后发布 theme.deleted 事件，通知宿主 UI 移除对应主题。
 */
export interface ThemeDeletedPayload {
  /**
   * 被删除的主题名称。
   */
  themeName: string;
}

/**
 * 描述主题背景变更事件发布时携带的数据结构。
 * ThemeRuntime 在 setActiveBackground 后发布 theme.background.changed 事件，通知宿主 UI 更换背景。
 */
export interface ThemeBackgroundChangedPayload {
  /**
   * 新的背景标识。
   */
  background: string;
}
