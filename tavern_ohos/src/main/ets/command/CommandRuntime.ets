import { EventBus } from '../runtime/EventBus';
import type { RuntimePermission } from '../contracts/PublicContracts';
import type {
  CommandAction,
  CommandErrorPayload,
  CommandExecutedPayload,
  CommandExecuteOptions,
  CommandExecutionResult,
  CommandNamedArgument,
  CommandParsedInput,
  CommandPipelineResult,
  CommandRecord,
  CommandRegisteredPayload,
  CommandRegistrationParams,
} from './CommandModels';
import { CommandInvocation } from './CommandModels';

/**
 * 命令注册后的内部定义，包含记录和可执行动作。
 */
interface CommandDefinitionInternal {
  /**
   * 命令记录信息。
   */
  record: CommandRecord;
  /**
   * 命令的可执行回调。
   */
  action: CommandAction;
}

/**
 * 命令运行时的无 UI 能力层，负责命令注册、解析、执行和事件发布。
 */
export class CommandRuntime {
  /**
   * 事件总线实例。
   */
  private events: EventBus;
  /**
   * 已注册的命令定义映射，键为命令名称。
   */
  private commands: Map<string, CommandDefinitionInternal> = new Map<string, CommandDefinitionInternal>();
  /**
   * 别名到标准名称的映射。
   */
  private aliases: Map<string, string> = new Map<string, string>();

  /**
   * 构造命令运行时实例。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 注册一条命令，使其可被后续运行时流程调用。
   * @param params 命令注册参数。
   * @returns 注册成功的命令记录副本。
   */
  registerCommand(params: CommandRegistrationParams): CommandRecord {
    const record: CommandRecord = {
      name: params.name,
      aliases: params.aliases.slice(),
      helpText: params.helpText,
      permission: params.permission,
      returns: params.returns,
      enabled: params.enabled,
    };
    const definition: CommandDefinitionInternal = {
      record: this.copyCommand(record),
      action: params.action,
    };
    this.commands.set(record.name, definition);
    for (let index = 0; index < record.aliases.length; index += 1) {
      this.aliases.set(record.aliases[index], record.name);
    }
    const payload: CommandRegisteredPayload = {
      command: this.copyCommand(record),
    };
    this.events.publish<CommandRegisteredPayload>('command.registered', payload);
    return this.copyCommand(record);
  }

  /**
   * 取消注册一条命令，使其不再响应调用。
   * @param name 命令名称或别名。
   */
  unregisterCommand(name: string): void {
    const canonical = this.resolveCommandName(name);
    const definition = this.commands.get(canonical);
    if (definition !== undefined) {
      for (let index = 0; index < definition.record.aliases.length; index += 1) {
        this.aliases.delete(definition.record.aliases[index]);
      }
    }
    this.commands.delete(canonical);
    this.aliases.delete(name);
  }

  /**
   * 解析命令文本，提取出结构化的命令输入。
   * @param text 以斜杠开头的命令文本。
   * @returns 解析后的命令输入。
   */
  parseText(text: string): CommandParsedInput {
    const trimmed = text.trim();
    if (!trimmed.startsWith('/')) {
      throw new Error('Command text must start with slash.');
    }
    const withoutSlash = trimmed.substring(1).trim();
    const tokens = this.tokenize(withoutSlash);
    if (tokens.length === 0) {
      throw new Error('Command name is missing.');
    }
    // 命令名称取自第一个 token。
    const commandName = tokens[0];
    const namedArguments = new Array<CommandNamedArgument>();
    const unnamed = new Array<string>();
    for (let index = 1; index < tokens.length; index += 1) {
      const token = tokens[index];
      const equals = token.indexOf('=');
      if (equals > 0) {
        const argument: CommandNamedArgument = {
          name: token.substring(0, equals),
          value: token.substring(equals + 1),
        };
        namedArguments.push(argument);
      } else {
        unnamed.push(token);
      }
    }
    return {
      commandName: commandName,
      namedArguments: namedArguments,
      unnamedArgument: unnamed.join(' '),
    };
  }

  /**
   * 执行一条命令文本，返回单步执行结果。
   * @param text 命令文本。
   * @param options 执行选项。
   * @returns 命令执行结果。
   */
  async executeText(text: string, options: CommandExecuteOptions): Promise<CommandExecutionResult> {
    const parsed = this.parseText(text);
    return await this.executeParsed(parsed, '', options);
  }

  /**
   * 执行命令流水线（按 | 分割的多段命令），每段输出作为下一段输入。
   * @param text 包含管道符的命令文本。
   * @param options 执行选项。
   * @returns 流水线执行结果。
   */
  async executePipeline(text: string, options: CommandExecuteOptions): Promise<CommandPipelineResult> {
    const segments = this.splitPipeline(text);
    const steps = new Array<CommandExecutionResult>();
    let pipeInput = '';
    for (let index = 0; index < segments.length; index += 1) {
      const parsed = this.parseText(segments[index]);
      const step = await this.executeParsed(parsed, pipeInput, options);
      steps.push(step);
      if (!step.ok) {
        return {
          ok: false,
          finalOutput: pipeInput,
          steps: steps,
          error: step.error,
          cancelled: step.cancelled,
        };
      }
      pipeInput = step.output;
    }
    return {
      ok: true,
      finalOutput: pipeInput,
      steps: steps,
      error: '',
      cancelled: false,
    };
  }

  /**
   * 根据前缀补全可用的命令名称和别名。
   * @param prefix 命令名称前缀。
   * @returns 匹配的命令名称和别名列表，按字典序排序。
   */
  autocomplete(prefix: string): Array<string> {
    const result = new Array<string>();
    const names = Array.from(this.commands.keys());
    for (let index = 0; index < names.length; index += 1) {
      if (names[index].startsWith(prefix)) {
        result.push(names[index]);
      }
    }
    const aliases = Array.from(this.aliases.keys());
    for (let index = 0; index < aliases.length; index += 1) {
      if (aliases[index].startsWith(prefix)) {
        result.push(aliases[index]);
      }
    }
    result.sort();
    return result;
  }

  /**
   * 获取指定命令的帮助文本。
   * @param name 命令名称或别名。
   * @returns 帮助文本，命令不存在时返回空字符串。
   */
  getHelp(name: string): string {
    const definition = this.commands.get(this.resolveCommandName(name));
    if (definition === undefined) {
      return '';
    }
    return definition.record.helpText;
  }

  /**
   * 列出所有已注册的命令记录。
   * @returns 命令记录列表，返回副本以保护内部状态。
   */
  listCommands(): Array<CommandRecord> {
    const result = new Array<CommandRecord>();
    const definitions = Array.from(this.commands.values());
    for (let index = 0; index < definitions.length; index += 1) {
      result.push(this.copyCommand(definitions[index].record));
    }
    return result;
  }
  private async executeParsed(
    parsed: CommandParsedInput,
    pipeInput: string,
    options: CommandExecuteOptions,
  ): Promise<CommandExecutionResult> {
    // 通过别名解析出标准命令名称。
    const commandName = this.resolveCommandName(parsed.commandName);
    const invocation = new CommandInvocation(
      commandName,
      parsed.namedArguments,
      parsed.unnamedArgument,
      pipeInput,
      options.cancelled,
    );
    const definition = this.commands.get(commandName);
    if (definition === undefined || !definition.record.enabled) {
      return this.publishError(invocation, 'Command not found or disabled.');
    }
    if (options.cancelled) {
      return this.publishError(invocation, 'Command cancelled.', true);
    }
    if (!this.hasPermission(definition.record.permission, options.allowedPermissions)) {
      return this.publishError(invocation, `Missing permission: ${definition.record.permission}`);
    }
    let result: CommandExecutionResult;
    try {
      result = await definition.action.execute(invocation);
    } catch (error) {
      result = {
        ok: false,
        commandName: commandName,
        output: '',
        error: String(error),
        cancelled: false,
      };
    }
    if (result.ok) {
      const payload: CommandExecutedPayload = {
        result: this.copyResult(result),
        invocation: this.copyInvocation(invocation),
      };
      this.events.publish<CommandExecutedPayload>('command.executed', payload);
    } else {
      const payload: CommandErrorPayload = {
        result: this.copyResult(result),
        invocation: this.copyInvocation(invocation),
      };
      this.events.publish<CommandErrorPayload>('command.error', payload);
    }
    return result;
  }

  /**
   * 发布命令错误事件并返回失败结果。
   * @param invocation 命令调用上下文。
   * @param message 错误消息。
   * @param cancelled 是否因取消而失败。
   * @returns 错误执行结果。
   */
  private publishError(invocation: CommandInvocation, message: string, cancelled: boolean = false): CommandExecutionResult {
    const result: CommandExecutionResult = {
      ok: false,
      commandName: invocation.commandName,
      output: '',
      error: message,
      cancelled: cancelled,
    };
    const payload: CommandErrorPayload = {
      result: this.copyResult(result),
      invocation: this.copyInvocation(invocation),
    };
    this.events.publish<CommandErrorPayload>('command.error', payload);
    return result;
  }

  /**
   * 解析命令名称，若为别名则返回对应的标准名称。
   * @param name 命令名称或别名。
   * @returns 标准命令名称。
   */
  private resolveCommandName(name: string): string {
    const aliasTarget = this.aliases.get(name);
    if (aliasTarget !== undefined) {
      return aliasTarget;
    }
    return name;
  }

  /**
   * 判断权限列表中是否包含执行命令所需的指定权限。
   * @param permission 所需的权限。
   * @param allowedPermissions 当前可用的权限列表。
   * @returns 权限满足时返回 true。
   */
  private hasPermission(permission: RuntimePermission, allowedPermissions: Array<RuntimePermission>): boolean {
    if (permission.length === 0) {
      return true;
    }
    for (let index = 0; index < allowedPermissions.length; index += 1) {
      if (allowedPermissions[index] === permission) {
        return true;
      }
    }
    return false;
  }
  private splitPipeline(text: string): Array<string> {
    const parts = new Array<string>();
    let current = '';
    let quoted = false;
    for (let index = 0; index < text.length; index += 1) {
      const char = text.charAt(index);
      if (char === '"') {
        quoted = !quoted;
        current += char;
      } else if (char === '|' && !quoted) {
        parts.push(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    if (current.trim().length > 0) {
      parts.push(current.trim());
    }
    return parts;
  }

  /**
   * 把命令文本拆分为 token 列表。
   * @param text 文本内容。
   * @returns token 列表。
   */
  private tokenize(text: string): Array<string> {
    const tokens = new Array<string>();
    let current = '';
    let quoted = false;
    for (let index = 0; index < text.length; index += 1) {
      const char = text.charAt(index);
      if (char === '"') {
        quoted = !quoted;
      } else if (this.isWhitespace(char) && !quoted) {
        if (current.length > 0) {
          tokens.push(current);
          current = '';
        }
      } else {
        current += char;
      }
    }
    if (current.length > 0) {
      tokens.push(current);
    }
    return tokens;
  }

  /**
   * 判断指定字符是否为空白字符。
   * @param char 待检查字符。
   * @returns 是空白字符时返回 true。
   */
  private isWhitespace(char: string): boolean {
    return char === ' ' || char === '\t' || char === '\n' || char === '\r';
  }

  /**
   * 复制命令记录，避免外部修改内部状态。
   * @param record 待复制的命令记录。
   * @returns 命令记录的深拷贝。
   */
  private copyCommand(record: CommandRecord): CommandRecord {
    return {
      name: record.name,
      aliases: record.aliases.slice(),
      helpText: record.helpText,
      permission: record.permission,
      returns: record.returns,
      enabled: record.enabled,
    };
  }

  /**
   * 复制命令执行结果，避免外部修改内部状态。
   * @param result 待复制的执行结果。
   * @returns 执行结果的副本。
   */
  private copyResult(result: CommandExecutionResult): CommandExecutionResult {
    return {
      ok: result.ok,
      commandName: result.commandName,
      output: result.output,
      error: result.error,
      cancelled: result.cancelled,
    };
  }

  /**
   * 复制命令调用上下文，避免外部修改内部状态。
   * @param invocation 待复制的调用上下文。
   * @returns 调用上下文的副本。
   */
  private copyInvocation(invocation: CommandInvocation): CommandInvocation {
    const namedArguments = new Array<CommandNamedArgument>();
    for (let index = 0; index < invocation.namedArguments.length; index += 1) {
      const argument = invocation.namedArguments[index];
      namedArguments.push({
        name: argument.name,
        value: argument.value,
      });
    }
    return new CommandInvocation(
      invocation.commandName,
      namedArguments,
      invocation.unnamedArgument,
      invocation.pipeInput,
      invocation.cancelled,
    );
  }
}
