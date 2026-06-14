import { EventBus } from '../runtime/EventBus';
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
 * 描述命令模块运行时内部的命令定义结构。
 */
interface CommandDefinitionInternal {
  /**
   * 命令的持久化记录数据。
   */
  record: CommandRecord;
  /**
   * 命令的执行行为实现。
   */
  action: CommandAction;
}

/**
 * 提供命令相关的无 UI 运行时能力，负责命令的注册、解析、执行和事件发布，
 * 供聊天输入框中的斜杠命令处理、命令行界面和脚本执行等场景调用。
 */
export class CommandRuntime {
  /**
   * 事件总线，用于发布命令注册、执行成功和失败等事件。
   */
  private events: EventBus;
  /**
   * 已注册的命令映射表，键为命令名称。
   */
  private commands: Map<string, CommandDefinitionInternal> = new Map<string, CommandDefinitionInternal>();
  /**
   * 命令别名映射表，键为别名，值为对应的命令名称。
   */
  private aliases: Map<string, string> = new Map<string, string>();

  /**
   * 初始化当前运行时实例，在应用启动或进入命令处理环境时调用。
   * @param events 事件总线，用于在命令注册、执行成功、执行失败后发布事件通知其他模块。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 注册命令，在外部模块初始化或新增命令时调用。
   * 流程：创建命令记录 -> 建立命令名称映射 -> 建立别名映射 -> 发布 command.registered 事件。
   * @param params 包含命令名称、别名、权限和实现行为的注册参数，由外部模块在启动或按需时提供。
   * @returns 注册后的命令记录副本，用于注册结果确认。
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
   * 取消注册命令，移除别名映射，在模块卸载或命令替换时调用。
   * 流程：根据名称或别名解析标准名称 -> 删除别名映射 -> 从命令表移除。
   * @param name 命令名称或别名，由取消注册操作传入。
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
   * 解析命令文本，提取命令名称、命名参数和未命名参数，在用户输入斜杠命令时由执行流程调用。
   * 文本格式："/commandName arg1 key=val" -> 命令名为 commandName，命名参数 key=val，未命名参数 arg1。
   * @param text 以斜杠开头的命令文本（如 "/command arg1 key=val"），由聊天输入框或命令行输入提供。
   * @returns 解析后的结构化命令输入，供命令执行使用。
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
   * 执行文本格式的命令（单条命令，不支持管道），在聊天输入框或其他单条命令执行场景调用。
   * 流程：parseText 解析 -> resolveCommandName 解析别名 -> 校验权限和启用状态 -> 调用 action.execute -> 发布执行成功/失败事件。
   * @param text 以斜杠开头的命令文本，由输入框提交时传入。
   * @param options 执行控制选项，包含权限列表和取消状态，由调用方根据当前上下文提供。
   * @returns 命令执行结果，包含 output、ok、error 等字段。
   */
  async executeText(text: string, options: CommandExecuteOptions): Promise<CommandExecutionResult> {
    const parsed = this.parseText(text);
    return await this.executeParsed(parsed, '', options);
  }

  /**
   * 执行管道命令，以管道符 | 分隔多段命令，前一段的输出作为下一段的管道输入，在需要链式处理命令时调用。
   * 流程：splitPipeline 分割 -> 逐段 parseText -> 逐段执行 -> 失败时中断并返回聚合结果。
   * @param text 包含管道符的命令文本，如 "/cmd1 | /cmd2 key=val"，由管道命令输入提供。
   * @param options 执行控制选项，包含权限列表和取消状态，传递给每段命令的执行过程。
   * @returns 管道执行的聚合结果，包含每步结果和最终输出。
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
   * 根据输入前缀返回匹配的命令名和别名列表，在用户输入命令时提供自动补全建议。
   * @param prefix 输入的前缀字符串，由输入框的自动补全触发传递。
   * @returns 按字母排序的匹配命令名称列表，用于 UI 显示补全下拉选项。
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
   * 获取指定命令的帮助文本，在用户查询命令帮助时调用。
   * @param name 命令名称或别名，由帮助查询操作传入。
   * @returns 命令的帮助说明文本，未找到时返回空字符串。
   */
  getHelp(name: string): string {
    const definition = this.commands.get(this.resolveCommandName(name));
    if (definition === undefined) {
      return '';
    }
    return definition.record.helpText;
  }

  /**
   * 读取所有已注册命令的列表，在展示命令列表或帮助页面时调用。
   * @returns 已注册命令的记录副本列表，用于命令列表展示和帮助信息输出。
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
   * 发布命令执行失败事件，并构造 CommandExecutionResult 返回。
   * @param invocation 命令调用的上下文信息。
   * @param message 错误描述信息。
   * @param cancelled 是否因取消而失败。
   * @returns 构造的失败执行结果。
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
   * 解析命令名称，如果输入是别名则返回对应的标准名称。
   * @param name 命令名称或别名。
   * @returns 解析后的标准命令名称。
   */
  private resolveCommandName(name: string): string {
    const aliasTarget = this.aliases.get(name);
    if (aliasTarget !== undefined) {
      return aliasTarget;
    }
    return name;
  }

  /**
   * 检查当前上下文是否包含执行指定命令所需的权限。
   * @param permission 命令所需的权限标识。
   * @param allowedPermissions 当前上下文允许的权限列表。
   * @returns true 表示有权执行，false 表示无权限。
   */
  private hasPermission(permission: string, allowedPermissions: Array<string>): boolean {
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
   * 把命令文本拆分为 token 列表，支持引号包裹的带空格文本。
   * @param text 待拆分的命令文本（不含开头的斜杠）。
   * @returns 拆分后的 token 列表。
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
   * 判断字符是否为空白字符（空格、制表符、换行符、回车符）。
   * @param char 待判断的字符。
   * @returns true 表示是空白字符。
   */
  private isWhitespace(char: string): boolean {
    return char === ' ' || char === '\t' || char === '\n' || char === '\r';
  }

  /**
   * 复制命令记录，避免外部修改内部状态。
   * @param record 原始命令记录。
   * @returns 命令记录的副本。
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
   * @param result 原始执行结果。
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
   * @param invocation 原始调用上下文。
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
