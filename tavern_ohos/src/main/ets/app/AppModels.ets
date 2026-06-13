export interface RuntimeManifest {
  schemaVersion: number;
  runtime: string;
  globalMode: boolean;
  initializedAt: number;
  updatedAt: number;
}

export interface RuntimeStateRecord {
  schemaVersion: number;
  phase: string;
  ready: boolean;
  globalMode: boolean;
  lastSignal: string;
  migrationVersion: string;
  restored: boolean;
  updatedAt: number;
}

export interface LifecycleStartupOptions {
  globalMode: boolean;
  processRestored: boolean;
  migrationVersion: string;
}

export interface LifecycleStartupResult {
  phases: Array<string>;
  state: RuntimeStateRecord;
}
