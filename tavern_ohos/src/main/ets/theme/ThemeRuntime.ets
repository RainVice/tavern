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

export class ThemeRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private themes: Map<string, ThemeRecord> = new Map<string, ThemeRecord>();
  private activeThemeName: string = '';
  private activeBackground: string = '';
  private themeRootPath: string = 'tavern-data/users/default/assets/themes';
  private statePath: string = 'tavern-data/users/default/settings/theme-state.json';

  constructor(files: TavernFileStore, events: EventBus) {
    this.files = files;
    this.events = events;
  }

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

  async listThemes(): Promise<Array<ThemeRecord>> {
    const result = new Array<ThemeRecord>();
    this.themes.forEach((theme: ThemeRecord) => {
      result.push(this.copyTheme(theme));
    });
    result.sort((left: ThemeRecord, right: ThemeRecord) => left.name.localeCompare(right.name));
    return result;
  }

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

  getActiveThemeName(): string {
    return this.activeThemeName;
  }

  async setActiveBackground(background: string): Promise<void> {
    this.activeBackground = background;
    await this.persistState();
    const payload: ThemeBackgroundChangedPayload = {
      background: background,
    };
    this.events.publish<ThemeBackgroundChangedPayload>('theme.background.changed', payload);
  }

  getActiveBackground(): string {
    return this.activeBackground;
  }

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

  async exportThemes(): Promise<ThemeExportData> {
    return {
      themes: await this.listThemes(),
      state: this.copyState(),
    };
  }

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

  private copyState(): ThemeStateRecord {
    return {
      activeThemeName: this.activeThemeName,
      activeBackground: this.activeBackground,
    };
  }

  private themePath(name: string): string {
    return `${this.themeRootPath}/${safePathSegment(name, 'theme')}.json`;
  }

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
