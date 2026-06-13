export interface WorldBook {
  schemaVersion: number;
  id: string;
  name: string;
  nextEntryId: number;
  entries: Array<WorldInfoEntry>;
  createdAt: number;
  updatedAt: number;
}

export interface WorldBookIndex {
  schemaVersion: number;
  nextId: number;
  items: Array<WorldBookIndexEntry>;
}

export interface WorldBookIndexEntry {
  id: string;
  name: string;
  entryCount: number;
  createdAt: number;
  updatedAt: number;
}

export interface WorldInfoEntryCreateParams {
  comment: string;
  keys: Array<string>;
  secondaryKeys: Array<string>;
  content: string;
  constant: boolean;
  selective: boolean;
  enabled: boolean;
  insertionOrder: number;
  position: string;
  caseSensitive: boolean;
}

export interface WorldInfoEntryUpdateParams {
  comment: string;
  keys: Array<string>;
  secondaryKeys: Array<string>;
  content: string;
  constant: boolean;
  selective: boolean;
  enabled: boolean;
  insertionOrder: number;
  position: string;
  caseSensitive: boolean;
}

export interface WorldInfoEntry {
  id: string;
  uid: number;
  comment: string;
  keys: Array<string>;
  secondaryKeys: Array<string>;
  content: string;
  constant: boolean;
  selective: boolean;
  enabled: boolean;
  insertionOrder: number;
  position: string;
  caseSensitive: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface WorldInfoActivation {
  entries: Array<WorldInfoEntry>;
  matches: Array<WorldInfoMatch>;
  promptText: string;
}

export interface WorldInfoMatch {
  worldBookId: string;
  entryId: string;
  key: string;
}

export interface WorldInfoActivationPayload {
  worldBookIds: Array<string>;
  entries: Array<WorldInfoEntry>;
  matches: Array<WorldInfoMatch>;
}

export interface WorldInfoImportData {
  schemaVersion: number;
  id: string;
  name: string;
  nextEntryId: number;
  entries: Array<WorldInfoEntry>;
  createdAt: number;
  updatedAt: number;
}

export interface WorldInfoEventPayload {
  worldBook: WorldBook;
}
