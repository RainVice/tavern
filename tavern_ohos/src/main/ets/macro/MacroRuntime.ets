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
   * 宏注册信息，包含描述记录和可执行动作。
   */
  record: MacroRecord;
  /**
   * 宏展开时执行的可调用动作。
   */
  action: MacroAction;
}

/**
 * 提供宏展开相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在消息发送或 AI 回复生成前被调用，将文本中的 {{name::args}} 模板标记替换为运行时值。
 * 支持内置宏（角色名、变量读写、条件判断等）和外部插件注册的自定义宏，
 * 展开完成后通过事件总线通知其他模块展开结果。
 */
export class MacroRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 变量运行时实例，用于宏展开过程中读写聊天变量。
   */
  private variables: VariableRuntime;
  /**
   * 已注册的宏定义映射，键为宏名称，值为内部宏定义（含记录和可执行动作）。
   */
  private macros: Map<string, MacroDefinitionInternal> = new Map<string, MacroDefinitionInternal>();
  /**
   * 宏递归展开的最大嵌套深度，防止无限递归。
   */
  private maxDepth: number = 8;

  /**
   * 注入宏展开运行时依赖并初始化实例状态，同时注册所有内置宏。
   * 由 Tavern 主容器在应用启动时创建 MacroRuntime 实例时调用，
   * 注册 char、user、persona、chat、message、worldinfo、getvar、setvar、if、random 等内置宏。
   * @param events 用于发布宏注册、展开等事件的事件总线，其他模块可通过监听 macro.registered / macro.expanded 事件获取展开状态。
   * @param variables 变量运行时实例，用于 {{getvar}}/{{setvar}} 宏在展开时读写聊天上下文变量。
   */
  constructor(events: EventBus, variables: VariableRuntime) {
    this.events = events;
    this.variables = variables;
    this.registerBuiltIns();
  }

  /**
   * 注册一个新的宏到运行时中，使其可在后续文本展开时被识别和调用，并发布注册事件。
   * 由 registerBuiltIn 或外部插件系统调用，将宏定义存入 macros 映射供展开时查找。
   * @param params 宏注册参数，包含名称、分类、描述、来源、插件标识和可执行动作。
   *                其中 name 用于输入文本 {{name}} 的匹配，action 用于实际的展开替换。
   * @returns 注册成功的宏记录副本，供调用方安全读取注册结果。
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
   * 从运行时中取消注册指定名称的宏，使其不再被后续展开流程识别。
   * 通常在插件被卸载时由外部调用，用于清理该插件注册的宏，避免无效匹配。
   * @param name 要取消注册的宏名称，对应输入文本中 {{name}} 的 name 部分。
   */
  unregisterMacro(name: string): void {
    this.macros.delete(name);
  }

  /**
   * 展开输入文本中的所有宏，将 {{...}} 形式的模板标记替换为对应的运行时值。
   * 使用默认的 "keep" 策略处理未知宏（保留原始标记不替换）。
   * 在消息发送到 AI 模型前或生成回复后，由消息发送流程调用，
   * 确保最终文本中的宏标记被正确展开。
   * @param input 包含宏模板标记的原始输入文本，通常为消息正文或提示词模板。
   * @param context 宏展开评估上下文，包含角色名称、聊天名称和变量信息，由调用方从当前会话状态构造。
   * @returns 宏展开后的结果，包含替换后的文本和诊断信息，调用方使用 text 作为最终输出。
   */
  expand(input: string, context: MacroEvaluationContext): MacroExpansionResult {
    return this.expandWithStrategy(input, context, 'keep');
  }

  /**
   * 使用自定义策略展开输入文本中的所有宏，支持对未知宏选择保留、移除或跳过处理。
   * 是 expand 和 diagnose 的内部委托方法，完成展开后发布 macro.expanded 事件。
   * @param input 包含宏模板标记的原始输入文本。
   * @param context 宏展开评估上下文，包含角色名称、聊天名称和变量信息，由调用方从当前会话状态构造。
   * @param unknownStrategy 处理未知宏的策略："keep" 保留原样（默认），"remove" 移除标记。影响最终输出文本中未注册宏的处理方式。
   * @returns 宏展开后的结果，包含替换后的文本和诊断信息，调用方使用 text 替换原始输入。
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
   * 诊断输入文本中的所有宏标记，返回发现的未知宏和潜在问题的诊断信息列表。
   * 不实际替换文本，仅进行检测分析。
   * 用于在发送消息前对文本进行预检，提前发现未注册的宏供用户确认。
   * @param input 包含宏模板标记的原始输入文本，通常为待发送的消息或提示词。
   * @param context 宏展开评估上下文，包含角色名称、聊天名称和变量信息，由调用方从当前会话状态构造。
   * @returns 诊断信息列表，每条包含宏名称、错误消息、偏移量和原始文本。
   */
  diagnose(input: string, context: MacroEvaluationContext): Array<MacroDiagnostic> {
    return this.expandWithStrategy(input, context, 'keep').diagnostics;
  }

  /**
   * 根据输入前缀自动补全已注册的宏名称，返回按名称字典序排序的匹配结果。
   * 在用户输入 {{ 后由 UI 层调用以提供自动补全建议，提升用户输入效率。
   * @param prefix 用于匹配宏名称的前缀字符串，通常为用户当前输入的部分宏名。
   * @returns 匹配的宏记录列表（副本），按名称字典序排序，供 UI 展示补全选项。
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
   * 获取所有已注册宏的记录列表，每个条目为副本，调用方修改返回值不影响内部状态。
   * 用于 UI 层的宏管理界面展示所有可用宏，或外部模块查询当前已注册的宏列表。
   * @returns 所有已注册宏的记录数组，不含可执行动作。
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
   * 从指定起始位置之后查找与 {{ 配对的 }} 结束位置，支持嵌套 {{}}。
   * @param input 待搜索的原始输入文本。
   * @param start 开始搜索的位置索引（{{ 中第一个 { 的位置）。
   * @returns 配对 }} 中第二个 } 的索引，若未找到则返回 -1。
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
   * 注册所有内置宏，包括角色名、用户名、人格名、聊天名、消息文本、世界信息、
   * 变量读写、条件判断、随机选择、空格、换行、无操作和日期时间等宏。
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
   * 注册单个内置宏，构造注册参数后委托 registerMacro 完成注册。
   * @param name 宏名称，同时也是描述文本。
   * @param category 宏所属分类。
   * @param action 宏展开时执行的可调用动作。
   */
  private registerBuiltin(name: string, category: string, action: MacroAction): void {
    // 构造注册参数并调用通用注册方法。
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
   * 深拷贝宏记录，创建新对象防止外部修改内部状态。
   * @param record 要复制的宏记录对象。
   * @returns 独立于原对象的宏记录副本。
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
   * 深拷贝诊断信息列表，创建新数组和元素防止外部修改内部状态。
   * @param diagnostics 要复制的诊断信息数组。
   * @returns 独立于原数组的诊断信息副本列表。
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
 * 描述宏展开的单步中间结果，用于递归展开过程中判断是否继续展开。
 */
interface MacroExpandStep {
  /**
   * 单步展开后的文本内容。
   */
  text: string;
  /**
   * 当前步是否产生了替换（即文本发生了变化）。
   */
  changed: boolean;
}

/**
 * 描述宏替换操作的内部结果，用于单步替换过程中的返回值传递。
 */
interface MacroReplaceResult {
  /**
   * 宏替换后的实际输出值。
   */
  value: string;
  /**
   * 本次替换是否实际产生了变更。
   */
  changed: boolean;
}

/**
 * {{char}} 宏：展开为角色名称。
 * 在消息文本中出现 {{char}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 将标记替换为当前聊天的角色名称（来源于 MacroEvaluationContext.characterName）。
 */
class CharacterNameMacroAction implements MacroAction {
  /**
   * 从上下文中直接返回角色名称，用于替换 {{char}} 标记。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.characterName;
  }
}

/**
 * {{user}} 宏：展开为用户名称。
 * 在消息文本中出现 {{user}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 将标记替换为当前用户的昵称（来源于 MacroEvaluationContext.userName）。
 */
class UserNameMacroAction implements MacroAction {
  /**
   * 从上下文中直接返回用户名称，用于替换 {{user}} 标记。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.userName;
  }
}

/**
 * {{persona}} 宏：展开为人格名称。
 * 在消息文本中出现 {{persona}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 将标记替换为当前活跃人格的名称（来源于 MacroEvaluationContext.personaName）。
 */
class PersonaNameMacroAction implements MacroAction {
  /**
   * 从上下文中直接返回人格名称，用于替换 {{persona}} 标记。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.personaName;
  }
}

/**
 * {{chat}} 宏：展开为聊天名称。
 * 在消息文本中出现 {{chat}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 将标记替换为当前聊天会话的名称（来源于 MacroEvaluationContext.chatName）。
 */
class ChatNameMacroAction implements MacroAction {
  /**
   * 从上下文中直接返回聊天名称，用于替换 {{chat}} 标记。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.chatName;
  }
}

/**
 * {{message}} 宏：展开为当前消息文本内容。
 * 在消息文本中出现 {{message}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 将标记替换为当前消息的正文内容（来源于 MacroEvaluationContext.messageText）。
 */
class MessageTextMacroAction implements MacroAction {
  /**
   * 从上下文中直接返回当前消息文本，用于替换 {{message}} 标记。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.messageText;
  }
}

/**
 * {{worldinfo}} 宏：展开为世界信息名称。
 * 在消息文本中出现 {{worldinfo}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 将标记替换为当前活跃世界信息的名称（来源于 MacroEvaluationContext.worldInfoName）。
 */
class WorldInfoNameMacroAction implements MacroAction {
  /**
   * 从上下文中直接返回世界信息名称，用于替换 {{worldinfo}} 标记。
   */
  expand(context: MacroExecutionContext): string {
    return context.context.worldInfoName;
  }
}

/**
 * {{getvar}} 宏：从聊天变量中读取指定变量的值并展开。
 * 在消息文本中出现 {{getvar::variableName}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 通过 VariableRuntime.resolveVariable 读取聊天上下文中的变量值并替换标记。
 */
class GetVariableMacroAction implements MacroAction {
  /**
   * 变量运行时实例，用于在宏展开过程中通过 name 参数解析变量的当前值。
   */
  private variables: VariableRuntime;

  /**
   * 创建 getvar 宏动作实例。
   * @param variables 变量运行时实例，提供根据变量名从聊天上下文中读取变量值的能力。
   */
  constructor(variables: VariableRuntime) {
    this.variables = variables;
  }

  /**
   * 从上下文中读取第一个参数指定的变量名，并返回其当前值；无参数时返回空字符串。
   */
  expand(context: MacroExecutionContext): string {
    if (context.args.length === 0) {
      return '';
    }
    return this.variables.resolveVariable(context.args[0], context.context.variableContext).value;
  }
}

/**
 * {{setvar}} 宏：将指定的值写入聊天变量，不产生输出。
 * 在消息文本中出现 {{setvar::name::value}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 通过 VariableRuntime.setContextVariable 将值写入当前聊天范围的变量中（副作用宏）。
 */
class SetVariableMacroAction implements MacroAction {
  /**
   * 变量运行时实例，用于在宏展开过程中将参数中的变量名和值写入聊天上下文。
   */
  private variables: VariableRuntime;

  /**
   * 创建 setvar 宏动作实例。
   * @param variables 变量运行时实例，提供根据变量名和值设置聊天上下文变量的能力。
   */
  constructor(variables: VariableRuntime) {
    this.variables = variables;
  }

  /**
   * 将第一个参数作为变量名、第二个参数作为值写入聊天上下文变量，返回空字符串。
   * 参数不足 2 个时直接返回空字符串不执行写入。
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
 * {{if}} 宏：条件判断宏，根据第一个参数的布尔值返回第二个参数（真值分支）或第三个参数（假值分支）。
 * 在消息文本中出现 {{if::condition::trueValue::falseValue}} 时，
 * 被 MacroRuntime 的 evaluateMacro 方法调用，用于在模板中实现简单的条件逻辑。
 */
class IfMacroAction implements MacroAction {
  /**
   * 根据条件执行分支选择：条件为真时返回第二个参数，为假且有第三个参数时返回第三个参数，否则返回空字符串。
   * 参数不足 2 个时返回空字符串。
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
   * 判断字符串是否为真值（非空、非 "false"、非 "off"、非 "0"）。
   * @param value 要判断真值性的字符串。
   * @returns 字符串表示真值时返回 true，否则返回 false。
   */
  private isTruthy(value: string): boolean {
    const normalized = value.trim().toLowerCase();
    return normalized.length > 0 && normalized !== 'false' && normalized !== 'off' && normalized !== '0';
  }
}

/**
 * {{random}} 宏：从参数列表中随机选择一个值展开。
 * 在消息文本中出现 {{random::option1::option2::...}} 时，
 * 被 MacroRuntime 的 evaluateMacro 方法调用，每次展开随机选取一个选项，用于增加回复的多样性。
 */
class RandomMacroAction implements MacroAction {
  /**
   * 从宏参数中随机选取一个并返回；无参数时返回空字符串。
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
 * {{space}} 宏：展开为指定数量的空格字符，默认 1 个空格。
 * 在消息文本中出现 {{space::count}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 用于在模板中生成指定数量的连续空格。
 */
class SpaceMacroAction implements MacroAction {
  /**
   * 根据第一个参数指定的数量重复空格字符；默认生成 1 个空格，最小为 1。
   */
  expand(context: MacroExecutionContext): string {
    // 解析空格重复次数，默认 1。
    const count = context.args.length === 0 ? 1 : Number.parseInt(context.args[0], 10);
    return ' '.repeat(count > 0 ? count : 1);
  }
}

/**
 * {{newline}} 宏：展开为指定数量的换行符，默认 1 个换行。
 * 在消息文本中出现 {{newline::count}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 用于在模板中生成指定数量的换行，适用于提示词格式构造。
 */
class NewlineMacroAction implements MacroAction {
  /**
   * 根据第一个参数指定的数量重复换行符；默认生成 1 个换行，最小为 1。
   */
  expand(context: MacroExecutionContext): string {
    // 解析换行重复次数，默认 1。
    const count = context.args.length === 0 ? 1 : Number.parseInt(context.args[0], 10);
    return '\n'.repeat(count > 0 ? count : 1);
  }
}

/**
 * {{noop}} 宏：无操作宏，始终返回空字符串，用于吞掉原始标记。
 * 在消息文本中出现 {{noop}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 用于在模板中注释掉某些内容或占位但不产生输出。
 */
class NoopMacroAction implements MacroAction {
  /**
   * 忽略所有参数，直接返回空字符串，即 {{noop}} 标记被完全移除不产生任何文本。
   */
  expand(context: MacroExecutionContext): string {
    return '';
  }
}

/**
 * {{isodate}} 宏：展开为当前日期的 ISO 8601 格式（YYYY-MM-DD）。
 * 在消息文本中出现 {{isodate}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 用于在模板中插入当前日期，例如在日记类提示词中。
 */
class IsoDateMacroAction implements MacroAction {
  /**
   * 返回当前日期的 ISO 日期部分（前 10 个字符），格式为 YYYY-MM-DD。
   */
  expand(context: MacroExecutionContext): string {
    return new Date().toISOString().substring(0, 10);
  }
}

/**
 * {{time}} 宏：展开为当前时间的 HH:MM 格式。
 * 在消息文本中出现 {{time}} 时，被 MacroRuntime 的 evaluateMacro 方法调用，
 * 用于在模板中插入当前时间，例如在时间相关的提示词中。
 */
class TimeMacroAction implements MacroAction {
  /**
   * 返回当前时间的时:分部分（ISO 格式的第 11-16 个字符），格式为 HH:MM。
   */
  expand(context: MacroExecutionContext): string {
    return new Date().toISOString().substring(11, 16);
  }
}
