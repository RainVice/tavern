import { EventBus } from '../runtime/EventBus';
import type {
  BranchActivatedPayload,
  BranchCreateParams,
  BranchEventPayload,
  BranchExportData,
  BranchRecord,
  CheckpointCreateParams,
  CheckpointEventPayload,
  CheckpointRecord,
} from './BranchModels';

/**
 * 提供聊天分支相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class BranchRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * branches 列表，由当前实例内部维护。
   */
  private branches: Map<string, BranchRecord> = new Map<string, BranchRecord>();
  /**
   * checkpoints 列表，由当前实例内部维护。
   */
  private checkpoints: Map<string, CheckpointRecord> = new Map<string, CheckpointRecord>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的分支记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  createBranch(params: BranchCreateParams): BranchRecord {
    if (this.branches.has(params.id)) {
      throw new Error(`Branch already exists: ${params.id}`);
    }
    const now = Date.now();
    const branch: BranchRecord = {
      id: params.id,
      parentChatId: params.parentChatId,
      anchorMessageId: params.anchorMessageId,
      childChatId: params.childChatId,
      title: params.title,
      active: false,
      createdAt: now,
      updatedAt: now,
    };
    this.branches.set(branch.id, this.cloneBranch(branch));
    this.publishBranchEvent('branch.created', branch);
    return this.cloneBranch(branch);
  }

  /**
   * 创建新的检查点记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  createCheckpoint(params: CheckpointCreateParams): CheckpointRecord {
    this.requireBranch(params.branchId);
    if (this.checkpoints.has(params.id)) {
      throw new Error(`Checkpoint already exists: ${params.id}`);
    }
    const checkpoint: CheckpointRecord = {
      id: params.id,
      branchId: params.branchId,
      anchorMessageId: params.anchorMessageId,
      label: params.label,
      snapshotRef: params.snapshotRef,
      createdAt: Date.now(),
    };
    this.checkpoints.set(checkpoint.id, this.cloneCheckpoint(checkpoint));
    const payload: CheckpointEventPayload = {
      checkpoint: this.cloneCheckpoint(checkpoint),
    };
    this.events.publish<CheckpointEventPayload>('branch.checkpoint.created', payload);
    return this.cloneCheckpoint(checkpoint);
  }

  /**
   * 更新分支状态，必要时写回存储并发布对应事件。
   * @param branchId 目标分支标识。
   */
  activateBranch(branchId: string): BranchRecord {
    const branch = this.requireBranch(branchId);
    this.deactivateSiblings(branch.parentChatId);
    branch.active = true;
    branch.updatedAt = Date.now();
    const payload: BranchActivatedPayload = {
      branch: this.cloneBranch(branch),
    };
    this.events.publish<BranchActivatedPayload>('branch.activated', payload);
    return this.cloneBranch(branch);
  }

  /**
   * 读取指定分支，不存在时抛出错误。
   * @param parentChatId 目标父聊天标识。
   * @returns 更新或读取后的记录副本。
   */
  getActiveBranch(parentChatId: string): BranchRecord {
    const branches = Array.from(this.branches.values());
    for (let index = 0; index < branches.length; index += 1) {
      const branch = branches[index];
      if (branch.parentChatId === parentChatId && branch.active) {
        return this.cloneBranch(branch);
      }
    }
    throw new Error(`Active branch not found: ${parentChatId}`);
  }

  /**
   * 读取Branches列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param parentChatId 目标父聊天标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listBranches(parentChatId: string): Array<BranchRecord> {
    const result = new Array<BranchRecord>();
    const branches = Array.from(this.branches.values());
    for (let index = 0; index < branches.length; index += 1) {
      const branch = branches[index];
      if (parentChatId.length === 0 || branch.parentChatId === parentChatId) {
        result.push(this.cloneBranch(branch));
      }
    }
    return result;
  }

  /**
   * 读取指定Lineage，不存在时抛出错误。
   * @param chatId 目标聊天标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  getLineage(chatId: string): Array<BranchRecord> {
    const reversed = new Array<BranchRecord>();
    // current Chat 标识。
    let currentChatId = chatId;
    let found = true;
    while (found) {
      found = false;
      const branches = Array.from(this.branches.values());
      for (let index = 0; index < branches.length; index += 1) {
        const branch = branches[index];
        if (branch.childChatId === currentChatId) {
          reversed.push(this.cloneBranch(branch));
          currentChatId = branch.parentChatId;
          found = true;
          break;
        }
      }
    }
    const lineage = new Array<BranchRecord>();
    for (let index = reversed.length - 1; index >= 0; index -= 1) {
      lineage.push(this.cloneBranch(reversed[index]));
    }
    return lineage;
  }

  /**
   * 导出分支，用于备份、迁移或与 SillyTavern 数据互通。
   * @param branchId 目标分支标识。
   * @returns 可持久化或可传输的导出内容。
   */
  exportBranch(branchId: string): BranchExportData {
    const branch = this.cloneBranch(this.requireBranch(branchId));
    const checkpoints = new Array<CheckpointRecord>();
    const all = Array.from(this.checkpoints.values());
    for (let index = 0; index < all.length; index += 1) {
      if (all[index].branchId === branchId) {
        checkpoints.push(this.cloneCheckpoint(all[index]));
      }
    }
    const data: BranchExportData = {
      branch: branch,
      checkpoints: checkpoints,
    };
    return data;
  }

  /**
   * 执行 restoreBranch 的内部处理步骤，供当前模块复用。
   * @param data 导入或恢复使用的序列化数据。
   * @param newBranchId 目标新分支标识。
   * @param newChildChatId 目标新子聊天标识。
   */
  restoreBranch(data: BranchExportData, newBranchId: string, newChildChatId: string): BranchRecord {
    if (this.branches.has(newBranchId)) {
      throw new Error(`Branch already exists: ${newBranchId}`);
    }
    const restored = this.cloneBranch(data.branch);
    restored.id = newBranchId;
    restored.childChatId = newChildChatId;
    restored.active = false;
    restored.updatedAt = Date.now();
    this.branches.set(restored.id, this.cloneBranch(restored));
    for (let index = 0; index < data.checkpoints.length; index += 1) {
      const checkpoint = this.cloneCheckpoint(data.checkpoints[index]);
      checkpoint.id = this.restoredCheckpointId(newBranchId, checkpoint.id, index);
      checkpoint.branchId = restored.id;
      this.checkpoints.set(checkpoint.id, this.cloneCheckpoint(checkpoint));
    }
    this.publishBranchEvent('branch.restored', restored);
    return this.cloneBranch(restored);
  }

  /**
   * 读取必须存在的Branch 值，缺失时抛出错误。
   * @param branchId 目标分支标识。
   */
  private requireBranch(branchId: string): BranchRecord {
    const branch = this.branches.get(branchId);
    if (branch === undefined) {
      throw new Error(`Branch not found: ${branchId}`);
    }
    return branch;
  }

  /**
   * 更新Siblings状态，必要时写回存储并发布对应事件。
   * @param parentChatId 目标父聊天标识。
   */
  private deactivateSiblings(parentChatId: string): void {
    const branches = Array.from(this.branches.values());
    for (let index = 0; index < branches.length; index += 1) {
      const branch = branches[index];
      if (branch.parentChatId === parentChatId) {
        branch.active = false;
      }
    }
  }

  /**
   * 复制Branch 值，避免外部修改内部状态。
   */
  private cloneBranch(branch: BranchRecord): BranchRecord {
    const cloned: BranchRecord = {
      id: branch.id,
      parentChatId: branch.parentChatId,
      anchorMessageId: branch.anchorMessageId,
      childChatId: branch.childChatId,
      title: branch.title,
      active: branch.active,
      createdAt: branch.createdAt,
      updatedAt: branch.updatedAt,
    };
    return cloned;
  }

  /**
   * 复制Checkpoint 值，避免外部修改内部状态。
   */
  private cloneCheckpoint(checkpoint: CheckpointRecord): CheckpointRecord {
    const cloned: CheckpointRecord = {
      id: checkpoint.id,
      branchId: checkpoint.branchId,
      anchorMessageId: checkpoint.anchorMessageId,
      label: checkpoint.label,
      snapshotRef: checkpoint.snapshotRef,
      createdAt: checkpoint.createdAt,
    };
    return cloned;
  }
  private restoredCheckpointId(branchId: string, checkpointId: string, index: number): string {
    const base = `${branchId}:${checkpointId}`;
    if (!this.checkpoints.has(base)) {
      return base;
    }
    let suffix = index + 1;
    let candidate = `${base}:${suffix}`;
    while (this.checkpoints.has(candidate)) {
      suffix += 1;
      candidate = `${base}:${suffix}`;
    }
    return candidate;
  }

  /**
   * 发布聊天分支事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。

   */
  private publishBranchEvent(eventName: string, branch: BranchRecord): void {
    const payload: BranchEventPayload = {
      branch: this.cloneBranch(branch),
    };
    this.events.publish<BranchEventPayload>(eventName, payload);
  }
}
