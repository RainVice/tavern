/**
 * 描述工具调用操作完成后返回给调用方的结果。
 * 由 ToolAction.execute 返回，供 ToolCallingRuntime 判断执行状态和处理结果。
 */
export interface ToolExecutionResult {
  /**
   * 执行是否成功，由工具实现方设置，影响 ToolCallingRuntime 是否将结果添加到 invocations。
   */
  ok: boolean;
  /**
   * 执行结果数据，成功时的结构化输出文本。
   */
  result: string;
  /**
   * 执行失败时的错误描述。
   */
  error: string;
}

/**
 * 描述工具调用模块在运行时交换的动作接口。
 * 宿主在注册工具时提供 execute 实现，ToolCallingRuntime 在 invokeToolCalls 时调用。
 */
export interface ToolAction {
  /**
   * 执行工具逻辑，返回执行结果。
   * @param argumentsJson 工具参数的 JSON 字符串，由 AI 模型生成的函数调用参数。
   */
  execute(argumentsJson: string): Promise<ToolExecutionResult>;
}

/**
 * 描述注册工具时需要传入的参数。
 * 在宿主向 ToolCallingRuntime 注册可用工具时传入。
 */
export interface ToolRegistrationParams {
  /**
   * 工具名称（唯一标识），在 ToolCallingRuntime 中作为查找键。
   */
  name: string;
  /**
   * 工具显示名称，用于 UI 展示和日志记录。
   */
  displayName: string;
  /**
   * 工具功能描述，用于在 AI 模型选择工具时理解工具的用途。
   */
  description: string;
  /**
   * 工具参数 schema 的 JSON 字符串，用于 AI 模型生成符合格式的参数。
   */
  parametersJson: string;
  /**
   * 工具所需权限，用于在工具执行前检查宿主授权。
   */
  permission: string;
  /**
   * 是否为静默调用（不展示给用户），静默工具的结果不会出现在 UI 中。
   */
  stealth: boolean;
  /**
   * 是否启用，禁用的工具不会被 listOpenAITools 返回，AI 模型无法调用。
   */
  enabled: boolean;
  /**
   * 工具执行动作，ToolCallingRuntime 在调用工具时执行该动作。
   */
  action: ToolAction;
}

/**
 * 描述工具调用持久化或内存索引中的一条记录。
 * 在工具注册后存储在 ToolCallingRuntime 中，供 AI 模型调用时查询。
 */
export interface ToolDefinitionRecord {
  /**
   * 工具名称。
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
   * 工具参数 schema 的 JSON 字符串。
   */
  parametersJson: string;
  /**
   * 工具所需权限。
   */
  permission: string;
  /**
   * 是否为静默调用。
   */
  stealth: boolean;
  /**
   * 是否启用。
   */
  enabled: boolean;
}

/**
 * 描述发送给外部服务或宿主网络层的工具调用请求数据。
 * 由 AI 模型返回的 function_call 解析而来，包含调用参数和签名信息。
 */
export interface ToolCallRequest {
  /**
   * 请求唯一标识，由 AI 模型生成，用于关联调用和结果。
   */
  id: string;
  /**
   * 工具名称，用于在已注册的工具列表中查找对应的 ToolDefinition。
   */
  name: string;
  /**
   * 工具参数的 JSON 字符串，AI 模型根据参数 schema 生成。
   */
  argumentsJson: string;
  /**
   * 对调用结果的数字签名，用于安全验证调用未被篡改。
   */
  signature: string;
  /**
   * 调用时附带的推理过程文本，记录模型在调用该工具时的思考过程。
   */
  reasoning: string;
}

/**
 * 描述工具调用模块在运行时交换的调用记录。
 * 记录一次工具调用的完整信息，包括调用参数、执行结果和签名。
 */
export interface ToolInvocation {
  /**
   * 调用唯一标识，来自 ToolCallRequest.id。
   */
  id: string;
  /**
   * 工具显示名称。
   */
  displayName: string;
  /**
   * 工具名称。
   */
  name: string;
  /**
   * 调用时传入的参数。
   */
  parameters: string;
  /**
   * 执行结果数据。
   */
  result: string;
  /**
   * 执行是否出错。
   */
  error: boolean;
  /**
   * 调用结果的数字签名。
   */
  signature: string;
  /**
   * 调用时附带的推理过程文本。
   */
  reasoning: string;
}

/**
 * 描述工具调用持久化或内存索引中的一条记录。
 * 记录工具执行过程中产生的错误信息。
 */
export interface ToolErrorRecord {
  /**
   * 出错的工具名称。
   */
  toolName: string;
  /**
   * 错误描述。
   */
  message: string;
}

/**
 * 描述工具调用执行完成后的汇总结果。
 * 在一次或多次工具调用后返回，包含所有调用记录和错误信息。
 */
export interface ToolInvocationResult {
  /**
   * 所有工具调用的记录列表。
   */
  invocations: Array<ToolInvocation>;
  /**
   * 执行过程中的错误列表。
   */
  errors: Array<ToolErrorRecord>;
  /**
   * 静默调用（stealth）的工具名称列表。
   */
  stealthCalls: Array<string>;
  /**
   * 格式化的结果消息列表，可返回给 AI 模型作为后续对话的参考。
   */
  resultMessages: Array<string>;
}

/**
 * 描述工具调用循环的执行参数。
 * 在执行多轮次工具调用时传入，支持分批调用和递归深度限制。
 */
export interface ToolCallLoopParams {
  /**
   * 按轮次分组的多批次工具调用请求，每轮是一组并行调用。
   */
  batches: Array<Array<ToolCallRequest>>;
  /**
   * 最大递归深度，防止无限递归调用。
   */
  maxDepth: number;
  /**
   * 本次调用的推理过程文本。
   */
  reasoningText: string;
}

/**
 * 描述工具调用模块在运行时交换的数据结构。
 * 用于将工具定义格式化为 OpenAI 兼容的 function 结构。
 */
export interface ToolOpenAIFunction {
  /**
   * 函数名称。
   */
  name: string;
  /**
   * 函数描述。
   */
  description: string;
  /**
   * 函数参数 schema 的 JSON 字符串。
   */
  parametersJson: string;
}

/**
 * 描述 OpenAI 格式的工具定义。
 * 在 listOpenAITools 中返回，用于兼容 OpenAI 的 tool calling API。
 */
export interface ToolOpenAITool {
  /**
   * 工具类型（固定为 "function"）。
   */
  type: string;
  /**
   * 工具对应的函数定义。
   */
  function: ToolOpenAIFunction;
}

/**
 * 描述工具调用执行事件发布时携带的数据结构。
 * ToolCallingRuntime 在 invokeOne 后发布 tool.called 事件，通知宿主 UI 展示工具执行情况。
 */
export interface ToolCalledPayload {
  /**
   * 已执行的工具调用记录。
   */
  invocation: ToolInvocation;
}

/**
 * 描述工具调用错误事件发布时携带的数据结构。
 * ToolCallingRuntime 在 addError 后发布 tool.error 事件，通知宿主 UI 展示错误信息。
 */
export interface ToolErrorPayload {
  /**
   * 错误记录。
   */
  error: ToolErrorRecord;
}

/**
 * 描述工具注册事件发布时携带的数据结构。
 * ToolCallingRuntime 在 registerTool 后发布 tool.registered 事件，通知宿主 UI 刷新工具列表。
 */
export interface ToolRegisteredPayload {
  /**
   * 已注册的工具定义。
   */
  tool: ToolDefinitionRecord;
}
