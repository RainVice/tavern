import { AppRuntime } from '../app/AppRuntime';
import type { LifecycleStartupOptions, LifecycleStartupResult, RuntimeStateRecord } from '../app/AppModels';
import { EventRuntime } from '../event/EventRuntime';
import { EventBus } from '../runtime/EventBus';
import type { TavernFileStore } from '../storage/TavernFileStore';

/**
 * 提供生命周期相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在 Tavern 启动流程中按 init -> migrate -> restore -> ready 顺序编排各阶段，
 * 每个阶段都会将运行时状态持久化到文件存储并通过事件总线通知其他模块。
 */
export class LifecycleRuntime {
  /**
   * 应用运行时实例，提供 manifest 和运行时状态的管理能力。
   */
  private app: AppRuntime;
  /**
   * 事件总线。
   */
  private events: EventRuntime;
  /**
   * 注入生命周期运行时依赖并初始化实例状态。
   * 由 Tavern 主容器在应用启动时创建 LifecycleRuntime 实例时调用。
   * @param files 用于持久化生命周期状态的文件存储适配器，在 markReady / initialize 中将运行时状态写入文件。
   * @param eventBus 用于发布生命周期状态变更事件的事件总线，各阶段完成后通过 EventRuntime 发送 runtime.init/runtime.ready 等信号。
   * @param app 应用运行时实例，提供 manifest 和运行时状态管理能力，各阶段的状态读写均委托给此实例。
   * @param rootPath Tavern 数据在文件系统中的根目录路径，用于确定生命周期状态文件的存储位置。
   */
  constructor(_files: TavernFileStore, eventBus: EventBus, app: AppRuntime, _rootPath: string = 'tavern-data') {
    this.app = app;
    this.events = new EventRuntime(eventBus);
  }

  /**
   * 执行应用初始化流程，保存 manifest 和运行时状态，并发布初始化完成事件。
   * 在 runStartup 中被调用，是启动流程的第一个阶段。
   * @param globalMode 是否以全局模式初始化。为 true 时保存到全局路径，影响后续所有模块读取状态的文件位置；为 false 时保存到用户路径。
   * @returns 包含迁移版本号、就绪标志等信息的运行时状态记录，供 runStartup 检查是否需要执行后续阶段。
   */
  async initialize(globalMode: boolean): Promise<RuntimeStateRecord> {
    await this.app.saveManifest(globalMode);
    const state = await this.app.saveRuntimeState('init', false, globalMode, 'runtime.init');
    this.events.emitRuntimeSignal('runtime.init', 'lifecycle initialized');
    return state;
  }

  /**
   * 更新 Ready 状态，将运行时状态标记为就绪并持久化到文件存储，同时发布 runtime.ready 事件。
   * 在 runStartup 的最后阶段被调用，标识整个启动流程（init -> migrate -> restore）已全部完成，
   * 此时其他模块可以安全地使用已恢复的数据。
   * @returns 包含就绪标志为 true 的运行时状态记录。
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
   * 执行启动流程，按顺序执行初始化、迁移、恢复和就绪阶段，返回各阶段结果。
   * 由 Tavern 主容器在应用启动时调用，是生命周期管理的入口方法。
   * 流程说明：
   *   1. initialize(globalMode) —— 保存 manifest 和初始状态，发布 runtime.init。
   *   2. 若 migrationVersion 非空 —— 执行迁移阶段，更新状态为 migrating，发布 runtime.migrate。
   *   3. 若 processRestored 为 true —— 执行恢复阶段，更新状态为 restored，发布 process.restored。
   *   4. markReady() —— 标记为就绪，发布 runtime.ready。
   * @param options 控制启动流程的选项，包含全局模式、迁移版本号、是否恢复等设置，调用方根据应用当前状态决定各阶段是否执行。
   * @returns 包含所有已执行阶段名称和最终运行时状态的结果对象，调用方可通过 phases 数组了解实际执行的流程范围。
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
