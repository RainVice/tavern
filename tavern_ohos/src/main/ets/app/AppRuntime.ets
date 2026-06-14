import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type { RuntimeManifest, RuntimeStateRecord } from './AppModels';

/**
 * 提供应用运行状态相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class AppRuntime {
  /**
   * 持久化 manifest 数据的 JSON 存储实例，文件路径为 {rootPath}/app/manifest.json。
   */
  private manifestStore: JsonStore<RuntimeManifest>;
  /**
   * 持久化运行时状态记录的 JSON 存储实例，文件路径为 {rootPath}/app/runtime-state.json。
   */
  private stateStore: JsonStore<RuntimeStateRecord>;

  /**
   * 初始化当前运行时实例，创建 manifest 和 runtime-state 两个 JSON 存储实例。
   * @param files TavernFileStore 文件存储适配器，提供底层文件读写能力。
   * @param rootPath 数据根路径，默认为 "tavern-data"，用于拼接存储文件的目录前缀。
   */
  constructor(files: TavernFileStore, rootPath: string = 'tavern-data') {
    this.manifestStore = new JsonStore<RuntimeManifest>(files, `${rootPath}/app/manifest.json`);
    this.stateStore = new JsonStore<RuntimeStateRecord>(files, `${rootPath}/app/runtime-state.json`);
  }

  /**
   * 读取或解析 Manifest，调用方应处理不存在或不匹配的情况。
   * @returns 解析后的完整 manifest 对象，文件不存在时返回默认值。
   */
  async loadManifest(): Promise<RuntimeManifest> {
    return this.manifestStore.read(this.defaultManifest());
  }

  /**
   * 创建或写入 Manifest，完成持久化后返回可供调用方使用的结果。
   * @param globalMode 要写入的全局模式值，覆盖当前 manifest 中的 globalMode 字段。
   * @returns 写入持久化后的完整 manifest 对象副本，包含自动填充的时间戳和 schema 版本。
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
   * @returns 解析后的状态记录对象，文件不存在时返回默认状态。
   */
  async loadRuntimeState(): Promise<RuntimeStateRecord> {
    return this.stateStore.read(this.defaultState());
  }

  /**
   * 创建或写入运行时状态，完成持久化后返回可供调用方使用的结果。
   * @param phase 要设置的生命周期阶段名称（如 "created"、"ready"）。
   * @param ready 是否标记为就绪状态。
   * @param globalMode 全局模式值，同步写入状态记录。
   * @param lastSignal 最近一次信号标识，用于追踪驱动来源。
   * @returns 写入持久化后的完整状态记录副本，包含 schemaVersion 和时间戳。
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
   * 创建或写入完整的运行时状态，支持手动指定所有状态字段，完成持久化后返回状态副本。
   * @param phase 要设置的生命周期阶段名称（如 "created"、"ready"）。
   * @param ready 是否标记为就绪状态。
   * @param globalMode 全局模式值，同步写入状态记录。
   * @param lastSignal 最近一次信号标识，用于追踪驱动来源。
   * @param migrationVersion 迁移版本号，用于记录数据迁移进度。
   * @param restored 是否已完成恢复标记。
   * @returns 写入持久化后的完整状态记录副本，包含 schemaVersion 和时间戳。
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
