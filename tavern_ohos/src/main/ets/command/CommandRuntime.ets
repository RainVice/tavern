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
 * 描述命令模块在运行时交换的数据结构。
 */
interface CommandDefinitionInternal {
  /**
   * 记录数据。
   */
  record: CommandRecord;
  /**
   * action 值，由当前实例内部维护。
   */
  action: CommandAction;
}

/**
 * 提供命令相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class CommandRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * commands 列表，由当前实例内部维护。
   */
  private commands: Map<string, CommandDefinitionInternal> = new Map<string, CommandDefinitionInternal>();
  /**
   * aliases 列表，由当前实例内部维护。
   */
  private aliases: Map<string, string> = new Map<string, string>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 注册Command 值，使其可被后续运行时流程使用。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 取消注册Command 值，避免后续流程继续调用。
   * @param name 显示名称或注册名称。
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
   * 解析Text，非法输入会返回失败标记或空结果。
   * @param text 文本内容。
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
    // command 名称。
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
   * 执行 executeText 的内部处理步骤，供当前模块复用。
   * @param text 文本内容。
   * @param options 控制本次调用行为的选项。
   */
  async executeText(text: string, options: CommandExecuteOptions): Promise<CommandExecutionResult> {
    const parsed = this.parseText(text);
    return await this.executeParsed(parsed, '', options);
  }

  /**
   * 执行 executePipeline 的内部处理步骤，供当前模块复用。
   * @param text 文本内容。
   * @param options 控制本次调用行为的选项。
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
   * 执行 autocomplete 的内部处理步骤，供当前模块复用。
   * @param prefix CIDR 前缀长度。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 读取指定Help，不存在时抛出错误。
   * @param name 显示名称或注册名称。
   * @returns 更新或读取后的记录副本。
   */
  getHelp(name: string): string {
    const definition = this.commands.get(this.resolveCommandName(name));
    if (definition === undefined) {
      return '';
    }
    return definition.record.helpText;
  }

  /**
   * 读取Commands列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
    // command 名称。
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
   * 发布命令事件，把状态变化通知给宿主或其他 Runtime。

   * @param message 消息记录。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 根据当前上下文解析Command 名称，返回实际可用值。
   * @param name 显示名称或注册名称。
   */
  private resolveCommandName(name: string): string {
    const aliasTarget = this.aliases.get(name);
    if (aliasTarget !== undefined) {
      return aliasTarget;
    }
    return name;
  }

  /**
   * 判断当前对象是否包含Permission 值。


   * @returns 条件命中时返回 true，否则返回 false。
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
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 判断Whitespace 值是否满足条件。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  private isWhitespace(char: string): boolean {
    return char === ' ' || char === '\t' || char === '\n' || char === '\r';
  }

  /**
   * 复制Command 值，避免外部修改内部状态。
   * @param record 记录副本。
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
   * 复制Result 值，避免外部修改内部状态。
   * @param result 返回结果。
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
   * 复制Invocation 值，避免外部修改内部状态。
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
