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

export class BranchRuntime {
  private events: EventBus;
  private branches: Map<string, BranchRecord> = new Map<string, BranchRecord>();
  private checkpoints: Map<string, CheckpointRecord> = new Map<string, CheckpointRecord>();

  constructor(events: EventBus) {
    this.events = events;
  }

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

  getLineage(chatId: string): Array<BranchRecord> {
    const reversed = new Array<BranchRecord>();
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

  private requireBranch(branchId: string): BranchRecord {
    const branch = this.branches.get(branchId);
    if (branch === undefined) {
      throw new Error(`Branch not found: ${branchId}`);
    }
    return branch;
  }

  private deactivateSiblings(parentChatId: string): void {
    const branches = Array.from(this.branches.values());
    for (let index = 0; index < branches.length; index += 1) {
      const branch = branches[index];
      if (branch.parentChatId === parentChatId) {
        branch.active = false;
      }
    }
  }

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

  private publishBranchEvent(eventName: string, branch: BranchRecord): void {
    const payload: BranchEventPayload = {
      branch: this.cloneBranch(branch),
    };
    this.events.publish<BranchEventPayload>(eventName, payload);
  }
}
