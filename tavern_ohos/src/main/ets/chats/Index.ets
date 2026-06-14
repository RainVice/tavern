/**
 * 聊天模块统一导出入口。
 * 导出 ChatRuntime（聊天管理运行时）、MessageRuntime（消息管理运行时）以及所有相关的数据结构和事件载荷类型，
 * 供 UI 层的聊天列表页、对话页面和外部模块通过 import { ... } from './chats' 的方式统一引用。
 */
export { ChatRuntime } from './ChatRuntime';
export { MessageRuntime } from './MessageRuntime';
export type {
  ChatCreateParams,
  ChatEventPayload,
  ChatExportExtra,
  ChatExportHeader,
  ChatExportMessage,
  ChatIndex,
  ChatIndexEntry,
  ChatMessage,
  ChatMessageCreateParams,
  ChatMessageUpdateParams,
  ChatRecord,
  MessageEventPayload,
} from './ChatModels';
