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
   * 内存中的分支记录映射表。
   */
  private branches: Map<string, BranchRecord> = new Map<string, BranchRecord>();
  /**
   * 内存中的检查点记录映射表。
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
   * 创建新的分支记录，写入内存并返回副本。
   * @param params 新分支的创建参数。
   * @returns 新创建的分支记录副本。
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
   * 创建新的检查点记录，写入内存并返回副本。
   * @param params 新检查点的创建参数。
   * @returns 新创建的检查点记录副本。
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
   * 激活指定分支，同时取消同一父级下其他分支的激活状态。
   * @param branchId 目标分支标识。
   * @returns 激活后的分支记录副本。
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
   * 获取指定父级聊天下当前激活的分支。
   * 不存在时抛出错误。
   * @param parentChatId 目标父聊天标识。
   * @returns 激活分支的记录副本。
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
   * 列出指定父级聊天下的所有分支。
   * @param parentChatId 目标父聊天标识；传入空字符串则返回全部分支。
   * @returns 分支记录副本列表。
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
   * 从指定聊天标识沿 parentChatId 链向上追溯，获取完整分支谱系。
   * @param chatId 起始聊天标识。
   * @returns 从根到叶排列的分支记录列表。
   */
  getLineage(chatId: string): Array<BranchRecord> {
    const reversed = new Array<BranchRecord>();
    // 当前聊天标识。
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
   * 恢复分支及其关联的检查点，将导出的数据重新导入实例。
   * @param data 待恢复的导出数据。
   * @param newBranchId 恢复后使用的新分支标识。
   * @param newChildChatId 恢复后使用的新子聊天标识。
   * @returns 恢复后的分支记录副本。
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
   * 获取指定分支，不存在时抛出错误。
   * @param branchId 目标分支标识。
   * @returns 分支记录。
   */
  private requireBranch(branchId: string): BranchRecord {
    const branch = this.branches.get(branchId);
    if (branch === undefined) {
      throw new Error(`Branch not found: ${branchId}`);
    }
    return branch;
  }

  /**
   * 取消指定父级聊天下所有分支的激活状态。
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
   * 深拷贝 BranchRecord，避免外部修改内部状态。
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
   * 深拷贝 CheckpointRecord，避免外部修改内部状态。
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

  /**
   * 生成恢复后的检查点标识，避免与已有标识冲突。
   * @param branchId 分支标识。
   * @param checkpointId 原始检查点标识。
   * @param index 检查点在列表中的索引。
   * @returns 不重复的检查点标识。
   */
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
   * @param eventName 要发布的事件名称。
   */
  private publishBranchEvent(eventName: string, branch: BranchRecord): void {
    const payload: BranchEventPayload = {
      branch: this.cloneBranch(branch),
    };
    this.events.publish<BranchEventPayload>(eventName, payload);
  }
}
