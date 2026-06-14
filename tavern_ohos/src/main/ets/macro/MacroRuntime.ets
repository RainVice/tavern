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
 * 内部宏定义结构，将宏记录与可执行动作绑定。
 */
interface MacroDefinitionInternal {
  /**
   * 宏记录（不含执行逻辑的元信息）。
   */
  record: MacroRecord;
  /**
   * 宏对应的可执行动作。
   */
  action: MacroAction;
}

/**
 * 提供宏展开相关的无 UI 运行时能力，负责宏注册、展开、诊断和事件发布。
 */
export class MacroRuntime {
  /**
   * 事件总线，用于发布 macro.registered / macro.expanded 等事件。
   */
  private events: EventBus;
  /**
   * 变量运行时，供 getvar / setvar 等内置宏读取或写入变量。
   */
  private variables: VariableRuntime;
  /**
   * 已注册的宏映射表，键为宏名称，值为内部定义。
   */
  private macros: Map<string, MacroDefinitionInternal> = new Map<string, MacroDefinitionInternal>();
  /**
   * 宏展开的最大递归深度，防止无限循环。
   */
  private maxDepth: number = 8;

  /**
   * 构造 MacroRuntime 实例。
   * @param events 事件总线实例。
   * @param variables 变量运行时实例。
   */
  constructor(events: EventBus, variables: VariableRuntime) {
    this.events = events;
    this.variables = variables;
    this.registerBuiltIns();
  }

  /**
   * 注册一个宏，使其可被后续展开流程使用。
   * @param params 宏注册参数。
   * @returns 注册成功的宏记录副本。
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
   * 取消注册指定名称的宏。
   * @param name 要移除的宏名称。
   */
  unregisterMacro(name: string): void {
    this.macros.delete(name);
  }

  /**
   * 对输入文本进行宏展开，遇到未知宏时保留原文本。
   * @param input 待展开的原始文本。
   * @param context 宏展开上下文。
   * @returns 展开结果。
   */
  expand(input: string, context: MacroEvaluationContext): MacroExpansionResult {
    return this.expandWithStrategy(input, context, 'keep');
  }

  /**
   * 对输入文本进行宏展开，可通过 unknownStrategy 控制未知宏的处理方式。
   * @param input 待展开的原始文本。
   * @param context 宏展开上下文。
   * @param unknownStrategy 遇到未知宏时的策略：'keep' 保留原文本，'remove' 移除。
   * @returns 展开结果。
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
   * 对输入文本进行诊断，仅返回诊断信息，不实际展开文本。
   * @param input 待诊断的原始文本。
   * @param context 宏展开上下文。
   * @returns 诊断列表；返回值是副本，调用方可安全读取。
   */
  diagnose(input: string, context: MacroEvaluationContext): Array<MacroDiagnostic> {
    return this.expandWithStrategy(input, context, 'keep').diagnostics;
  }

  /**
   * 根据前缀自动补全已注册的宏名称。
   * @param prefix 要匹配的宏名称前缀。
   * @returns 匹配的宏记录列表，按名称字典序排序；返回值是副本。
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
   * 获取当前所有已注册宏的记录列表。
   * @returns 宏记录列表，按注册顺序排列；返回值是副本。
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
   * 从给定位置开始查找宏结束标记 }}。
   * @param input 原始文本。
   * @param start 开始搜索的位置。
   * @returns }} 的位置，未找到时返回 -1。
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
 * 初始化内置宏（如 {{char}}、{{user}}、{{random}} 等）。
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
   * 注册单个内置宏。
   * @param name 宏名称。
   * @param category 宏分类。
   * @param action 宏对应的动作实现。
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
   * 深拷贝 MacroRecord，防止外部修改内部状态。
   * @param record 要复制的宏记录。
   * @returns 新的宏记录副本。
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
   * 深拷贝诊断列表，防止外部修改内部状态。
   * @param diagnostics 原始诊断列表。
   * @returns 新的诊断列表副本。
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
 * 内部类型，表示一次单遍宏展开的结果。
 */
interface MacroExpandStep {
  /**
   * 展开后的文本。
   */
  text: string;
  /**
   * 此次展开是否至少替换了一个宏。
   */
  changed: boolean;
}

/**
 * 内部类型，表示单个宏替换的结果。
 */
interface MacroReplaceResult {
  /**
   * 替换后的文本。
   */
  value: string;
  /**
   * 是否发生了替换。
   */
  changed: boolean;
}

/**
 * 内置宏：展开为角色名称（characterName）。
 */
class CharacterNameMacroAction implements MacroAction {
  /**
   * 返回当前上下文的角色名称。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.characterName;
  }
}

/**
 * 内置宏：展开为用户名称（userName）。
 */
class UserNameMacroAction implements MacroAction {
  /**
   * 返回当前上下文的用户名称。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.userName;
  }
}

/**
 * 内置宏：展开为 Persona 名称（personaName）。
 */
class PersonaNameMacroAction implements MacroAction {
  /**
   * 返回当前上下文的 Persona 名称。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.personaName;
  }
}

/**
 * 内置宏：展开为对话名称（chatName）。
 */
class ChatNameMacroAction implements MacroAction {
  /**
   * 返回当前上下文的对话名称。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.chatName;
  }
}

/**
 * 内置宏：展开为消息文本（messageText）。
 */
class MessageTextMacroAction implements MacroAction {
  /**
   * 返回当前上下文的消息文本。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.messageText;
  }
}

/**
 * 内置宏：展开为 World Info 名称（worldInfoName）。
 */
class WorldInfoNameMacroAction implements MacroAction {
  /**
   * 返回当前上下文的 World Info 名称。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.worldInfoName;
  }
}

/**
 * 内置宏：读取变量值（{{getvar::key}}）。
 */
class GetVariableMacroAction implements MacroAction {
  /**
   * 变量运行时实例，用于解析变量值。
   */
  private variables: VariableRuntime;

  /**
   * 构造 GetVariableMacroAction。
   * @param variables 变量运行时实例。
   */
  constructor(variables: VariableRuntime) {
    this.variables = variables;
  }

  /**
   * 根据第一个参数解析变量值并返回。
   */
  expand(context: MacroExecutionContext): string {
    if (context.args.length === 0) {
      return '';
    }
    return this.variables.resolveVariable(context.args[0], context.context.variableContext).value;
  }
}

/**
 * 内置宏：设置变量值（{{setvar::key::value}}）。
 */
class SetVariableMacroAction implements MacroAction {
  /**
   * 变量运行时实例，用于写入变量。
   */
  private variables: VariableRuntime;

  /**
   * 构造 SetVariableMacroAction。
   * @param variables 变量运行时实例。
   */
  constructor(variables: VariableRuntime) {
    this.variables = variables;
  }

  /**
   * 将第一个参数作为变量名、第二个参数作为变量值写入上下文。
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
 * 内置宏：条件判断（{{if::condition::trueValue::falseValue}}）。
 */
class IfMacroAction implements MacroAction {
  /**
   * 根据条件参数的布尔值选择返回第一个或第二个值参数。
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
   * 判断字符串是否为真值（非空、非 false、非 off、非 0）。
   * @param value 待判断的字符串。
   * @returns 值为真时返回 true。
   */
  private isTruthy(value: string): boolean {
    const normalized = value.trim().toLowerCase();
    return normalized.length > 0 && normalized !== 'false' && normalized !== 'off' && normalized !== '0';
  }
}

/**
 * 内置宏：随机选择（{{random::opt1::opt2::...}}）。
 */
class RandomMacroAction implements MacroAction {
  /**
   * 从参数列表中随机选择一个返回。
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
 * 内置宏：生成空格（{{space::n}}，默认为 1 个）。
 */
class SpaceMacroAction implements MacroAction {
  /**
   * 返回指定数量的空格字符。
   */
  expand(context: MacroExecutionContext): string {
    // 数量。
    const count = context.args.length === 0 ? 1 : Number.parseInt(context.args[0], 10);
    return ' '.repeat(count > 0 ? count : 1);
  }
}

/**
 * 内置宏：生成换行符（{{newline::n}}，默认为 1 个）。
 */
class NewlineMacroAction implements MacroAction {
  /**
   * 返回指定数量的换行符。
   */
  expand(context: MacroExecutionContext): string {
    // 数量。
    const count = context.args.length === 0 ? 1 : Number.parseInt(context.args[0], 10);
    return '\n'.repeat(count > 0 ? count : 1);
  }
}

/**
 * 内置宏：无操作（{{noop}}），始终返回空字符串。
 */
class NoopMacroAction implements MacroAction {
  /**
   * 返回空字符串，不产生任何输出。
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
 * 内置宏：返回当前 ISO 日期（{{isodate}}，格式 yyyy-MM-dd）。
 */
class IsoDateMacroAction implements MacroAction {
  /**
   * 返回当天日期的 ISO 8601 字符串（仅日期部分）。
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
 * 内置宏：返回当前时间（{{time}}，格式 HH:mm）。
 */
class TimeMacroAction implements MacroAction {
  /**
   * 返回当前时间的 ISO 8601 字符串（仅时分部分）。
   */
  expand(context: MacroExecutionContext): string {
    const rawLength = context.raw.length;
    if (rawLength < 0) {
      return context.raw;
    }
    return new Date().toISOString().substring(11, 16);
  }
}
