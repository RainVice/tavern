import { AppRuntime } from '../app/AppRuntime';
import type { LifecycleStartupOptions, LifecycleStartupResult, RuntimeStateRecord } from '../app/AppModels';
import { EventRuntime } from '../event/EventRuntime';
import { EventBus } from '../runtime/EventBus';
import type { TavernFileStore } from '../storage/TavernFileStore';

/**
 * 提供生命周期相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class LifecycleRuntime {
  /**
   * app 值，由当前实例内部维护。
   */
  private app: AppRuntime;
  /**
   * 事件总线。
   */
  private events: EventRuntime;
  /**
   * 注入生命周期运行时依赖并初始化实例状态。
   * @param files 文件存储适配器。
   * @param eventBus 事件总线。

   * @param rootPath Tavern 数据根路径。
   */
  constructor(_files: TavernFileStore, eventBus: EventBus, app: AppRuntime, _rootPath: string = 'tavern-data') {
    this.app = app;
    this.events = new EventRuntime(eventBus);
  }

  /**
   * 执行 initialize 的内部处理步骤，供当前模块复用。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  async initialize(globalMode: boolean): Promise<RuntimeStateRecord> {
    await this.app.saveManifest(globalMode);
    const state = await this.app.saveRuntimeState('init', false, globalMode, 'runtime.init');
    this.events.emitRuntimeSignal('runtime.init', 'lifecycle initialized');
    return state;
  }

  /**
   * 更新Ready状态，必要时写回存储并发布对应事件。
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
   * 执行 runStartup 的内部处理步骤，供当前模块复用。
   * @param options 控制本次调用行为的选项。
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
