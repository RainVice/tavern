export interface CleanupReport { orphanFiles: Array<string>; corruptIndexes: Array<string>;
  staleTasks: Array<string>; totalRemoved: number; errors: Array<string>; }
export interface CleanupResult { report: CleanupReport; success: boolean; }
export interface CleanupCompletedPayload { report: CleanupReport; }
export interface CleanupStats { orphans: number; corrupt: number; }
