import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type { RuntimeManifest, RuntimeStateRecord } from './AppModels';

/**
 * 提供应用运行状态相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布，
 * 用于在应用启动、状态恢复、生命周期管理及跨模块通信等流程中维护运行时的配置和阶段信息。
 */
export class AppRuntime {
  /**
   * 用于读写应用清单（manifest）的 JSON 存储实例，在应用启动和状态保存流程中负责持久化运行时配置。
   */
  private manifestStore: JsonStore<RuntimeManifest>;
  /**
   * 用于读写运行时状态（runtime-state）的 JSON 存储实例，在应用状态恢复和保存流程中负责持久化生命周期信息。
   */
  private stateStore: JsonStore<RuntimeStateRecord>;

  /**
   * 初始化当前运行时实例，在应用启动或模块加载时调用，建立与持久化存储的连接通道。
   * @param files 文件存储适配器，用于在启动、状态恢复和状态保存流程中读写清单及运行状态数据。
   * @param rootPath 数据存储的根路径，默认为 tavern-data，用于组织运行时文件的目录结构。
   */
  constructor(files: TavernFileStore, rootPath: string = 'tavern-data') {
    this.manifestStore = new JsonStore<RuntimeManifest>(files, `${rootPath}/app/manifest.json`);
    this.stateStore = new JsonStore<RuntimeStateRecord>(files, `${rootPath}/app/runtime-state.json`);
  }

  /**
   * 从持久化存储中读取应用清单（manifest），若文件不存在则使用默认值，
   * 用于在应用启动流程中获取运行时的全局配置信息。
   * @returns 解析后的 RuntimeManifest 对象。
   */
  async loadManifest(): Promise<RuntimeManifest> {
    return this.manifestStore.read(this.defaultManifest());
  }

  /**
   * 保存应用清单，更新 globalMode 并刷新时间戳，写回持久化存储，
   * 用于在全局模式切换或运行时配置变更时持久化当前状态。
   * @param globalMode 要设置的全局模式值，在调用方触发模式切换后写入 manifest 供下次启动读取。
   * @returns 写入后的完整 manifest 对象。
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
   * 从持久化存储中读取运行时状态，若文件不存在则使用默认值，
   * 用于在应用启动流程中恢复上一次的运行阶段和就绪状态。
   * @returns 解析后的 RuntimeStateRecord 对象。
   */
  async loadRuntimeState(): Promise<RuntimeStateRecord> {
    return this.stateStore.read(this.defaultState());
  }

  /**
   * 保存运行时状态（基础字段），写回持久化存储并返回完整记录，
   * 用于在生命周期阶段切换时及时持久化当前的运行阶段和就绪信息。
   * @param phase 当前生命周期阶段名称，在阶段切换流程中由调用方传入并持久化供下次启动恢复。
   * @param ready 运行时是否已就绪，影响外部模块在就绪检查流程中是否允许调用相关功能。
   * @param globalMode 全局模式状态，在状态保存时记录供下次启动恢复上下文隔离策略。
   * @param lastSignal 最近一次收到的信号标识，用于记录运行时收到的最后一条指令，便于状态恢复和调试。
   * @returns 写入后的完整状态记录。
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
   * 保存运行时状态（完整字段），写回持久化存储并返回完整记录，
   * 用于在数据迁移或状态恢复流程中持久化所有状态字段，比 saveRuntimeState 更完整地记录迁移和恢复信息。
   * @param phase 当前生命周期阶段名称，在阶段切换流程中传入。
   * @param ready 运行时是否已就绪，影响外部模块的就绪检查。
   * @param globalMode 全局模式状态。
   * @param lastSignal 最近一次收到的信号标识。
   * @param migrationVersion 数据迁移版本号，在数据升级流程中记录当前使用的迁移版本。
   * @param restored 是否从持久化存储中成功恢复状态，在状态恢复流程结束后标记恢复结果。
   * @returns 写入后的完整状态记录。
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
