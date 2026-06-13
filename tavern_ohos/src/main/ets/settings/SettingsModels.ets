export interface SettingSchemaCreateParams {
  key: string;
  defaultValue: string;
  valueType: string;
  schemaVersion: number;
  description: string;
}

export interface SettingSchemaRecord {
  key: string;
  defaultValue: string;
  valueType: string;
  schemaVersion: number;
  description: string;
}

export interface SettingEntry {
  scope: string;
  scopeId: string;
  key: string;
  value: string;
  schemaVersion: number;
  updatedAt: number;
}

export interface SettingChangedPayload {
  scope: string;
  scopeId: string;
  key: string;
  oldValue: string;
  newValue: string;
  schemaVersion: number;
}

export interface SettingMigrationRecord {
  scope: string;
  scopeId: string;
  fromKey: string;
  toKey: string;
  fromVersion: number;
  toVersion: number;
  migratedAt: number;
}

export interface SettingSnapshot {
  schemaVersion: number;
  entries: Array<SettingEntry>;
  migrationMetadata: Array<SettingMigrationRecord>;
}
