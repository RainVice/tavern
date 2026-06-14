import type {
  RuntimePermission,
  ToolCallContentType,
} from '../contracts/PublicContracts';

/**
 * 工具调用操作执行完毕后返回给调用方的结果。
 */
export interface ToolExecutionResult {
  /**
   * 执行是否成功。
   */
  ok: boolean;
  /**
   * 执行返回的文本结果。
   */
  result: string;
  /**
   * 执行失败时的错误描述。
   */
  error: string;
}

/**
 * 定义一个可注册到运行时中的工具操作，包含执行逻辑。
 */
export interface ToolAction {
  /**
   * 执行工具操作。
   * @param argumentsJson 工具参数的 JSON 字符串。
   */
  execute(argumentsJson: string): Promise<ToolExecutionResult>;
}

/**
 * 注册一个工具时需提供的完整参数。
 */
export interface ToolRegistrationParams {
  /**
   * 工具名称，用于内部标识和索引。
   */
  name: string;
  /**
   * 工具显示名称，用于界面展示。
   */
  displayName: string;
  /**
   * 工具功能描述，供模型理解何时调用此工具。
   */
  description: string;
  /**
   * 工具参数的 JSON Schema 字符串。
   */
  parametersJson: string;
  /**
   * 调用此工具所需的运行时权限。
   */
  permission: RuntimePermission;
  /**
   * 是否隐藏调用结果，不将其作为消息返回。
   */
  stealth: boolean;
  /**
   * 工具是否已启用，禁用后不会出现在调用列表中。
   */
  enabled: boolean;
  /**
   * 工具的执行逻辑。
   */
  action: ToolAction;
}

/**
 * 持久化或内存索引中存储的一条工具定义记录。
 */
export interface ToolDefinitionRecord {
  /**
   * 工具名称，用于内部标识。
   */
  name: string;
  /**
   * 工具显示名称。
   */
  displayName: string;
  /**
   * 工具功能描述。
   */
  description: string;
  /**
   * 工具参数的 JSON Schema 字符串。
   */
  parametersJson: string;
  /**
   * 调用此工具所需的运行时权限。
   */
  permission: RuntimePermission;
  /**
   * 是否隐藏调用结果。
   */
  stealth: boolean;
  /**
   * 工具是否已启用。
   */
  enabled: boolean;
}

/**
 * 发送给外部服务或宿主层的一次工具调用请求。
 */
export interface ToolCallRequest {
  /**
   * 本次调用请求的唯一标识。
   */
  id: string;
  /**
   * 目标工具名称。
   */
  name: string;
  /**
   * 调用参数的 JSON 字符串。
   */
  argumentsJson: string;
  /**
   * 调用签名，用于校验或追踪。
   */
  signature: string;
  /**
   * 触发此次调用的推理文本。
   */
  reasoning: string;
}

/**
 * 一条工具调用的执行记录，包含输入、输出及状态。
 */
export interface ToolInvocation {
  /**
   * 调用记录的唯一标识。
   */
  id: string;
  /**
   * 工具的显示名称。
   */
  displayName: string;
  /**
   * 工具名称。
   */
  name: string;
  /**
   * 传入的参数文本。
   */
  parameters: string;
  /**
   * 执行返回的结果文本。
   */
  result: string;
  /**
   * 执行是否出错。
   */
  error: boolean;
  /**
   * 调用签名。
   */
  signature: string;
  /**
   * 触发此次调用的推理文本。
   */
  reasoning: string;
}

/**
 * 工具调用过程中产生的错误记录。
 */
export interface ToolErrorRecord {
  /**
   * 产生错误的工具名称。
   */
  toolName: string;
  /**
   * 错误消息。
   */
  message: string;
}

/**
 * 一批工具调用执行后的汇总结果。
 */
export interface ToolInvocationResult {
  /**
   * 所有工具调用的执行记录。
   */
  invocations: Array<ToolInvocation>;
  /**
   * 执行过程中产生的所有错误记录。
   */
  errors: Array<ToolErrorRecord>;
  /**
   * 隐藏调用的工具名称列表。
   */
  stealthCalls: Array<string>;
  /**
   * 格式化后的结果消息列表，可直接用于消息展示。
   */
  resultMessages: Array<string>;
}

/**
 * 工具调用循环的入参，包含多批调用请求和深度限制。
 */
export interface ToolCallLoopParams {
  /**
   * 按批次组织的工具调用请求列表。
   */
  batches: Array<Array<ToolCallRequest>>;
  /**
   * 循环调用的最大深度，防止无限递归。
   */
  maxDepth: number;
  /**
   * 触发调用的推理文本，将透传给每个请求。
   */
  reasoningText: string;
}

/**
 * OpenAI 格式的工具函数定义。
 */
export interface ToolOpenAIFunction {
  /**
   * 函数名称。
   */
  name: string;
  /**
   * 函数功能描述。
   */
  description: string;
  /**
   * 函数参数的 JSON Schema 字符串。
   */
  parametersJson: string;
}

/**
 * OpenAI 格式的工具定义，包含类型和函数描述。
 */
export interface ToolOpenAITool {
  /**
   * 工具类型（固定为 'function'）。
   */
  type: ToolCallContentType;
  /**
   * 工具所对应的函数定义。
   */
  function: ToolOpenAIFunction;
}

/**
 * 工具调用事件发布时携带的负载，表示一次工具已被执行。
 */
export interface ToolCalledPayload {
  /**
   * 被执行的工具调用记录。
   */
  invocation: ToolInvocation;
}

/**
 * 工具调用错误事件发布时携带的负载。
 */
export interface ToolErrorPayload {
  /**
   * 错误详情。
   */
  error: ToolErrorRecord;
}

/**
 * 工具注册事件发布时携带的负载，表示一个新工具已注册到运行时。
 */
export interface ToolRegisteredPayload {
  /**
   * 已注册的工具定义记录。
   */
  tool: ToolDefinitionRecord;
}
