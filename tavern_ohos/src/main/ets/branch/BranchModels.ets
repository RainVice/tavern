export interface BranchCreateParams {
  id: string;
  parentChatId: string;
  anchorMessageId: string;
  childChatId: string;
  title: string;
}

export interface BranchRecord {
  id: string;
  parentChatId: string;
  anchorMessageId: string;
  childChatId: string;
  title: string;
  active: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface CheckpointCreateParams {
  id: string;
  branchId: string;
  anchorMessageId: string;
  label: string;
  snapshotRef: string;
}

export interface CheckpointRecord {
  id: string;
  branchId: string;
  anchorMessageId: string;
  label: string;
  snapshotRef: string;
  createdAt: number;
}

export interface BranchExportData {
  branch: BranchRecord;
  checkpoints: Array<CheckpointRecord>;
}

export interface BranchEventPayload {
  branch: BranchRecord;
}

export interface BranchActivatedPayload {
  branch: BranchRecord;
}

export interface CheckpointEventPayload {
  checkpoint: CheckpointRecord;
}
