/**
 * 命令模块统一导出入口。
 * 导出 CommandRuntime（命令管理运行时）、CommandInvocation（命令调用上下文类）以及所有相关的数据结构和事件载荷类型，
 * 供 UI 层的命令输入处理和外部模块通过 import { ... } from './command' 的方式统一引用。
 */
export { CommandRuntime } from './CommandRuntime';
export { CommandInvocation } from './CommandModels';
export type {
  CommandAction,
  CommandErrorPayload,
  CommandExecutedPayload,
  CommandExecuteOptions,
  CommandExecutionResult,
  CommandNamedArgument,
  CommandParsedInput,
  CommandPipelineResult,
  CommandRecord,
  CommandRegisteredPayload,
  CommandRegistrationParams,
} from './CommandModels';
