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

interface ToolDefinitionInternal {
  record: ToolDefinitionRecord;
  action: ToolAction;
}

export class ToolCallingRuntime {
  private events: EventBus;
  private tools: Map<string, ToolDefinitionInternal> = new Map<string, ToolDefinitionInternal>();

  constructor(events: EventBus) {
    this.events = events;
  }

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

  unregisterTool(name: string): void {
    this.tools.delete(name);
  }

  listTools(): Array<ToolDefinitionRecord> {
    const records = new Array<ToolDefinitionRecord>();
    const values = Array.from(this.tools.values());
    for (let index = 0; index < values.length; index += 1) {
      records.push(this.copyTool(values[index].record));
    }
    return records;
  }

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

  async invokeToolCalls(calls: Array<ToolCallRequest>, reasoningText: string): Promise<ToolInvocationResult> {
    const result = this.createEmptyResult();
    for (let index = 0; index < calls.length; index += 1) {
      await this.invokeOne(calls[index], reasoningText, result);
    }
    return result;
  }

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

  private copyError(error: ToolErrorRecord): ToolErrorRecord {
    return {
      toolName: error.toolName,
      message: error.message,
    };
  }
}
