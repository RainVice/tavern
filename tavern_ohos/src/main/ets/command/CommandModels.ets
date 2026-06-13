/**
 * 描述命令操作完成后返回给调用方的结果。
 */
export interface CommandExecutionResult {
  /**
   * ok 值，由当前实例内部维护。
   */
  ok: boolean;
  /**
   * command 名称。
   */
  commandName: string;
  /**
   * output 值，由当前实例内部维护。
   */
  output: string;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
  /**
   * cancelled 值，由当前实例内部维护。
   */
  cancelled: boolean;
}

/**
 * 描述命令模块在运行时交换的数据结构。
 */
export interface CommandAction {
  /**
   * 执行 execute 的内部处理步骤，供当前模块复用。
   */
  execute(invocation: CommandInvocation): Promise<CommandExecutionResult>;
}

/**
 * 描述调用命令能力时需要传入的参数。
 */
export interface CommandRegistrationParams {
  /**
   * 名称。
   */
  name: string;
  /**
   * aliases 列表，由当前实例内部维护。
   */
  aliases: Array<string>;
  /**
   * help Text 值，由当前实例内部维护。
   */
  helpText: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: string;
  /**
   * returns 列表，由当前实例内部维护。
   */
  returns: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * action 值，由当前实例内部维护。
   */
  action: CommandAction;
}

/**
 * 描述命令持久化或内存索引中的一条记录。
 */
export interface CommandRecord {
  /**
   * 名称。
   */
  name: string;
  /**
   * aliases 列表，由当前实例内部维护。
   */
  aliases: Array<string>;
  /**
   * help Text 值，由当前实例内部维护。
   */
  helpText: string;
  /**
   * permission 值，由当前实例内部维护。
   */
  permission: string;
  /**
   * returns 列表，由当前实例内部维护。
   */
  returns: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
}

/**
 * 描述命令模块在运行时交换的数据结构。
 */
export interface CommandNamedArgument {
  /**
   * 名称。
   */
  name: string;
  /**
   * 字段值。
   */
  value: string;
}

/**
 * 描述调用命令能力时需要传入的参数。
 */
export interface CommandParsedInput {
  /**
   * command 名称。
   */
  commandName: string;
  /**
   * named Arguments 列表，由当前实例内部维护。
   */
  namedArguments: Array<CommandNamedArgument>;
  /**
   * unnamed Argument 值，由当前实例内部维护。
   */
  unnamedArgument: string;
}

/**
 * 描述命令模块在运行时交换的数据结构。
 */
export interface CommandExecuteOptions {
  /**
   * allowed Permissions 列表，由当前实例内部维护。
   */
  allowedPermissions: Array<string>;
  /**
   * cancelled 值，由当前实例内部维护。
   */
  cancelled: boolean;
}

/**
 * 描述命令操作完成后返回给调用方的结果。
 */
export interface CommandPipelineResult {
  /**
   * ok 值，由当前实例内部维护。
   */
  ok: boolean;
  /**
   * final Output 值，由当前实例内部维护。
   */
  finalOutput: string;
  /**
   * steps 列表，由当前实例内部维护。
   */
  steps: Array<CommandExecutionResult>;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
  /**
   * cancelled 值，由当前实例内部维护。
   */
  cancelled: boolean;
}

/**
 * 描述命令事件发布时携带的数据结构。
 */
export interface CommandExecutedPayload {
  /**
   * 处理结果。
   */
  result: CommandExecutionResult;
  /**
   * invocation 值，由当前实例内部维护。
   */
  invocation: CommandInvocation;
}

/**
 * 描述命令事件发布时携带的数据结构。
 */
export interface CommandErrorPayload {
  /**
   * 处理结果。
   */
  result: CommandExecutionResult;
  /**
   * invocation 值，由当前实例内部维护。
   */
  invocation: CommandInvocation;
}

/**
 * 描述命令事件发布时携带的数据结构。
 */
export interface CommandRegisteredPayload {
  /**
   * command 值，由当前实例内部维护。
   */
  command: CommandRecord;
}

/**
 * 封装命令相关状态和行为。
 */
export class CommandInvocation {
  /**
   * command 名称。
   */
  commandName: string;
  /**
   * named Arguments 列表，由当前实例内部维护。
   */
  namedArguments: Array<CommandNamedArgument>;
  /**
   * unnamed Argument 值，由当前实例内部维护。
   */
  unnamedArgument: string;
  /**
   * pipe Input 值，由当前实例内部维护。
   */
  pipeInput: string;
  /**
   * cancelled 值，由当前实例内部维护。
   */
  cancelled: boolean;

  /**
   * 注入命令运行时依赖并初始化实例状态。
   * @param commandName 命令名称。
   */
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

  /**
   * 读取指定NamedArgument，不存在时抛出错误。
   * @param name 显示名称或注册名称。
   * @returns 更新或读取后的记录副本。
   */
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
