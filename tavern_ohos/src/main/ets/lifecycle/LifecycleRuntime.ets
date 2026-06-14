import { AppRuntime } from '../app/AppRuntime';
import type { LifecycleStartupOptions, LifecycleStartupResult, RuntimeStateRecord } from '../app/AppModels';
import { EventRuntime } from '../event/EventRuntime';
import { EventBus } from '../runtime/EventBus';
import type { TavernFileStore } from '../storage/TavernFileStore';

/**
 * 生命周期运行时，编排 initialize → (migrate) → (restore) → markReady 的启动流程，
 * 并管理运行时状态的持久化与生命周期事件发布。
 */
export class LifecycleRuntime {
  /**
   * AppRuntime 实例，负责 manifest 与运行时状态的读写。
   */
  private app: AppRuntime;
  /**
   * EventRuntime 实例，负责运行时生命周期信号的发布。
   */
  private events: EventRuntime;

  /**
   * 注入生命周期运行时依赖，初始化与 AppRuntime 的绑定和事件运行时实例。
   * @param files 文件存储适配器，用于底层文件读写。
   * @param eventBus 事件总线实例，供 EventRuntime 订阅与发布事件。
   * @param app 应用运行时实例，负责状态的持久化和读取。
   * @param _rootPath Tavern 数据根路径，暂未使用，保留接口兼容性。
   */
  constructor(_files: TavernFileStore, eventBus: EventBus, app: AppRuntime, _rootPath: string = 'tavern-data') {
    this.app = app;
    this.events = new EventRuntime(eventBus);
  }

  /**
   * 执行初始化流程：持久化 manifest、写入 ''init'' 阶段状态并发布 runtime.init 信号。
   * @param globalMode 是否启用全局模式，传入 saveManifest 和 saveRuntimeState。
   * @returns 写入持久化后的运行时状态快照。
   */
  async initialize(globalMode: boolean): Promise<RuntimeStateRecord> {
    await this.app.saveManifest(globalMode);
    const state = await this.app.saveRuntimeState('init', false, globalMode, 'runtime.init');
    this.events.emitRuntimeSignal('runtime.init', 'lifecycle initialized');
    return state;
  }

  /**
   * 标记运行时为就绪状态：写入 ready 阶段并发布 runtime.ready 信号。
   * @returns 写入持久化后的运行时状态快照。
   */
  async markReady(): Promise<RuntimeStateRecord> {
    const current = await this.app.loadRuntimeState();
    const state = await this.app.saveDetailedRuntimeState(
      'ready',
      true,
      current.globalMode,
      'runtime.ready',
      current.migrationVersion,
      current.restored,
    );
    this.events.emitRuntimeSignal('runtime.ready', 'lifecycle ready');
    return state;
  }

  /**
   * 执行完整的启动流程，按需经过 initialize → migrate → restore → ready 四个阶段。
   * @param options 启动选项，控制全局模式、迁移版本和恢复行为。
   * @returns 包含已执行阶段列表和最终运行时状态快照的结果对象。
   */
  async runStartup(options: LifecycleStartupOptions): Promise<LifecycleStartupResult> {
    const phases = new Array<string>();
    await this.initialize(options.globalMode);
    phases.push('runtime.init');
    let state = await this.app.loadRuntimeState();
    if (options.migrationVersion.length > 0) {
      state = await this.app.saveDetailedRuntimeState(
        'migrating',
        false,
        options.globalMode,
        'runtime.migrate',
        options.migrationVersion,
        false,
      );
      this.events.emitRuntimeSignal('runtime.migrate', options.migrationVersion);
      phases.push('runtime.migrate');
    }

    if (options.processRestored) {
      state = await this.app.saveDetailedRuntimeState(
        'restored',
        false,
        options.globalMode,
        'process.restored',
        options.migrationVersion.length > 0 ? options.migrationVersion : state.migrationVersion,
        true,
      );
      this.events.emitRuntimeSignal('process.restored', 'runtime state restored');
      phases.push('process.restored');
    }

    state = await this.markReady();
    phases.push('runtime.ready');
    return {
      phases: phases,
      state: state,
    };
  }
}
