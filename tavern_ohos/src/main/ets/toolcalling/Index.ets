/**
 * toolcalling 模块导出核心能力和类型。
 *
 * 提供工具调用运行时管理（ToolCallingRuntime）以及相关模型类型，
 * 包括定义记录、请求结构、调用结果和事件载荷。
 */
export { ToolCallingRuntime } from './ToolCallingRuntime';
export type {
  ToolAction,
  ToolCalledPayload,
  ToolCallLoopParams,
  ToolCallRequest,
  ToolDefinitionRecord,
  ToolErrorPayload,
  ToolErrorRecord,
  ToolExecutionResult,
  ToolInvocation,
  ToolInvocationResult,
  ToolOpenAIFunction,
  ToolOpenAITool,
  ToolRegisteredPayload,
  ToolRegistrationParams,
} from './ToolCallingModels';
