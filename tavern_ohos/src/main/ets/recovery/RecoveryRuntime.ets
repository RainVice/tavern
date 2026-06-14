import { EventBus } from '../runtime/EventBus';
import type { RecoveryAttemptedPayload, RecoveryMetadata, RecoveryResult, RecoverySnapshot, RecoveryType } from './RecoveryModels';

/**
 * 提供恢复快照相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class RecoveryRuntime {
  /**
   * 事件总线，用于发布恢复尝试事件。
   */
  private events: EventBus; private snapshots: Array<RecoverySnapshot>=[];
  /**
   * 初始化当前运行时实例，清空快照列表。
   * @param events 事件总线，用于发布 recovery.attempted 事件。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 创建恢复快照并写入内存存储。在关键操作前由外部模块调用，记录当前状态以便后续恢复。
   * @param type 快照类型（如 user_password、data_corruption、session_restore），标识恢复场景类别。
   * @param metadata 与快照关联的元数据（来源、聊天标识、消息标识、原因等），提供恢复时所需的上下文信息。
   * @returns 新创建的快照记录副本。
   */
  createSnapshot(type: RecoveryType, metadata: RecoveryMetadata): RecoverySnapshot {
    const snap: RecoverySnapshot = { type: type, metadata: this.copyMetadata(metadata), timestamp: Date.now() };
    this.snapshots.push(this.copySnapshot(snap)); return this.copySnapshot(snap);
  }

  /**
   * 查询指定类型的最新一条恢复快照。在尝试恢复时调用，按类型从快照列表中逆序查找。
   * @param type 快照类型，限定搜索范围。
   * @returns 匹配的最新快照记录副本，不存在时返回 undefined。
   */
  getLatestSnapshot(type: RecoveryType): RecoverySnapshot|undefined {
    for (let i=this.snapshots.length-1;i>=0;i--) { if (this.snapshots[i].type===type) return this.copySnapshot(this.snapshots[i]); }
    return undefined;
  }

  /**
   * 尝试从最新快照恢复指定类型的状态，并发布恢复尝试事件。在需要恢复的场景下由外部模块调用。
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
   * 返回所有已存储的快照记录列表的深拷贝。用于 UI 展示快照历史或批量查询。
   * @returns 快照记录副本数组。
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
   * 深拷贝恢复结果对象。
   * @param result 待拷贝的恢复结果。
   */
  private copyResult(result: RecoveryResult): RecoveryResult {
    return {
      success: result.success,
      type: result.type,
      message: result.message,
    };
  }
}
