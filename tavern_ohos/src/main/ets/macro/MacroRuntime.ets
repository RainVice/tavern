import { EventBus } from '../runtime/EventBus';
import { VariableRuntime } from '../variable/VariableRuntime';
import type {
  MacroAction,
  MacroDiagnostic,
  MacroEvaluationContext,
  MacroExpandedPayload,
  MacroExpansionResult,
  MacroExecutionContext,
  MacroRecord,
  MacroRegisteredPayload,
  MacroRegistrationParams,
} from './MacroModels';

/**
 * 描述宏展开模块在运行时交换的数据结构。
 */
interface MacroDefinitionInternal {
  /**
   * 记录数据。
   */
  record: MacroRecord;
  /**
   * action 值，由当前实例内部维护。
   */
  action: MacroAction;
}

/**
 * 提供宏展开相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class MacroRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * variables 列表，由当前实例内部维护。
   */
  private variables: VariableRuntime;
  /**
   * macros 列表，由当前实例内部维护。
   */
  private macros: Map<string, MacroDefinitionInternal> = new Map<string, MacroDefinitionInternal>();
  /**
   * max Depth 值，由当前实例内部维护。
   */
  private maxDepth: number = 8;

  /**
   * 注入宏展开运行时依赖并初始化实例状态。
   * @param events 事件总线。
   */
  constructor(events: EventBus, variables: VariableRuntime) {
    this.events = events;
    this.variables = variables;
    this.registerBuiltIns();
  }

  /**
   * 注册Macro 值，使其可被后续运行时流程使用。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  registerMacro(params: MacroRegistrationParams): MacroRecord {
    const record: MacroRecord = {
      name: params.name,
      category: params.category,
      description: params.description,
      source: params.source,
      pluginId: params.pluginId,
    };
    const definition: MacroDefinitionInternal = {
      record: this.cloneRecord(record),
      action: params.action,
    };
    this.macros.set(record.name, definition);
    const payload: MacroRegisteredPayload = {
      macro: this.cloneRecord(record),
    };
    this.events.publish<MacroRegisteredPayload>('macro.registered', payload);
    return this.cloneRecord(record);
  }

  /**
   * 取消注册Macro 值，避免后续流程继续调用。
   * @param name 显示名称或注册名称。
   */
  unregisterMacro(name: string): void {
    this.macros.delete(name);
  }

  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   * @param input 待处理的输入对象。
   */
  expand(input: string, context: MacroEvaluationContext): MacroExpansionResult {
    return this.expandWithStrategy(input, context, 'keep');
  }

  /**
   * 执行 expandWithStrategy 的内部处理步骤，供当前模块复用。
   * @param input 待处理的输入对象。
   */
  expandWithStrategy(input: string, context: MacroEvaluationContext, unknownStrategy: string): MacroExpansionResult {
    const diagnostics = new Array<MacroDiagnostic>();
    const output = this.expandText(input, context, unknownStrategy, diagnostics);
    const payload: MacroExpandedPayload = {
      input: input,
      output: output,
      diagnostics: this.cloneDiagnostics(diagnostics),
    };
    this.events.publish<MacroExpandedPayload>('macro.expanded', payload);
    return {
      text: output,
      diagnostics: this.cloneDiagnostics(diagnostics),
    };
  }

  /**
   * 执行 diagnose 的内部处理步骤，供当前模块复用。
   * @param input 待处理的输入对象。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  diagnose(input: string, context: MacroEvaluationContext): Array<MacroDiagnostic> {
    return this.expandWithStrategy(input, context, 'keep').diagnostics;
  }

  /**
   * 执行 autocomplete 的内部处理步骤，供当前模块复用。
   * @param prefix CIDR 前缀长度。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  autocomplete(prefix: string): Array<MacroRecord> {
    const result = new Array<MacroRecord>();
    const definitions = Array.from(this.macros.values());
    for (let index = 0; index < definitions.length; index += 1) {
      if (definitions[index].record.name.startsWith(prefix)) {
        result.push(this.cloneRecord(definitions[index].record));
      }
    }
    result.sort((left: MacroRecord, right: MacroRecord) => left.name.localeCompare(right.name));
    return result;
  }
  private expandText(
    input: string,
    context: MacroEvaluationContext,
    unknownStrategy: string,
    diagnostics: Array<MacroDiagnostic>,
  ): string {
    let output = input;
    for (let depth = 0; depth < this.maxDepth; depth += 1) {
      const next = this.expandOnce(output, context, unknownStrategy, diagnostics);
      output = next.text;
      if (!next.changed) {
        break;
      }
    }
    return output;
  }

  /**
   * 读取Macros列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listMacros(): Array<MacroRecord> {
    const result = new Array<MacroRecord>();
    const definitions = Array.from(this.macros.values());
    for (let index = 0; index < definitions.length; index += 1) {
      result.push(this.cloneRecord(definitions[index].record));
    }
    return result;
  }
  private expandOnce(
    input: string,
    context: MacroEvaluationContext,
    unknownStrategy: string,
    diagnostics: Array<MacroDiagnostic>,
  ): MacroExpandStep {
    let output = '';
    let cursor = 0;
    let changed = false;
    while (cursor < input.length) {
      const start = input.indexOf('{{', cursor);
      if (start < 0) {
        output += input.substring(cursor);
        break;
      }
      output += input.substring(cursor, start);
      const end = this.findMacroEnd(input, start);
      if (end < 0) {
        output += input.substring(start);
        break;
      }
      const raw = input.substring(start, end + 2);
      const body = input.substring(start + 2, end).trim();
      const replacement = this.evaluateMacro(body, raw, start, context, unknownStrategy, diagnostics);
      output += replacement.value;
      if (replacement.changed) {
        changed = true;
      }
      cursor = end + 2;
    }
    return {
      text: output,
      changed: changed,
    };
  }
  private evaluateMacro(
    body: string,
    raw: string,
    offset: number,
    context: MacroEvaluationContext,
    unknownStrategy: string,
    diagnostics: Array<MacroDiagnostic>,
  ): MacroReplaceResult {
    const parts = this.splitMacroBody(body);
    // 名称。
    const name = parts.length === 0 ? '' : parts[0].trim();
    const definition = this.macros.get(name);
    if (definition === undefined) {
      const diagnostic: MacroDiagnostic = {
        macroName: name,
        message: `Unknown macro: ${name}`,
        offset: offset,
        raw: raw,
      };
      this.pushDiagnosticOnce(diagnostics, diagnostic);
      return {
        value: unknownStrategy === 'remove' ? '' : raw,
        changed: unknownStrategy === 'remove',
      };
    }
    const args = new Array<string>();
    for (let index = 1; index < parts.length; index += 1) {
      args.push(this.expandText(parts[index], context, unknownStrategy, diagnostics));
    }
    const executionContext: MacroExecutionContext = {
      name: name,
      args: args,
      raw: raw,
      context: context,
    };
    return {
      value: definition.action.expand(executionContext),
      changed: true,
    };
  }

  private pushDiagnosticOnce(diagnostics: Array<MacroDiagnostic>, diagnostic: MacroDiagnostic): void {
    for (let index = 0; index < diagnostics.length; index += 1) {
      const existing = diagnostics[index];
      if (existing.macroName === diagnostic.macroName && existing.offset === diagnostic.offset && existing.raw === diagnostic.raw) {
        return;
      }
    }
    diagnostics.push(diagnostic);
  }

  /**
   * 在当前集合中查找Macro End 值，未命中时返回空值或默认位置。
   * @param input 待处理的输入对象。
   */
  private findMacroEnd(input: string, start: number): number {
    let depth = 0;
    let index = start + 2;
    while (index < input.length - 1) {
      const pair = input.substring(index, index + 2);
      if (pair === '{{') {
        depth += 1;
        index += 2;
      } else if (pair === '}}') {
        if (depth === 0) {
          return index;
        }
        depth -= 1;
        index += 2;
      } else {
        index += 1;
      }
    }
    return -1;
  }
  private splitMacroBody(body: string): Array<string> {
    const parts = new Array<string>();
    let current = '';
    let depth = 0;
    let index = 0;
    while (index < body.length) {
      const pair = index < body.length - 1 ? body.substring(index, index + 2) : '';
      if (pair === '{{') {
        depth += 1;
        current += pair;
        index += 2;
      } else if (pair === '}}') {
        if (depth > 0) {
          depth -= 1;
        }
        current += pair;
        index += 2;
      } else if (pair === '::' && depth === 0) {
        parts.push(current);
        current = '';
        index += 2;
      } else {
        current += body.charAt(index);
        index += 1;
      }
    }
    parts.push(current);
    return parts;
  }

  /**
   * 注册Built Ins 列表，使其可被后续运行时流程使用。
   */
  private registerBuiltIns(): void {
    this.registerBuiltin('char', 'names', new CharacterNameMacroAction());
    this.registerBuiltin('user', 'names', new UserNameMacroAction());
    this.registerBuiltin('persona', 'character', new PersonaNameMacroAction());
    this.registerBuiltin('chat', 'chat', new ChatNameMacroAction());
    this.registerBuiltin('message', 'chat', new MessageTextMacroAction());
    this.registerBuiltin('worldinfo', 'worldinfo', new WorldInfoNameMacroAction());
    this.registerBuiltin('getvar', 'variable', new GetVariableMacroAction(this.variables));
    this.registerBuiltin('setvar', 'variable', new SetVariableMacroAction(this.variables));
    this.registerBuiltin('if', 'utility', new IfMacroAction());
    this.registerBuiltin('random', 'random', new RandomMacroAction());
    this.registerBuiltin('space', 'utility', new SpaceMacroAction());
    this.registerBuiltin('newline', 'utility', new NewlineMacroAction());
    this.registerBuiltin('noop', 'utility', new NoopMacroAction());
    this.registerBuiltin('isodate', 'time', new IsoDateMacroAction());
    this.registerBuiltin('time', 'time', new TimeMacroAction());
  }

  /**
   * 注册Builtin 值，使其可被后续运行时流程使用。
   * @param name 显示名称或注册名称。


   */
  private registerBuiltin(name: string, category: string, action: MacroAction): void {
    // 调用参数。
    const params: MacroRegistrationParams = {
      name: name,
      category: category,
      description: name,
      source: 'builtin',
      pluginId: '',
      action: action,
    };
    this.registerMacro(params);
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private cloneRecord(record: MacroRecord): MacroRecord {
    return {
      name: record.name,
      category: record.category,
      description: record.description,
      source: record.source,
      pluginId: record.pluginId,
    };
  }

  /**
   * 复制Diagnostics 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneDiagnostics(diagnostics: Array<MacroDiagnostic>): Array<MacroDiagnostic> {
    const cloned = new Array<MacroDiagnostic>();
    for (let index = 0; index < diagnostics.length; index += 1) {
      cloned.push({
        macroName: diagnostics[index].macroName,
        message: diagnostics[index].message,
        offset: diagnostics[index].offset,
        raw: diagnostics[index].raw,
      });
    }
    return cloned;
  }
}

/**
 * 描述宏展开模块在运行时交换的数据结构。
 */
interface MacroExpandStep {
  /**
   * 文本内容。
   */
  text: string;
  /**
   * changed 值，由当前实例内部维护。
   */
  changed: boolean;
}

/**
 * 描述宏展开操作完成后返回给调用方的结果。
 */
interface MacroReplaceResult {
  /**
   * 字段值。
   */
  value: string;
  /**
   * changed 值，由当前实例内部维护。
   */
  changed: boolean;
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class CharacterNameMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.characterName;
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class UserNameMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.userName;
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class PersonaNameMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.personaName;
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class ChatNameMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.chatName;
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class MessageTextMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.messageText;
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class WorldInfoNameMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.worldInfoName;
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class GetVariableMacroAction implements MacroAction {
  /**
   * variables 列表，由当前实例内部维护。
   */
  private variables: VariableRuntime;

  /**
   * 注入宏展开运行时依赖并初始化实例状态。
   */
  constructor(variables: VariableRuntime) {
    this.variables = variables;
  }

  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    if (context.args.length === 0) {
      return '';
    }
    return this.variables.resolveVariable(context.args[0], context.context.variableContext).value;
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class SetVariableMacroAction implements MacroAction {
  /**
   * variables 列表，由当前实例内部维护。
   */
  private variables: VariableRuntime;

  /**
   * 注入宏展开运行时依赖并初始化实例状态。
   */
  constructor(variables: VariableRuntime) {
    this.variables = variables;
  }

  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    if (context.args.length < 2) {
      return '';
    }
    this.variables.setContextVariable('chat', context.args[0], context.args[1], context.context.variableContext);
    return '';
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class IfMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    if (context.args.length < 2) {
      return '';
    }
    if (this.isTruthy(context.args[0])) {
      return context.args[1];
    }
    if (context.args.length > 2) {
      return context.args[2];
    }
    return '';
  }

  /**
   * 判断Truthy 值是否满足条件。
   * @param value 要保存或比较的字段值。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  private isTruthy(value: string): boolean {
    const normalized = value.trim().toLowerCase();
    return normalized.length > 0 && normalized !== 'false' && normalized !== 'off' && normalized !== '0';
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class RandomMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    if (context.args.length === 0) {
      return '';
    }
    const index = Math.floor(Math.random() * context.args.length);
    return context.args[index];
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class SpaceMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    // 数量。
    const count = context.args.length === 0 ? 1 : Number.parseInt(context.args[0], 10);
    return ' '.repeat(count > 0 ? count : 1);
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class NewlineMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    // 数量。
    const count = context.args.length === 0 ? 1 : Number.parseInt(context.args[0], 10);
    return '\n'.repeat(count > 0 ? count : 1);
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class NoopMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    const rawLength = context.raw.length;
    if (rawLength < 0) {
      return context.raw;
    }
    return '';
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class IsoDateMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    const rawLength = context.raw.length;
    if (rawLength < 0) {
      return context.raw;
    }
    return new Date().toISOString().substring(0, 10);
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class TimeMacroAction implements MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string {
    const rawLength = context.raw.length;
    if (rawLength < 0) {
      return context.raw;
    }
    return new Date().toISOString().substring(11, 16);
  }
}
