export interface CommandExecutionResult {
  ok: boolean;
  commandName: string;
  output: string;
  error: string;
  cancelled: boolean;
}

export interface CommandAction {
  execute(invocation: CommandInvocation): Promise<CommandExecutionResult>;
}

export interface CommandRegistrationParams {
  name: string;
  aliases: Array<string>;
  helpText: string;
  permission: string;
  returns: string;
  enabled: boolean;
  action: CommandAction;
}

export interface CommandRecord {
  name: string;
  aliases: Array<string>;
  helpText: string;
  permission: string;
  returns: string;
  enabled: boolean;
}

export interface CommandNamedArgument {
  name: string;
  value: string;
}

export interface CommandParsedInput {
  commandName: string;
  namedArguments: Array<CommandNamedArgument>;
  unnamedArgument: string;
}

export interface CommandExecuteOptions {
  allowedPermissions: Array<string>;
  cancelled: boolean;
}

export interface CommandPipelineResult {
  ok: boolean;
  finalOutput: string;
  steps: Array<CommandExecutionResult>;
  error: string;
  cancelled: boolean;
}

export interface CommandExecutedPayload {
  result: CommandExecutionResult;
  invocation: CommandInvocation;
}

export interface CommandErrorPayload {
  result: CommandExecutionResult;
  invocation: CommandInvocation;
}

export interface CommandRegisteredPayload {
  command: CommandRecord;
}

export class CommandInvocation {
  commandName: string;
  namedArguments: Array<CommandNamedArgument>;
  unnamedArgument: string;
  pipeInput: string;
  cancelled: boolean;

  constructor(
    commandName: string,
    namedArguments: Array<CommandNamedArgument>,
    unnamedArgument: string,
    pipeInput: string,
    cancelled: boolean,
  ) {
    this.commandName = commandName;
    this.namedArguments = namedArguments;
    this.unnamedArgument = unnamedArgument;
    this.pipeInput = pipeInput;
    this.cancelled = cancelled;
  }

  getNamedArgument(name: string): string {
    for (let index = 0; index < this.namedArguments.length; index += 1) {
      const argument = this.namedArguments[index];
      if (argument.name === name) {
        return argument.value;
      }
    }
    return '';
  }
}
