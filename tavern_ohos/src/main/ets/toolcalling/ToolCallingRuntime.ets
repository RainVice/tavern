import { EventBus } from '../runtime/EventBus';
import type {
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
  ToolOpenAITool,
  ToolRegisteredPayload,
  ToolRegistrationParams,
} from './ToolCallingModels';

/**
 * 描述工具调用模块在运行时交换的数据结构。
 * 内部使用的工具定义，在 ToolDefinitionRecord 基础上增加执行动作引用。
 */
interface ToolDefinitionInternal {
  /**
   * 工具定义记录。
   */
  record: ToolDefinitionRecord;
  /**
   * 工具执行动作，在 invokeOne 中调用以实现具体的工具逻辑。
   */
  action: ToolAction;
}

/**
 * 提供工具调用相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在 AI 模型请求调用外部工具（function calling）时，负责工具注册、调用分发、结果汇总和事件通知。
 */
export class ToolCallingRuntime {
  /**
   * 事件总线实例，用于发布工具调用和注册事件。
   */
  private events: EventBus;
  /**
   * 按名称保存的工具定义映射表，包含定义记录和执行动作。
   */
  private tools: Map<string, ToolDefinitionInternal> = new Map<string, ToolDefinitionInternal>();

  /**
   * 初始化 ToolCallingRuntime 实例。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 注册工具使其可用。
   * 在应用初始化时由宿主调用，将应用提供的功能暴露给 AI 模型调用。
   * @param params 工具注册参数。
   * @returns 注册后的工具定义记录。
   */
  registerTool(params: ToolRegistrationParams): ToolDefinitionRecord {
    const record: ToolDefinitionRecord = {
      name: params.name,
      displayName: params.displayName,
      description: params.description,
      parametersJson: params.parametersJson,
      permission: params.permission,
      stealth: params.stealth,
      enabled: params.enabled,
    };
    const definition: ToolDefinitionInternal = {
      record: this.copyTool(record),
      action: params.action,
    };
    this.tools.set(record.name, definition);
    const payload: ToolRegisteredPayload = {
      tool: this.copyTool(record),
    };
    this.events.publish<ToolRegisteredPayload>('tool.registered', payload);
    return this.copyTool(record);
  }

  /**
   * 取消注册工具。
   * 在工具不再可用时由宿主调用，从可用工具列表中移除。
   * @param name 要取消注册的工具名称。
   */
  unregisterTool(name: string): void {
    this.tools.delete(name);
  }

  /**
   * 列出所有已注册的工具定义。
   * 在 UI 展示可用工具列表或调试时调用。
   * @returns 工具定义记录数组。
   */
  listTools(): Array<ToolDefinitionRecord> {
    const records = new Array<ToolDefinitionRecord>();
    const values = Array.from(this.tools.values());
    for (let index = 0; index < values.length; index += 1) {
      records.push(this.copyTool(values[index].record));
    }
    return records;
  }

  /**
   * 列出所有已启用的 OpenAI 格式工具定义。
   * 在消息发送给 OpenAI 兼容 API 时调用，将工具定义注入到 API 请求中。
   * @returns OpenAI 格式的工具数组。
   */
  listOpenAITools(): Array<ToolOpenAITool> {
    const result = new Array<ToolOpenAITool>();
    const values = Array.from(this.tools.values());
    for (let index = 0; index < values.length; index += 1) {
      const record = values[index].record;
      if (!record.enabled) {
        continue;
      }
      result.push({
        type: 'function',
        function: {
          name: record.name,
          description: record.description,
          parametersJson: record.parametersJson,
        },
      });
    }
    return result;
  }

  /**
   * 执行一批工具调用，依次调用每个工具并汇总结果。
   * 在收到 AI 模型的工具调用请求后由 ProviderRuntime 调用。
   * @param calls 工具调用请求列表。
   * @param reasoningText 推理过程文本。
   * @returns 所有调用的汇总结果。
   */
  async invokeToolCalls(calls: Array<ToolCallRequest>, reasoningText: string): Promise<ToolInvocationResult> {
    const result = this.createEmptyResult();
    for (let index = 0; index < calls.length; index += 1) {
      await this.invokeOne(calls[index], reasoningText, result);
    }
    return result;
  }

  /**
   * 执行工具调用递归循环，逐批次调用工具，达到 maxDepth 或请求耗尽时停止。
   * 在 AI 模型连续返回多轮 tool_calls 时由 ProviderRuntime 循环调用。
   * @param params 调用循环参数（多批次请求、最大深度、推理文本）。
   * @returns 所有轮次的调用汇总结果。
   */
  async executeCallLoop(params: ToolCallLoopParams): Promise<ToolInvocationResult> {
    const result = this.createEmptyResult();
    for (let depth = 0; depth < params.batches.length; depth += 1) {
      if (depth >= params.maxDepth) {
        this.addError(result, 'ToolCallingRuntime', 'tool call recursion limit exceeded');
        break;
      }
      const batchResult = await this.invokeToolCalls(params.batches[depth], params.reasoningText);
      this.mergeResult(result, batchResult);
    }
    return result;
  }

  /**
   * 格式化工调用记录为可读字符串。
   * @returns 格式化的调用描述。
   */
  formatInvocationMessage(invocation: ToolInvocation): string {
    return `Tool calls: ${invocation.displayName}\n${invocation.name}: ${invocation.result}`;
  }
  private async invokeOne(call: ToolCallRequest, reasoningText: string, result: ToolInvocationResult): Promise<void> {
    const definition = this.tools.get(call.name);
    if (definition === undefined || !definition.record.enabled) {
      const message = `No enabled tool with the name "${call.name}" has been registered.`;
      this.addError(result, call.name, message);
      this.addInvocation(result, call, call.name, message, true, reasoningText);
      return;
    }
    let execution: ToolExecutionResult;
    try {
      execution = await definition.action.execute(call.argumentsJson);
    } catch (error) {
      execution = {
        ok: false,
        result: '',
        error: String(error),
      };
    }

    if (!execution.ok) {
      this.addError(result, call.name, execution.error);
      if (!definition.record.stealth) {
        this.addInvocation(result, call, definition.record.displayName, execution.error, true, reasoningText);
      } else {
        result.stealthCalls.push(call.name);
      }
      return;
    }

    if (definition.record.stealth) {
      result.stealthCalls.push(call.name);
      return;
    }

    this.addInvocation(result, call, definition.record.displayName, execution.result, false, reasoningText);
  }

  /**
   * 添加工具调用记录到结果中，并发布 tool.called 事件。
   * @param result 汇总结果。
   * @param call 原始调用请求。
   * @param displayName 工具显示名称。
   * @param output 执行输出。
   * @param isError 是否出错。
   * @param reasoningText 推理过程文本。
   */
  private addInvocation(
    result: ToolInvocationResult,
    call: ToolCallRequest,
    displayName: string,
    output: string,
    isError: boolean,
    reasoningText: string,
  ): void {
    const reasoning = call.reasoning.length > 0 ? call.reasoning : reasoningText;
    const invocation: ToolInvocation = {
      id: call.id,
      displayName: displayName,
      name: call.name,
      parameters: call.argumentsJson,
      result: output,
      error: isError,
      signature: call.signature,
      reasoning: reasoning,
    };
    result.invocations.push(invocation);
    result.resultMessages.push(this.formatInvocationMessage(invocation));
    const payload: ToolCalledPayload = {
      invocation: this.copyInvocation(invocation),
    };
    this.events.publish<ToolCalledPayload>('tool.called', payload);
  }

  /**
   * 添加错误记录到结果中，并发布 tool.error 事件。
   * @param result 汇总结果。
   * @param toolName 出错工具名称。
   * @param message 错误消息。
   */
  private addError(result: ToolInvocationResult, toolName: string, message: string): void {
    const error: ToolErrorRecord = {
      toolName: toolName,
      message: message,
    };
    result.errors.push(error);
    const payload: ToolErrorPayload = {
      error: this.copyError(error),
    };
    this.events.publish<ToolErrorPayload>('tool.error', payload);
  }

  /**
   * 创建一个空的 ToolInvocationResult。
   * @returns 初始化的空结果。
   */
  private createEmptyResult(): ToolInvocationResult {
    return {
      invocations: new Array<ToolInvocation>(),
      errors: new Array<ToolErrorRecord>(),
      stealthCalls: new Array<string>(),
      resultMessages: new Array<string>(),
    };
  }
  private mergeResult(target: ToolInvocationResult, source: ToolInvocationResult): void {
    for (let index = 0; index < source.invocations.length; index += 1) {
      target.invocations.push(source.invocations[index]);
    }
    for (let index = 0; index < source.errors.length; index += 1) {
      target.errors.push(source.errors[index]);
    }
    for (let index = 0; index < source.stealthCalls.length; index += 1) {
      target.stealthCalls.push(source.stealthCalls[index]);
    }
    for (let index = 0; index < source.resultMessages.length; index += 1) {
      target.resultMessages.push(source.resultMessages[index]);
    }
  }

  /**
   * 深度复制 ToolDefinitionRecord，防止外部代码修改内部状态。
   * @param record 工具定义记录。
   */
  private copyTool(record: ToolDefinitionRecord): ToolDefinitionRecord {
    return {
      name: record.name,
      displayName: record.displayName,
      description: record.description,
      parametersJson: record.parametersJson,
      permission: record.permission,
      stealth: record.stealth,
      enabled: record.enabled,
    };
  }

  /**
   * 深度复制 ToolInvocation，防止外部代码修改内部状态。
   */
  private copyInvocation(invocation: ToolInvocation): ToolInvocation {
    return {
      id: invocation.id,
      displayName: invocation.displayName,
      name: invocation.name,
      parameters: invocation.parameters,
      result: invocation.result,
      error: invocation.error,
      signature: invocation.signature,
      reasoning: invocation.reasoning,
    };
  }

  /**
   * 深度复制 ToolErrorRecord，防止外部代码修改内部状态。
   * @param error 错误记录。
   */
  private copyError(error: ToolErrorRecord): ToolErrorRecord {
    return {
      toolName: error.toolName,
      message: error.message,
    };
  }
}
