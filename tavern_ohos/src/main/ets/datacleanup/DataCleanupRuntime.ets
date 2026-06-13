import { EventBus } from '../runtime/EventBus';
import type { CleanupCompletedPayload, CleanupReport, CleanupResult, CleanupStats } from './DataCleanupModels';

export class DataCleanupRuntime {
  private events: EventBus; private orphanFiles: Array<string>=new Array(); private corruptIndexes: Array<string>=new Array();
  constructor(events: EventBus) { this.events=events; }

  registerOrphanFile(path: string): void { this.orphanFiles.push(path); }
  registerCorruptIndex(path: string): void { this.corruptIndexes.push(path); }

  runCleanup(): CleanupResult {
    const report: CleanupReport = {
      orphanFiles: this.orphanFiles.slice(), corruptIndexes: this.corruptIndexes.slice(),
      staleTasks: new Array<string>(), totalRemoved: this.orphanFiles.length + this.corruptIndexes.length,
      errors: new Array<string>(),
    };
    this.orphanFiles = new Array<string>(); this.corruptIndexes = new Array<string>();
    this.events.publish<CleanupCompletedPayload>('datacleanup.completed', { report });
    return { report, success: true };
  }

  getStats(): CleanupStats {
    const stats: CleanupStats = { orphans: this.orphanFiles.length, corrupt: this.corruptIndexes.length };
    return stats;
  }
}
