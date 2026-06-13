import { EventBus } from '../runtime/EventBus';
import type { RecoveryAttemptedPayload, RecoveryMetadata, RecoveryResult, RecoverySnapshot, RecoveryType } from './RecoveryModels';

/**
 * 提供恢复快照相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class RecoveryRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private snapshots: Array<RecoverySnapshot>=[];
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 创建新的快照记录，写入存储并返回副本。


   * @returns 更新或读取后的记录副本。
   */
  createSnapshot(type: RecoveryType, metadata: RecoveryMetadata): RecoverySnapshot {
    const snap: RecoverySnapshot = { type: type, metadata: this.copyMetadata(metadata), timestamp: Date.now() };
    this.snapshots.push(this.copySnapshot(snap)); return this.copySnapshot(snap);
  }

  /**
   * 读取指定快照，不存在时抛出错误。

   * @returns 更新或读取后的记录副本。
   */
  getLatestSnapshot(type: RecoveryType): RecoverySnapshot|undefined {
    for (let i=this.snapshots.length-1;i>=0;i--) { if (this.snapshots[i].type===type) return this.copySnapshot(this.snapshots[i]); }
    return undefined;
  }

  /**
   * 执行 attemptRecovery 的内部处理步骤，供当前模块复用。
   */
  attemptRecovery(type: RecoveryType): RecoveryResult {
    const snap = this.getLatestSnapshot(type);
    const result: RecoveryResult = {
      success: snap!==undefined, type,
      message: snap!==undefined ? `从快照恢复成功 (${snap.metadata.source||'unknown'})` : '无可恢复的快照',
    };
    this.events.publish<RecoveryAttemptedPayload>('recovery.attempted', { result: this.copyResult(result) });
    return this.copyResult(result);
  }

  /**
   * 读取Snapshots列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listSnapshots(): Array<RecoverySnapshot> {
    const result = new Array<RecoverySnapshot>();
    for (let index = 0; index < this.snapshots.length; index += 1) {
      result.push(this.copySnapshot(this.snapshots[index]));
    }
    return result;
  }

  /**
   * 复制Snapshot 值，避免外部修改内部状态。
   */
  private copySnapshot(snapshot: RecoverySnapshot): RecoverySnapshot {
    return {
      type: snapshot.type,
      metadata: this.copyMetadata(snapshot.metadata),
      timestamp: snapshot.timestamp,
    };
  }

  /**
   * 复制Metadata 值，避免外部修改内部状态。
   */
  private copyMetadata(metadata: RecoveryMetadata): RecoveryMetadata {
    return {
      source: metadata.source,
      chatId: metadata.chatId,
      messageId: metadata.messageId,
      reason: metadata.reason,
    };
  }

  /**
   * 复制Result 值，避免外部修改内部状态。
   * @param result 返回结果。
   */
  private copyResult(result: RecoveryResult): RecoveryResult {
    return {
      success: result.success,
      type: result.type,
      message: result.message,
    };
  }
}
