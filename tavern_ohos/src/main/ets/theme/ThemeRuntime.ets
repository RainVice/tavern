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
 */
export class ThemeRuntime {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 主题记录映射表，以主题名称为键维护所有已注册主题的内存索引。
   */
  private themes: Map<string, ThemeRecord> = new Map<string, ThemeRecord>();
  /**
   * 当前活跃主题的名称，为空时表示未激活任何主题。
   */
  private activeThemeName: string = '';
  /**
   * 当前选中的背景标识或路径，界面据此渲染背景图。
   */
  private activeBackground: string = '';
  /**
   * theme Root 路径。
   */
  private themeRootPath: string = 'tavern-data/users/default/assets/themes';
  /**
   * state 路径。
   */
  private statePath: string = 'tavern-data/users/default/settings/theme-state.json';

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param events 事件总线。
   */
  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

  /**
   * 创建或写入主题，持久化到文件并发布保存事件。
   * @param params 保存主题所需的参数。
   * @returns 保存后的主题记录副本。
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
   * 列出所有主题记录，返回按名称排序的副本。
   * @returns 所有主题记录列表副本。
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
   * 激活指定名称的主题，更新内部状态、持久化并发布激活事件。
   * @param name 主题名称。
   * @returns 激活后的主题记录副本。
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
   * 读取当前活跃主题的名称。
   * @returns 当前活跃主题名称字符串，可能为空字符串。
   */
  getActiveThemeName(): string {
    return this.activeThemeName;
  }

  /**
   * 设置当前背景，持久化状态并发布背景变更事件。
   * @param background 背景标识或路径。
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
   * 读取当前背景标识。
   * @returns 当前背景字符串。
   */
  getActiveBackground(): string {
    return this.activeBackground;
  }

  /**
   * 删除指定主题，清理文件和相关索引。
   * @param name 主题名称。
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
   * 导出主题列表及状态，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 包含主题列表和状态的导出数据。
   */
  async exportThemes(): Promise<ThemeExportData> {
    return {
      themes: await this.listThemes(),
      state: this.copyState(),
    };
  }

  /**
   * 从外部数据导入主题列表，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   * @param replace 是否先清空当前主题列表再导入。
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
   * 读取必须存在的Theme 值，缺失时抛出错误。
   * @param name 显示名称或注册名称。
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
   * 复制State 值，避免外部修改内部状态。
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
   * 复制Theme 值，避免外部修改内部状态。
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
