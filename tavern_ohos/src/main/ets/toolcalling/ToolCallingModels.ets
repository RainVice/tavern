import type {
  RuntimePermission,
  ToolCallContentType,
} from '../contracts/PublicContracts';

/**
 * 描述工具调用操作完成后返回给调用方的结果。
 */
export interface ToolExecutionResult {
  /**
   * ok 值，由当前实例内部维护。
   */
  ok: boolean;
  /**
   * 处理结果。
   */
  result: string;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
}

/**
 * 描述工具调用模块在运行时交换的数据结构。
 */
export interface ToolAction {
  /**
   * 执行 execute 的内部处理步骤，供当前模块复用。
   * @param argumentsJson arguments JSON 字符串。
   */
  execute(argumentsJson: string): Promise<ToolExecutionResult>;
}

/**
 * 描述调用工具调用能力时需要传入的参数。
 */
export interface ToolRegistrationParams {
  /**
   * 名称。
   */
  name: string;
  /**
   * display 名称。
   */
  displayName: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * parameters JSON 字符串。
   */
  parametersJson: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: RuntimePermission;
  /**
   * stealth 值，由当前实例内部维护。
   */
  stealth: boolean;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * action 值，由当前实例内部维护。
   */
  action: ToolAction;
}

/**
 * 描述工具调用持久化或内存索引中的一条记录。
 */
export interface ToolDefinitionRecord {
  /**
   * 名称。
   */
  name: string;
  /**
   * display 名称。
   */
  displayName: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * parameters JSON 字符串。
   */
  parametersJson: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: RuntimePermission;
  /**
   * stealth 值，由当前实例内部维护。
   */
  stealth: boolean;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
}

/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface ToolCallRequest {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * arguments JSON 字符串。
   */
  argumentsJson: string;
  /**
   * signature 值，由当前实例内部维护。
   */
  signature: string;
  /**
   * reasoning 值，由当前实例内部维护。
   */
  reasoning: string;
}

/**
 * 描述工具调用模块在运行时交换的数据结构。
 */
export interface ToolInvocation {
  /**
   * 标识。
   */
  id: string;
  /**
   * display 名称。
   */
  displayName: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * parameters 列表，由当前实例内部维护。
   */
  parameters: string;
  /**
   * 处理结果。
   */
  result: string;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: boolean;
  /**
   * signature 值，由当前实例内部维护。
   */
  signature: string;
  /**
   * reasoning 值，由当前实例内部维护。
   */
  reasoning: string;
}

/**
 * 描述工具调用持久化或内存索引中的一条记录。
 */
export interface ToolErrorRecord {
  /**
   * tool 名称。
   */
  toolName: string;
  /**
   * 消息数据。
   */
  message: string;
}

/**
 * 描述工具调用操作完成后返回给调用方的结果。
 */
export interface ToolInvocationResult {
  /**
   * invocations 列表，由当前实例内部维护。
   */
  invocations: Array<ToolInvocation>;
  /**
   * errors 列表，由当前实例内部维护。
   */
  errors: Array<ToolErrorRecord>;
  /**
   * stealth Calls 列表，由当前实例内部维护。
   */
  stealthCalls: Array<string>;
  /**
   * result Messages 列表，由当前实例内部维护。
   */
  resultMessages: Array<string>;
}

/**
 * 描述调用工具调用能力时需要传入的参数。
 */
export interface ToolCallLoopParams {
  /**
   * batches 列表，由当前实例内部维护。
   */
  batches: Array<Array<ToolCallRequest>>;
  /**
   * max Depth 值，由当前实例内部维护。
   */
  maxDepth: number;
  /**
   * reasoning Text 值，由当前实例内部维护。
   */
  reasoningText: string;
}

/**
 * 描述工具调用模块在运行时交换的数据结构。
 */
export interface ToolOpenAIFunction {
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * parameters JSON 字符串。
   */
  parametersJson: string;
}

/**
 * 描述工具调用模块在运行时交换的数据结构。
 */
export interface ToolOpenAITool {
  /**
   * type 值，由当前实例内部维护。
   */
  type: ToolCallContentType;
  /**
   * function 值，由当前实例内部维护。
   */
  function: ToolOpenAIFunction;
}

/**
 * 描述工具调用事件发布时携带的数据结构。
 */
export interface ToolCalledPayload {
  /**
   * invocation 值，由当前实例内部维护。
   */
  invocation: ToolInvocation;
}

/**
 * 描述工具调用事件发布时携带的数据结构。
 */
export interface ToolErrorPayload {
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: ToolErrorRecord;
}

/**
 * 描述工具调用事件发布时携带的数据结构。
 */
export interface ToolRegisteredPayload {
  /**
   * tool 值，由当前实例内部维护。
   */
  tool: ToolDefinitionRecord;
}
