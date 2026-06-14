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
 * 在聊天对话的分支管理流程中被调用，用于创建分支、检查点、切换分支以及导出恢复分支数据。
 */
export class BranchRuntime {
  /**
   * 事件总线，用于发布分支创建、激活、恢复和检查点创建事件。
   */
  private events: EventBus;
  /**
   * 分支记录内存索引，以分支标识为键，用于快速查找和管理分支记录。
   */
  private branches: Map<string, BranchRecord> = new Map<string, BranchRecord>();
  /**
   * 检查点记录内存索引，以检查点标识为键，用于快速查找和管理检查点记录。
   */
  private checkpoints: Map<string, CheckpointRecord> = new Map<string, CheckpointRecord>();

  /**
   * 初始化当前运行时实例，由宿主在应用启动时通过依赖注入创建。
   * @param events 事件总线，用于发布分支和检查点状态变更事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新分支记录：校验唯一性，写入内存索引并发布创建事件。
   * 在用户从聊天对话中选择"创建分支"时触发，用于建立新的聊天分支树。
   * @param params 分支创建参数，包含父聊天标识、锚点消息标识、子聊天标识和标题。
   * @returns 创建后的分支记录副本，包含完整的分支元数据和时间戳。
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
   * 在指定分支下创建检查点：校验分支存在性和标识唯一性，写入内存索引并发布事件。
   * 在用户从分支管理中选择"创建检查点"时触发，用于捕获分支特定时刻的消息状态。
   * @param params 检查点创建参数，包含分支标识、锚点消息标识、标签和快照引用。
   * @returns 创建后的检查点记录副本，包含完整的检查点元数据和时间戳。
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
   * 激活指定分支：将同属一个父聊天的其它分支设为非激活，标记该分支为激活并发布事件。
   * 在用户从分支导航中选择切换到另一个分支时触发。
   * @param branchId 要激活的分支标识，用于在内存索引中定位并切换状态。
   * @returns 激活后的分支记录副本，active 字段为 true。
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
   * 获取指定父聊天下当前激活的分支，未找到时抛出异常，用于确认当前正在使用的分支。
   * @param parentChatId 父聊天的标识，用于筛选属于该聊天的所有分支。
   * @returns 激活中的分支记录副本。
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
   * 获取指定父聊天下的所有分支记录，为空时返回全部，用于在 UI 中展示分支列表。
   * @param parentChatId 父聊天的标识；传入空字符串则返回所有分支（全局视图）。
   * @returns 符合条件的分支记录副本列表，调用方可安全修改。
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
   * 从指定聊天标识出发，沿子→父方向追溯完整的分支继承链，用于在 UI 中展示分支历史路径。
   * @param chatId 起始聊天标识，从当前聊天开始向上追踪分支来源。
   * @returns 从根到该聊天的分支记录列表（祖先在前，当前在后），按分支创建顺序排列。
   */
  getLineage(chatId: string): Array<BranchRecord> {
    const reversed = new Array<BranchRecord>();
    // 从当前聊天向上追溯父聊天，构建分支继承链
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
   * 导出指定分支及其所有检查点，用于备份、迁移或与外部工具数据互通。
   * @param branchId 要导出的分支标识，用于定位分支及其关联的检查点。
   * @returns 包含分支记录和关联检查点的导出数据，可用于 restoreBranch 恢复。
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
   * 从导出的分支数据中恢复分支和关联检查点：重置标识和状态，写入内存索引并发布事件。
   * 在数据迁移或从备份还原分支数据时调用，用于将导出的分支恢复到当前运行环境。
   * @param data 分支导出数据，包含分支记录和检查点列表，通过 exportBranch 获得。
   * @param newBranchId 恢复后使用的新分支标识，避免与现有分支标识冲突。
   * @param newChildChatId 恢复后使用的新子聊天标识，指向恢复后的聊天会话。
   * @returns 恢复后的分支记录副本，状态已被重置为未激活。
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
   * 根据标识查找分支记录，不存在时抛出异常，供内部方法在需要确保分支存在时使用。
   * @param branchId 要查找的分支标识，用于在内存索引中定位分支记录。
   */
  private requireBranch(branchId: string): BranchRecord {
    const branch = this.branches.get(branchId);
    if (branch === undefined) {
      throw new Error(`Branch not found: ${branchId}`);
    }
    return branch;
  }

  /**
   * 将指定父聊天下的所有分支设为非激活状态（激活新分支前的清理步骤），
   * 确保同一父聊天下只有一个分支处于激活状态。
   * @param parentChatId 父聊天的标识，用于筛选需要去激活的分支。
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
   * 复制分支记录，生成值副本，防止外部修改内部状态，用于所有对外暴露分支记录的场景。
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
   * 复制检查点记录，生成值副本，防止外部修改内部状态，用于所有对外暴露检查点记录的场景。
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
   * 发布分支事件（创建、恢复等），将分支状态变化通知给宿主或其他 Runtime。
   * @param eventName 要发布的事件名称（如 branch.created、branch.restored），用于订阅者识别事件类型。
   * @param branch 事件关联的分支记录，用于事件载荷中传递分支状态。
   */
  private publishBranchEvent(eventName: string, branch: BranchRecord): void {
    const payload: BranchEventPayload = {
      branch: this.cloneBranch(branch),
    };
    this.events.publish<BranchEventPayload>(eventName, payload);
  }
}
