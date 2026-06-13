export interface PresetField {
  name: string;
  value: string;
  valueType: string;
}

export interface PresetCreateParams {
  id: string;
  name: string;
  kind: string;
  enabled: boolean;
  version: number;
  fields: Array<PresetField>;
  migratedFrom: string;
}

export interface PresetUpdateParams {
  name: string;
  enabled: boolean;
  version: number;
  fields: Array<PresetField>;
  migratedFrom: string;
}

export interface PresetRecord {
  id: string;
  name: string;
  kind: string;
  enabled: boolean;
  version: number;
  fields: Array<PresetField>;
  migratedFrom: string;
}

export interface PresetBindingRecord {
  ownerType: string;
  ownerId: string;
  presetKind: string;
  presetId: string;
}

export interface PresetExportData {
  preset: PresetRecord;
}

export interface PresetEventPayload {
  preset: PresetRecord;
}

export interface PresetDeletedPayload {
  presetId: string;
  kind: string;
}

export interface PresetBoundPayload {
  binding: PresetBindingRecord;
}

export interface PresetMigratedPayload {
  preset: PresetRecord;
  fromVersion: number;
  toVersion: number;
}
