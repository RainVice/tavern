import { AppRuntime } from '../app/AppRuntime';
import type { LifecycleStartupOptions, LifecycleStartupResult, RuntimeStateRecord } from '../app/AppModels';
import { EventRuntime } from '../event/EventRuntime';
import { EventBus } from '../runtime/EventBus';
import type { TavernFileStore } from '../storage/TavernFileStore';

export class LifecycleRuntime {
  private files: TavernFileStore;
  private app: AppRuntime;
  private events: EventRuntime;
  private rootPath: string;

  constructor(files: TavernFileStore, eventBus: EventBus, app: AppRuntime, rootPath: string = 'tavern-data') {
    this.files = files;
    this.app = app;
    this.events = new EventRuntime(eventBus);
    this.rootPath = rootPath;
  }

  async initialize(globalMode: boolean): Promise<RuntimeStateRecord> {
    await this.files.ensureTavernDataLayout(this.rootPath);
    await this.app.saveManifest(globalMode);
    const state = await this.app.saveRuntimeState('init', false, globalMode, 'runtime.init');
    this.events.emitRuntimeSignal('runtime.init', 'lifecycle initialized');
    return state;
  }

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
