import { describe, it, expect } from '@ohos/hypium';
import {
  AppRuntime,
  EventBus,
  InMemoryFileStore,
  LifecycleRuntime,
  type LifecycleStartupResult,
  type RuntimeEvent,
  type RuntimeManifest,
  type RuntimeSignalPayload,
  type RuntimeStateRecord,
  type TavernFileStore,
} from '../../Index';

export default function lifecycleUnitTest() {
  describe('lifecycle runtime', () => {
    it('initializes manifest and runtime state in global mode', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const events = new EventBus();
      const app = new AppRuntime(files);
      // 运行时实例。
      const runtime = new LifecycleRuntime(files, events, app);
      const signals = new Array<string>();
      events.subscribe<RuntimeSignalPayload>('runtime.signal', (event: RuntimeEvent<RuntimeSignalPayload>) => {
        signals.push(event.payload.signal);
      });
      const state = await runtime.initialize(true);
      const manifest: RuntimeManifest = await app.loadManifest();
      const savedState: RuntimeStateRecord = await app.loadRuntimeState();

      expect(await files.exists('tavern-data/app/manifest.json')).assertTrue();
      expect(await files.exists('tavern-data/app/runtime-state.json')).assertTrue();
      expect(manifest.globalMode).assertTrue();
      expect(state.phase).assertEqual('init');
      expect(savedState.globalMode).assertTrue();
      expect(signals[0]).assertEqual('runtime.init');
    });

    it('marks the runtime ready and persists the last lifecycle signal', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const events = new EventBus();
      const app = new AppRuntime(files);
      // 运行时实例。
      const runtime = new LifecycleRuntime(files, events, app);

      await runtime.initialize(false);
      const readyState = await runtime.markReady();
      const savedState: RuntimeStateRecord = await app.loadRuntimeState();

      expect(readyState.ready).assertTrue();
      expect(readyState.phase).assertEqual('ready');
      expect(savedState.lastSignal).assertEqual('runtime.ready');
      expect(savedState.globalMode).assertFalse();
    });

    it('runs startup flow with migration and process restore markers', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const events = new EventBus();
      const app = new AppRuntime(files);
      // 运行时实例。
      const runtime = new LifecycleRuntime(files, events, app);
      const result: LifecycleStartupResult = await runtime.runStartup({
        globalMode: true,
        processRestored: true,
        migrationVersion: '2026.06.startup',
      });
      const savedState: RuntimeStateRecord = await app.loadRuntimeState();

      expect(result.phases.length).assertEqual(4);
      expect(result.phases[0]).assertEqual('runtime.init');
      expect(result.phases[1]).assertEqual('runtime.migrate');
      expect(result.phases[2]).assertEqual('process.restored');
      expect(result.phases[3]).assertEqual('runtime.ready');
      expect(savedState.lastSignal).assertEqual('runtime.ready');
      expect(savedState.globalMode).assertTrue();
      expect(savedState.migrationVersion).assertEqual('2026.06.startup');
      expect(savedState.restored).assertTrue();
    });
  });
}
