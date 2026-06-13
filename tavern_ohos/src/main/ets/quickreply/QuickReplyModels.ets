import type { CommandExecutionResult } from '../command/CommandModels';

export interface QuickReplySetCreateParams {
  id: string;
  name: string;
  scope: string;
  scopeId: string;
  enabled: boolean;
}

export interface QuickReplyItemCreateParams {
  id: string;
  label: string;
  title: string;
  command: string;
  enabled: boolean;
  visible: boolean;
  autoExecute: boolean;
  trigger: string;
  pluginId: string;
}

export interface QuickReplyItemRecord {
  id: string;
  label: string;
  title: string;
  command: string;
  enabled: boolean;
  visible: boolean;
  autoExecute: boolean;
  trigger: string;
  pluginId: string;
}

export interface QuickReplySetRecord {
  id: string;
  name: string;
  scope: string;
  scopeId: string;
  enabled: boolean;
  items: Array<QuickReplyItemRecord>;
}

export interface QuickReplyButtonData {
  setId: string;
  itemId: string;
  label: string;
  title: string;
  command: string;
  scope: string;
  scopeId: string;
  pluginId: string;
}

export interface QuickReplyExecutionResult {
  set: QuickReplySetRecord;
  item: QuickReplyItemRecord;
  executed: boolean;
  commandResult: CommandExecutionResult;
}

export interface QuickReplyExecutedPayload {
  set: QuickReplySetRecord;
  item: QuickReplyItemRecord;
  commandResult: CommandExecutionResult;
}

export interface QuickReplySetUpdatedPayload {
  set: QuickReplySetRecord;
}

export interface QuickReplyExportData {
  set: QuickReplySetRecord;
}
