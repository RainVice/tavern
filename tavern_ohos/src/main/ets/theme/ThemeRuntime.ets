import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  ThemeActivatedPayload,
  ThemeBackgroundChangedPayload,
  ThemeDeletedPayload,
  ThemeExportData,
  ThemeRecord,
  ThemeSaveParams,
  ThemeSavedPayload,
  ThemeStateRecord,
} from './ThemeModels';

/**
 * 提供主题相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在 UI 主题管理流程中，支持主题的创建、激活、删除、导入导出，以及背景图片的切换。
 */
export class ThemeRuntime {
  /**
   * 文件存储适配器实例，用于主题文件的读写操作。
   */
  private files: TavernFileStore;
  /**
   * 事件总线实例，用于发布主题变更事件。
   */
  private events: EventBus;
  /**
   * 按名称保存的主题记录映射表，是主题定义的核心存储。
   */
  private themes: Map<string, ThemeRecord> = new Map<string, ThemeRecord>();
  /**
   * 当前激活的主题名称，用于应用启动时自动恢复和 UI 标记。
   */
  private activeThemeName: string = '';
  /**
   * 当前激活的背景标识，用于 UI 背景展示。
   */
  private activeBackground: string = '';
  /**
   * 主题文件的存储根路径，用于主题 JSON 文件的读写定位。
   */
  private themeRootPath: string = 'tavern-data/users/default/assets/themes';
  /**
   * 主题状态文件的存储路径，用于持久化当前激活的主题和背景配置。
   */
  private statePath: string = 'tavern-data/users/default/settings/theme-state.json';

  /**
   * 初始化 ThemeRuntime 实例。
   * @param files 文件存储适配器。
   * @param events 事件总线实例。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 保存主题：写入内存映射和文件系统，发布 theme.saved 事件。
   * 在用户创建或编辑主题时由 UI 层调用。
   * @param params 主题保存参数（名称、内容 JSON、元数据 JSON）。
   * @returns 保存后的主题记录。
   */
  async saveTheme(params: ThemeSaveParams): Promise<ThemeRecord> {
    const now = Date.now();
    const existing = this.themes.get(params.name);
    const record: ThemeRecord = {
      schemaVersion: 1,
      name: params.name,
      path: this.themePath(params.name),
      contentJson: params.contentJson,
      metadataJson: params.metadataJson,
      active: this.activeThemeName === params.name,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.themes.set(record.name, this.copyTheme(record));
    await this.files.writeText(record.path, record.contentJson, true);
    await this.persistState();
    const payload: ThemeSavedPayload = {
      theme: this.copyTheme(record),
    };
    this.events.publish<ThemeSavedPayload>('theme.saved', payload);
    return this.copyTheme(record);
  }

  /**
   * 列出所有主题记录，按名称排序返回副本。
   * 在 UI 展示主题管理列表时调用。
   * @returns 主题记录副本数组。
   */
  async listThemes(): Promise<Array<ThemeRecord>> {
    const result = new Array<ThemeRecord>();
    this.themes.forEach((theme: ThemeRecord) => {
      result.push(this.copyTheme(theme));
    });
    result.sort((left: ThemeRecord, right: ThemeRecord) => left.name.localeCompare(right.name));
    return result;
  }

  /**
   * 激活指定名称的主题，更新所有主题的 active 标志并持久化状态。
   * 在用户选择主题时由 UI 层调用，触发宿主 UI 刷新样式。
   * @param name 要激活的主题名称。
   * @returns 激活后的主题记录。
   */
  async activateTheme(name: string): Promise<ThemeRecord> {
    this.requireTheme(name);
    this.activeThemeName = name;
    this.themes.forEach((theme: ThemeRecord, key: string) => {
      const updated = this.copyTheme(theme);
      updated.active = key === name;
      this.themes.set(key, updated);
    });
    await this.persistState();
    const active = this.requireTheme(name);
    const payload: ThemeActivatedPayload = {
      themeName: name,
      theme: this.copyTheme(active),
    };
    this.events.publish<ThemeActivatedPayload>('theme.activated', payload);
    return this.copyTheme(active);
  }

  /**
   * 获取当前激活的主题名称。
   * 在 UI 需要展示当前主题状态时调用。
   * @returns 当前激活的主题名称字符串。
   */
  getActiveThemeName(): string {
    return this.activeThemeName;
  }

  /**
   * 设置当前激活的背景标识，持久化状态并发布事件。
   * 在用户切换背景图片时由 UI 层调用。
   */
  async setActiveBackground(background: string): Promise<void> {
    this.activeBackground = background;
    await this.persistState();
    const payload: ThemeBackgroundChangedPayload = {
      background: background,
    };
    this.events.publish<ThemeBackgroundChangedPayload>('theme.background.changed', payload);
  }

  /**
   * 获取当前激活的背景标识。
   * @returns 当前背景标识字符串。
   */
  getActiveBackground(): string {
    return this.activeBackground;
  }

  /**
   * 删除指定名称的主题，清理文件并持久化状态。
   * 在用户删除主题时由 UI 层调用。
   * @param name 要删除的主题名称。
   */
  async deleteTheme(name: string): Promise<void> {
    const record = this.requireTheme(name);
    this.themes.delete(name);
    await this.files.delete(record.path);
    if (this.activeThemeName === name) {
      this.activeThemeName = '';
    }
    await this.persistState();
    const payload: ThemeDeletedPayload = {
      themeName: name,
    };
    this.events.publish<ThemeDeletedPayload>('theme.deleted', payload);
  }

  /**
   * 导出所有主题数据和状态，用于备份或迁移。
   * @returns 包含主题列表和状态的可序列化导出数据。
   */
  async exportThemes(): Promise<ThemeExportData> {
    return {
      themes: await this.listThemes(),
      state: this.copyState(),
    };
  }

  /**
   * 从外部数据导入主题列表。
   * 在从备份文件恢复或数据迁移时由宿主调用。
   * @param data 要导入的主题数据。
   * @param replace 是否替换现有全部主题（true 时清空现有数据）。
   */
  async importThemes(data: ThemeExportData, replace: boolean): Promise<void> {
    if (replace) {
      this.themes.clear();
      this.activeThemeName = '';
      this.activeBackground = '';
    }
    for (let index = 0; index < data.themes.length; index += 1) {
      const theme = this.copyTheme(data.themes[index]);
      theme.path = this.themePath(theme.name);
      this.themes.set(theme.name, this.copyTheme(theme));
      await this.files.writeText(theme.path, theme.contentJson, true);
    }
    this.activeThemeName = data.state.activeThemeName;
    this.activeBackground = data.state.activeBackground;
    if (this.activeThemeName.length > 0 && this.themes.get(this.activeThemeName) === undefined) {
      this.activeThemeName = '';
    }
    this.syncActiveFlags();
    await this.persistState();
  }

  /**
   * 确保指定主题存在，缺失时抛出错误。
   * @param name 主题名称。
   */
  private requireTheme(name: string): ThemeRecord {
    const record = this.themes.get(name);
    if (record === undefined) {
      throw new Error(`Theme not found: ${name}`);
    }
    return record;
  }
  private syncActiveFlags(): void {
    this.themes.forEach((theme: ThemeRecord, key: string) => {
      const updated = this.copyTheme(theme);
      updated.active = key === this.activeThemeName;
      this.themes.set(key, updated);
    });
  }
  private async persistState(): Promise<void> {
    const state = this.copyState();
    await this.files.writeText(this.statePath, JSON.stringify(state), true);
  }

  /**
   * 深度复制主题状态，防止外部代码修改内部状态。
   */
  private copyState(): ThemeStateRecord {
    return {
      activeThemeName: this.activeThemeName,
      activeBackground: this.activeBackground,
    };
  }
  private themePath(name: string): string {
    return `${this.themeRootPath}/${safePathSegment(name, 'theme')}.json`;
  }

  /**
   * 深度复制 ThemeRecord，防止外部代码修改内部状态。
   */
  private copyTheme(theme: ThemeRecord): ThemeRecord {
    return {
      schemaVersion: theme.schemaVersion,
      name: theme.name,
      path: theme.path,
      contentJson: theme.contentJson,
      metadataJson: theme.metadataJson,
      active: theme.active,
      createdAt: theme.createdAt,
      updatedAt: theme.updatedAt,
    };
  }
}
