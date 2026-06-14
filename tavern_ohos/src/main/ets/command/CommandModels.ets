/**
 * 描述命令执行完成后返回给调用方的结果，在执行流程结束时构造供调用方判断后续操作。
 */
export interface CommandExecutionResult {
  /**
   * 命令是否执行成功，用于调用方决定是否继续管道流程或展示错误提示。
   */
  ok: boolean;
  /**
   * 被执行的命令名称，用于结果追踪和日志记录。
   */
  commandName: string;
  /**
   * 命令执行产生的输出文本，如果命令在管道中，此值会作为下一段命令的 pipeInput。
   */
  output: string;
  /**
   * 命令执行失败时的错误信息，用于 UI 展示错误详情。
   */
  error: string;
  /**
   * 命令是否被取消执行，用于调用方判断是否需要终止后续管道处理。
   */
  cancelled: boolean;
}

/**
 * 描述命令模块在运行时执行命令时的行为接口，命令注册时必须提供此接口的实现。
 */
export interface CommandAction {
  /**
   * 执行命令的核心逻辑，在运行时匹配到对应命令时调用。
   * @param invocation 命令调用的上下文信息，包含名称、参数和管道输入。
   * @returns 命令执行的 Promise 结果，异步执行完成后通知调用方。
   */
  execute(invocation: CommandInvocation): Promise<CommandExecutionResult>;
}

/**
 * 描述注册命令时需要传入的参数，由外部模块在注册命令时提供。
 */
export interface CommandRegistrationParams {
  /**
   * 命令名称，用于在解析和执行时唯一标识该命令。
   */
  name: string;
  /**
   * 命令的别名列表，用户可通过别名触发同一命令，提高输入灵活性。
   */
  aliases: Array<string>;
  /**
   * 命令的帮助说明文本，在用户查询命令帮助时展示。
   */
  helpText: string;
  /**
   * 执行命令所需的权限标识，在本模块未设置时视为无需权限。
   */
  permission: string;
  /**
   * 命令返回值的描述说明，在帮助信息中展示供用户参考。
   */
  returns: string;
  /**
   * 命令是否启用，禁用的命令在解析后不会被执行。
   */
  enabled: boolean;
  /**
   * 命令的行为实现，包含 execute 方法，定义了命令的核心处理逻辑。
   */
  action: CommandAction;
}

/**
 * 描述命令持久化记录或注册后存储的结构，用于命令列表展示和事件发布。
 */
export interface CommandRecord {
  /**
   * 命令名称，用于在解析和执行时唯一标识该命令。
   */
  name: string;
  /**
   * 命令的别名列表，用户可通过别名触发同一命令。
   */
  aliases: Array<string>;
  /**
   * 命令的帮助说明文本，在用户查询命令帮助时展示。
   */
  helpText: string;
  /**
   * 执行命令所需的权限标识，在本模块未设置时视为无需权限。
   */
  permission: string;
  /**
   * 命令返回值的描述说明，在帮助信息中展示。
   */
  returns: string;
  /**
   * 命令是否启用，禁用的命令在解析后不会被执行。
   */
  enabled: boolean;
}

/**
 * 描述命令模块在运行时传递的命名参数结构，形如 key=value 的键值对参数。
 */
export interface CommandNamedArgument {
  /**
   * 参数名称，由等号前的部分解析得到。
   */
  name: string;
  /**
   * 参数的值，由等号后的部分解析得到。
   */
  value: string;
}

/**
 * 描述解析命令文本后得到的结构化输入，包含命令名称和各类参数。
 */
export interface CommandParsedInput {
  /**
   * 命令名称，由斜杠后的第一个 token 解析得到。
   */
  commandName: string;
  /**
   * 命名参数列表（形如 key=value 的参数），供命令执行逻辑按名称取值。
   */
  namedArguments: Array<CommandNamedArgument>;
  /**
   * 未命名参数的文本内容，即不属于 key=value 格式的剩余 token 拼接而成。
   */
  unnamedArgument: string;
}

/**
 * 描述命令执行时的可选控制选项，由调用方提供以约束命令的执行行为。
 */
export interface CommandExecuteOptions {
  /**
   * 当前上下文允许的权限列表，执行前会校验命令所需的权限是否在此列表中。
   */
  allowedPermissions: Array<string>;
  /**
   * 是否已取消执行，若为 true 则跳过命令的实际执行。
   */
  cancelled: boolean;
}

/**
 * 描述管道命令执行完成后的聚合结果，用于管道流程结束后通知调用方每一步的执行状态。
 */
export interface CommandPipelineResult {
  /**
   * 整个管道是否执行成功（所有步骤均成功），用于调用方判断后续流程。
   */
  ok: boolean;
  /**
   * 管道中最后一个命令的输出文本，作为管道处理的最终结果。
   */
  finalOutput: string;
  /**
   * 管道中每一步命令的执行结果列表，供调用方追踪每个步骤的详情。
   */
  steps: Array<CommandExecutionResult>;
  /**
   * 管道执行过程中的错误信息，当某一步失败时记录在该字段。
   */
  error: string;
  /**
   * 管道是否被取消执行，用于调用方判断是否需要终止后续处理。
   */
  cancelled: boolean;
}

/**
 * 描述命令执行成功后发布事件时携带的数据结构，供监听者获取执行结果和上下文。
 */
export interface CommandExecutedPayload {
  /**
   * 命令执行的最终结果，包含 output、ok 等字段。
   */
  result: CommandExecutionResult;
  /**
   * 命令调用的上下文信息，包含名称、参数等。
   */
  invocation: CommandInvocation;
}

/**
 * 描述命令执行失败后发布事件时携带的数据结构，供监听者处理错误和展示提示。
 */
export interface CommandErrorPayload {
  /**
   * 命令执行的失败结果，包含 error 信息和取消状态。
   */
  result: CommandExecutionResult;
  /**
   * 命令调用的上下文信息，包含名称、参数等。
   */
  invocation: CommandInvocation;
}

/**
 * 描述命令注册成功后发布事件时携带的数据结构，供监听者更新命令列表 UI。
 */
export interface CommandRegisteredPayload {
  /**
   * 已注册的命令记录，包括名称、别名和权限等信息。
   */
  command: CommandRecord;
}

/**
 * 封装命令调用的上下文信息，包含命令名称、参数和管道输入等运行时状态，
 * 传递给 CommandAction.execute() 供命令实现使用。
 */
export class CommandInvocation {
  /**
   * 被调用的命令名称，用于运行时分发到对应的 CommandAction 执行。
   */
  commandName: string;
  /**
   * 解析得到的命名参数列表，供命令实现按名称获取参数的值。
   */
  namedArguments: Array<CommandNamedArgument>;
  /**
   * 未命名的参数文本，即命令后的非 key=value 格式的剩余文本。
   */
  unnamedArgument: string;
  /**
   * 管道前一步传递过来的输入文本，作为当前命令的额外数据源（例如作为待处理文本）。
   */
  pipeInput: string;
  /**
   * 是否已取消执行，若为 true 则命令应跳过执行并返回取消状态。
   */
  cancelled: boolean;

  /**
   * 初始化命令调用上下文，在命令执行前的解析阶段构造。
   * @param commandName 被调用的命令名称，由 parseText 解析得到。
   * @param namedArguments 命名参数列表，由 parseText 从 key=value 格式提取。
   * @param unnamedArgument 未命名参数文本，由 parseText 提取的非命名参数部分。
   * @param pipeInput 管道前一步的输入文本，当前一步命令的 output 传递而来。
   * @param cancelled 是否已取消执行，阻止实际执行时传入 true。
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
   * 根据参数名获取命名参数的值，在命令执行逻辑中按名称查询特定参数。
   * @param name 要查找的参数名称，由命令实现按需传入。
   * @returns 参数的值，未找到时返回空字符串。
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
