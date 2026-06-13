import { EventBus } from '../runtime/EventBus';
import type { RecoveryAttemptedPayload, RecoveryMetadata, RecoveryResult, RecoverySnapshot, RecoveryType } from './RecoveryModels';

export class RecoveryRuntime {
  private events: EventBus; private snapshots: Array<RecoverySnapshot>=[];
  constructor(events: EventBus) { this.events=events; }

  createSnapshot(type: RecoveryType, metadata: RecoveryMetadata): RecoverySnapshot {
    const snap: RecoverySnapshot = { type: type, metadata: this.copyMetadata(metadata), timestamp: Date.now() };
    this.snapshots.push(this.copySnapshot(snap)); return this.copySnapshot(snap);
  }

  getLatestSnapshot(type: RecoveryType): RecoverySnapshot|undefined {
    for (let i=this.snapshots.length-1;i>=0;i--) { if (this.snapshots[i].type===type) return this.copySnapshot(this.snapshots[i]); }
    return undefined;
  }

  attemptRecovery(type: RecoveryType): RecoveryResult {
    const snap = this.getLatestSnapshot(type);
    const result: RecoveryResult = {
      success: snap!==undefined, type,
      message: snap!==undefined ? `从快照恢复成功 (${snap.metadata.source||'unknown'})` : '无可恢复的快照',
    };
    this.events.publish<RecoveryAttemptedPayload>('recovery.attempted', { result: this.copyResult(result) });
    return this.copyResult(result);
  }

  listSnapshots(): Array<RecoverySnapshot> {
    const result = new Array<RecoverySnapshot>();
    for (let index = 0; index < this.snapshots.length; index += 1) {
      result.push(this.copySnapshot(this.snapshots[index]));
    }
    return result;
  }

  private copySnapshot(snapshot: RecoverySnapshot): RecoverySnapshot {
    return {
      type: snapshot.type,
      metadata: this.copyMetadata(snapshot.metadata),
      timestamp: snapshot.timestamp,
    };
  }

  private copyMetadata(metadata: RecoveryMetadata): RecoveryMetadata {
    return {
      source: metadata.source,
      chatId: metadata.chatId,
      messageId: metadata.messageId,
      reason: metadata.reason,
    };
  }

  private copyResult(result: RecoveryResult): RecoveryResult {
    return {
      success: result.success,
      type: result.type,
      message: result.message,
    };
  }
}
