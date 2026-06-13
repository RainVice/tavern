export interface ThemeSaveParams {
  name: string;
  contentJson: string;
  metadataJson: string;
}

export interface ThemeRecord {
  schemaVersion: number;
  name: string;
  path: string;
  contentJson: string;
  metadataJson: string;
  active: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface ThemeStateRecord {
  activeThemeName: string;
  activeBackground: string;
}

export interface ThemeExportData {
  themes: Array<ThemeRecord>;
  state: ThemeStateRecord;
}

export interface ThemeActivatedPayload {
  themeName: string;
  theme: ThemeRecord;
}

export interface ThemeSavedPayload {
  theme: ThemeRecord;
}

export interface ThemeDeletedPayload {
  themeName: string;
}

export interface ThemeBackgroundChangedPayload {
  background: string;
}
