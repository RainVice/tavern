import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type { RuntimeManifest, RuntimeStateRecord } from './AppModels';

/**
 * 提供应用运行状态相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class AppRuntime {
  /**
   * manifest Store 值，由当前实例内部维护。
   */
  private manifestStore: JsonStore<RuntimeManifest>;
  /**
   * state Store 值，由当前实例内部维护。
   */
  private stateStore: JsonStore<RuntimeStateRecord>;

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param rootPath 数据根路径。
   */
  constructor(files: TavernFileStore, rootPath: string = 'tavern-data') {
    this.manifestStore = new JsonStore<RuntimeManifest>(files, `${rootPath}/app/manifest.json`);
    this.stateStore = new JsonStore<RuntimeStateRecord>(files, `${rootPath}/app/runtime-state.json`);
  }

  /**
   * 读取或解析Manifest，调用方应处理不存在或不匹配的情况。
   */
  async loadManifest(): Promise<RuntimeManifest> {
    return this.manifestStore.read(this.defaultManifest());
  }

  /**
   * 创建或写入Manifest，完成持久化后返回可供调用方使用的结果。

   * @returns 条件命中时返回 true，否则返回 false。
   */
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

  /**
   * 读取或解析状态，调用方应处理不存在或不匹配的情况。
   */
  async loadRuntimeState(): Promise<RuntimeStateRecord> {
    return this.stateStore.read(this.defaultState());
  }

  /**
   * 创建或写入状态，完成持久化后返回可供调用方使用的结果。




   * @returns 条件命中时返回 true，否则返回 false。
   */
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

  /**
   * 创建或写入状态，完成持久化后返回可供调用方使用的结果。
   */
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
