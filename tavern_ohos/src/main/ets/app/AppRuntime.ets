import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type { RuntimeManifest, RuntimeStateRecord } from './AppModels';

export class AppRuntime {
  private manifestStore: JsonStore<RuntimeManifest>;
  private stateStore: JsonStore<RuntimeStateRecord>;

  constructor(files: TavernFileStore, rootPath: string = 'tavern-data') {
    this.manifestStore = new JsonStore<RuntimeManifest>(files, `${rootPath}/app/manifest.json`);
    this.stateStore = new JsonStore<RuntimeStateRecord>(files, `${rootPath}/app/runtime-state.json`);
  }

  async loadManifest(): Promise<RuntimeManifest> {
    return this.manifestStore.read(this.defaultManifest());
  }

  async saveManifest(globalMode: boolean): Promise<RuntimeManifest> {
    const current = await this.loadManifest();
    const now = Date.now();
    const manifest: RuntimeManifest = {
      schemaVersion: current.schemaVersion,
      runtime: current.runtime,
      globalMode: globalMode,
      initializedAt: current.initializedAt === 0 ? now : current.initializedAt,
      updatedAt: now,
    };
    await this.manifestStore.write(manifest);
    return manifest;
  }

  async loadRuntimeState(): Promise<RuntimeStateRecord> {
    return this.stateStore.read(this.defaultState());
  }

  async saveRuntimeState(phase: string, ready: boolean, globalMode: boolean, lastSignal: string): Promise<RuntimeStateRecord> {
    const current = await this.loadRuntimeState();
    const state: RuntimeStateRecord = {
      schemaVersion: 1,
      phase: phase,
      ready: ready,
      globalMode: globalMode,
      lastSignal: lastSignal,
      migrationVersion: current.migrationVersion,
      restored: current.restored,
      updatedAt: Date.now(),
    };
    await this.stateStore.write(state);
    return state;
  }

  async saveDetailedRuntimeState(
    phase: string,
    ready: boolean,
    globalMode: boolean,
    lastSignal: string,
    migrationVersion: string,
    restored: boolean,
  ): Promise<RuntimeStateRecord> {
    const state: RuntimeStateRecord = {
      schemaVersion: 1,
      phase: phase,
      ready: ready,
      globalMode: globalMode,
      lastSignal: lastSignal,
      migrationVersion: migrationVersion,
      restored: restored,
      updatedAt: Date.now(),
    };
    await this.stateStore.write(state);
    return state;
  }

  private defaultManifest(): RuntimeManifest {
    return {
      schemaVersion: 1,
      runtime: 'tavern_ohos',
      globalMode: false,
      initializedAt: 0,
      updatedAt: 0,
    };
  }

  private defaultState(): RuntimeStateRecord {
    return {
      schemaVersion: 1,
      phase: 'created',
      ready: false,
      globalMode: false,
      lastSignal: '',
      migrationVersion: '',
      restored: false,
      updatedAt: 0,
    };
  }
}
