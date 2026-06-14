import type { RuntimePermission } from '../contracts/PublicContracts';

/**
 * 描述命令操作完成后返回给调用方的结果。
 */
export interface CommandExecutionResult {
  /**
   * 命令是否执行成功。
   */
  ok: boolean;
  /**
   * 所执行命令的名称。
   */
  commandName: string;
  /**
   * 命令执行后输出的文本内容。
   */
  output: string;
  /**
   * 命令执行失败时的错误描述。
   */
  error: string;
  /**
   * 命令是否已被取消。
   */
  cancelled: boolean;
}

/**
 * 定义命令执行时的回调行为，由命令注册方提供。
 */
export interface CommandAction {
  /**
   * 执行命令并返回结果。
   */
  execute(invocation: CommandInvocation): Promise<CommandExecutionResult>;
}

/**
 * 注册命令时需要提供的参数。
 */
export interface CommandRegistrationParams {
  /**
   * 命令名称。
   */
  name: string;
  /**
   * 命令别名列表。
   */
  aliases: Array<string>;
  /**
   * 命令的帮助文档文本。
   */
  helpText: string;
  /**
   * 执行此命令所需的运行时权限。
   */
  permission: RuntimePermission;
  /**
   * 命令返回值类型的描述文本。
   */
  returns: string;
  /**
   * 命令是否已启用。
   */
  enabled: boolean;
  /**
   * 命令执行时的回调定义。
   */
  action: CommandAction;
}

/**
 * 命令的持久化或内存索引记录。
 */
export interface CommandRecord {
  /**
   * 命令名称。
   */
  name: string;
  /**
   * 命令别名列表。
   */
  aliases: Array<string>;
  /**
   * 命令的帮助文档文本。
   */
  helpText: string;
  /**
   * 执行此命令所需的运行时权限。
   */
  permission: RuntimePermission;
  /**
   * 命令返回值类型的描述文本。
   */
  returns: string;
  /**
   * 命令是否已启用。
   */
  enabled: boolean;
}

/**
 * 描述命令的命名参数键值对。
 */
export interface CommandNamedArgument {
  /**
   * 参数名称。
   */
  name: string;
  /**
   * 参数值。
   */
  value: string;
}

/**
 * 描述解析后的命令输入。
 */
export interface CommandParsedInput {
  /**
   * 命令名称。
   */
  commandName: string;
  /**
   * 命名参数列表。
   */
  namedArguments: Array<CommandNamedArgument>;
  /**
   * 未命名参数文本。
   */
  unnamedArgument: string;
}

/**
 * 控制命令执行行为的选项。
 */
export interface CommandExecuteOptions {
  /**
   * 当前上下文允许的权限列表。
   */
  allowedPermissions: Array<RuntimePermission>;
  /**
   * 命令是否已取消。
   */
  cancelled: boolean;
}

/**
 * 描述命令流水线执行完成后返回给调用方的结果。
 */
export interface CommandPipelineResult {
  /**
   * 流水线是否全部执行成功。
   */
  ok: boolean;
  /**
   * 流水线最终输出的文本。
   */
  finalOutput: string;
  /**
   * 流水线中每一步的命令执行结果。
   */
  steps: Array<CommandExecutionResult>;
  /**
   * 流水线执行失败时的错误描述。
   */
  error: string;
  /**
   * 流水线是否已取消。
   */
  cancelled: boolean;
}

/**
 * 命令执行完成时事件发布携带的数据。
 */
export interface CommandExecutedPayload {
  /**
   * 命令执行结果。
   */
  result: CommandExecutionResult;
  /**
   * 命令调用上下文。
   */
  invocation: CommandInvocation;
}

/**
 * 命令执行出错时事件发布携带的数据。
 */
export interface CommandErrorPayload {
  /**
   * 命令执行结果。
   */
  result: CommandExecutionResult;
  /**
   * 命令调用上下文。
   */
  invocation: CommandInvocation;
}

/**
 * 命令注册完成时事件发布携带的数据。
 */
export interface CommandRegisteredPayload {
  /**
   * 注册的命令记录。
   */
  command: CommandRecord;
}

/**
 * 封装一次命令调用的完整上下文。
 */
export class CommandInvocation {
  /**
   * 命令名称。
   */
  commandName: string;
  /**
   * 命名参数列表。
   */
  namedArguments: Array<CommandNamedArgument>;
  /**
   * 未命名参数文本。
   */
  unnamedArgument: string;
  /**
   * 管道传入的输入文本。
   */
  pipeInput: string;
  /**
   * 本次调用是否已被取消。
   */
  cancelled: boolean;

  /**
   * 构造一次命令调用上下文。
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
   * 获取指定名称的命名参数值，不存在时返回空字符串。
   * @param name 参数名称。
   * @returns 参数值。
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
