import { EventBus } from '../runtime/EventBus';
import type { RecoveryAttemptedPayload, RecoveryMetadata, RecoveryResult, RecoverySnapshot, RecoveryType } from './RecoveryModels';

/**
 * 提供恢复快照相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class RecoveryRuntime {
  /**
   * 内部事件总线和快照列表。
   */
  private events: EventBus; private snapshots: Array<RecoverySnapshot>=[];

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 创建新的恢复快照，写入内部列表并返回其副本。
   * @param type 恢复类型。
   * @param metadata 上下文元数据。
   * @returns 新建快照的深拷贝副本。
   */
  createSnapshot(type: RecoveryType, metadata: RecoveryMetadata): RecoverySnapshot {
    const snap: RecoverySnapshot = { type: type, metadata: this.copyMetadata(metadata), timestamp: Date.now() };
    this.snapshots.push(this.copySnapshot(snap)); return this.copySnapshot(snap);
  }

  /**
   * 获取指定类型的最新快照，不存在时返回 undefined。
   * @param type 恢复类型。
   * @returns 快照副本，未找到返回 undefined。
   */
  getLatestSnapshot(type: RecoveryType): RecoverySnapshot|undefined {
    for (let i=this.snapshots.length-1;i>=0;i--) { if (this.snapshots[i].type===type) return this.copySnapshot(this.snapshots[i]); }
    return undefined;
  }

  /**
   * 尝试根据最新快照执行恢复，发布恢复尝试事件并返回处理结果。
   * @param type 恢复类型。
   * @returns 恢复操作结果。
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
   * 读取所有快照记录，返回副本以防止外部修改内部状态。
   * @returns 快照列表副本。
   */
  listSnapshots(): Array<RecoverySnapshot> {
    const result = new Array<RecoverySnapshot>();
    for (let index = 0; index < this.snapshots.length; index += 1) {
      result.push(this.copySnapshot(this.snapshots[index]));
    }
    return result;
  }

  /**
   * 深拷贝快照对象，防止外部引用修改内部状态。
   */
  private copySnapshot(snapshot: RecoverySnapshot): RecoverySnapshot {
    return {
      type: snapshot.type,
      metadata: this.copyMetadata(snapshot.metadata),
      timestamp: snapshot.timestamp,
    };
  }

  /**
   * 深拷贝元数据对象，防止外部引用修改内部状态。
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
   * 深拷贝结果对象，防止外部引用修改内部状态。
   * @param result 原始结果对象。
   * @returns 结果对象的深拷贝副本。
   */
  private copyResult(result: RecoveryResult): RecoveryResult {
    return {
      success: result.success,
      type: result.type,
      message: result.message,
    };
  }
}
