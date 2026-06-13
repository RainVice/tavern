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

interface MacroDefinitionInternal {
  record: MacroRecord;
  action: MacroAction;
}

export class MacroRuntime {
  private events: EventBus;
  private variables: VariableRuntime;
  private macros: Map<string, MacroDefinitionInternal> = new Map<string, MacroDefinitionInternal>();
  private maxDepth: number = 8;

  constructor(events: EventBus, variables: VariableRuntime) {
    this.events = events;
    this.variables = variables;
    this.registerBuiltIns();
  }

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

  unregisterMacro(name: string): void {
    this.macros.delete(name);
  }

  expand(input: string, context: MacroEvaluationContext): MacroExpansionResult {
    return this.expandWithStrategy(input, context, 'keep');
  }

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

  diagnose(input: string, context: MacroEvaluationContext): Array<MacroDiagnostic> {
    return this.expandWithStrategy(input, context, 'keep').diagnostics;
  }

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
    const name = parts.length === 0 ? '' : parts[0].trim();
    const definition = this.macros.get(name);
    if (definition === undefined) {
      const diagnostic: MacroDiagnostic = {
        macroName: name,
        message: `Unknown macro: ${name}`,
        offset: offset,
        raw: raw,
      };
      diagnostics.push(diagnostic);
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

  private registerBuiltin(name: string, category: string, action: MacroAction): void {
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

  private cloneRecord(record: MacroRecord): MacroRecord {
    return {
      name: record.name,
      category: record.category,
      description: record.description,
      source: record.source,
      pluginId: record.pluginId,
    };
  }

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

interface MacroExpandStep {
  text: string;
  changed: boolean;
}

interface MacroReplaceResult {
  value: string;
  changed: boolean;
}

class CharacterNameMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    return context.context.characterName;
  }
}

class UserNameMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    return context.context.userName;
  }
}

class PersonaNameMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    return context.context.personaName;
  }
}

class ChatNameMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    return context.context.chatName;
  }
}

class MessageTextMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    return context.context.messageText;
  }
}

class WorldInfoNameMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    return context.context.worldInfoName;
  }
}

class GetVariableMacroAction implements MacroAction {
  private variables: VariableRuntime;

  constructor(variables: VariableRuntime) {
    this.variables = variables;
  }

  expand(context: MacroExecutionContext): string {
    if (context.args.length === 0) {
      return '';
    }
    return this.variables.resolveVariable(context.args[0], context.context.variableContext).value;
  }
}

class SetVariableMacroAction implements MacroAction {
  private variables: VariableRuntime;

  constructor(variables: VariableRuntime) {
    this.variables = variables;
  }

  expand(context: MacroExecutionContext): string {
    if (context.args.length < 2) {
      return '';
    }
    this.variables.setContextVariable('chat', context.args[0], context.args[1], context.context.variableContext);
    return '';
  }
}

class IfMacroAction implements MacroAction {
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

  private isTruthy(value: string): boolean {
    const normalized = value.trim().toLowerCase();
    return normalized.length > 0 && normalized !== 'false' && normalized !== 'off' && normalized !== '0';
  }
}

class RandomMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    if (context.args.length === 0) {
      return '';
    }
    const index = Math.floor(Math.random() * context.args.length);
    return context.args[index];
  }
}

class SpaceMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    const count = context.args.length === 0 ? 1 : Number.parseInt(context.args[0], 10);
    return ' '.repeat(count > 0 ? count : 1);
  }
}

class NewlineMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    const count = context.args.length === 0 ? 1 : Number.parseInt(context.args[0], 10);
    return '\n'.repeat(count > 0 ? count : 1);
  }
}

class NoopMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    const rawLength = context.raw.length;
    if (rawLength < 0) {
      return context.raw;
    }
    return '';
  }
}

class IsoDateMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    const rawLength = context.raw.length;
    if (rawLength < 0) {
      return context.raw;
    }
    return new Date().toISOString().substring(0, 10);
  }
}

class TimeMacroAction implements MacroAction {
  expand(context: MacroExecutionContext): string {
    const rawLength = context.raw.length;
    if (rawLength < 0) {
      return context.raw;
    }
    return new Date().toISOString().substring(11, 16);
  }
}
