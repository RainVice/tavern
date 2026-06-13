export interface ToolExecutionResult {
  ok: boolean;
  result: string;
  error: string;
}

export interface ToolAction {
  execute(argumentsJson: string): Promise<ToolExecutionResult>;
}

export interface ToolRegistrationParams {
  name: string;
  displayName: string;
  description: string;
  parametersJson: string;
  permission: string;
  stealth: boolean;
  enabled: boolean;
  action: ToolAction;
}

export interface ToolDefinitionRecord {
  name: string;
  displayName: string;
  description: string;
  parametersJson: string;
  permission: string;
  stealth: boolean;
  enabled: boolean;
}

export interface ToolCallRequest {
  id: string;
  name: string;
  argumentsJson: string;
  signature: string;
  reasoning: string;
}

export interface ToolInvocation {
  id: string;
  displayName: string;
  name: string;
  parameters: string;
  result: string;
  error: boolean;
  signature: string;
  reasoning: string;
}

export interface ToolErrorRecord {
  toolName: string;
  message: string;
}

export interface ToolInvocationResult {
  invocations: Array<ToolInvocation>;
  errors: Array<ToolErrorRecord>;
  stealthCalls: Array<string>;
  resultMessages: Array<string>;
}

export interface ToolCallLoopParams {
  batches: Array<Array<ToolCallRequest>>;
  maxDepth: number;
  reasoningText: string;
}

export interface ToolOpenAIFunction {
  name: string;
  description: string;
  parametersJson: string;
}

export interface ToolOpenAITool {
  type: string;
  function: ToolOpenAIFunction;
}

export interface ToolCalledPayload {
  invocation: ToolInvocation;
}

export interface ToolErrorPayload {
  error: ToolErrorRecord;
}

export interface ToolRegisteredPayload {
  tool: ToolDefinitionRecord;
}
