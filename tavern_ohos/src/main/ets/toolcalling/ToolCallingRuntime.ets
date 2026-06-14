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
 */
interface ToolDefinitionInternal {
  /**
   * 工具定义的持久化记录。
   */
  record: ToolDefinitionRecord;
  /**
   * 工具的执行逻辑。
   */
  action: ToolAction;
}

/**
 * 提供工具调用相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ToolCallingRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * tools 映射表，以工具名称为键，存储完整的工具定义。
   */
  private tools: Map<string, ToolDefinitionInternal> = new Map<string, ToolDefinitionInternal>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 向运行时注册一个工具，使其可在后续的调用循环中使用。
   * @param params 工具的注册参数，包含名称、描述、执行逻辑等。
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
   * 从运行时移除一个已注册的工具，使其不再被后续流程调用。
   * @param name 要移除的工具名称。
   */
  unregisterTool(name: string): void {
    this.tools.delete(name);
  }

  /**
   * 读取Tools列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 工具调用记录列表副本。
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
   * 读取OpenAITools列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 工具调用记录列表副本。
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
   * 执行一批工具调用请求，汇总所有结果。
   * @param calls 需要执行的工具调用请求列表。
   * @param reasoningText 触发本次调用的推理文本，透传给每条调用记录。
   */
  async invokeToolCalls(calls: Array<ToolCallRequest>, reasoningText: string): Promise<ToolInvocationResult> {
    const result = this.createEmptyResult();
    for (let index = 0; index < calls.length; index += 1) {
      await this.invokeOne(calls[index], reasoningText, result);
    }
    return result;
  }

  /**
   * 执行工具调用的多层循环，按批次依次调用，受 maxDepth 限制。
   * @param params 包含按批次组织的请求列表和深度限制的循环参数。
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
   * 将一次工具调用结果格式化为可读文本，供消息展示使用。
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
   * 创建或写入Invocation，完成持久化后返回可供调用方使用的结果。
   * @param result 返回结果。

   * @param displayName display名称。
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
   * 创建或写入Error，完成持久化后返回可供调用方使用的结果。
   * @param result 返回结果。
   * @param toolName tool名称。
   * @param message 消息记录。
   */
  private addError(result: ToolInvocationResult, toolName: string, message: string): void {
    // 错误信息。
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
   * 创建新的空结果记录，写入存储并返回副本。
   * @returns 工具调用结果记录副本。
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
   * 复制Tool 值，避免外部修改内部状态。
   * @param record 记录副本。
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
   * 复制Invocation 值，避免外部修改内部状态。
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
   * 复制Error 值，避免外部修改内部状态。
   * @param error 错误信息。
   */
  private copyError(error: ToolErrorRecord): ToolErrorRecord {
    return {
      toolName: error.toolName,
      message: error.message,
    };
  }
}
