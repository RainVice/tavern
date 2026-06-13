import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  MacroRuntime,
  VariableRuntime,
  type MacroAction,
  type MacroDiagnostic,
  type MacroEvaluationContext,
  type MacroExecutionContext,
  type MacroExpandedPayload,
  type MacroExpansionResult,
  type MacroRegistrationParams,
  type RuntimeEvent,
  type VariableResolveContext,
} from '../../Index';

export default function macroUnitTest() {
  describe('macro runtime', () => {
    it('expands built-in, variable, nested, and conditional macros', 0, () => {
      const variables = new VariableRuntime(new EventBus());
      // 运行时实例。
      const runtime = new MacroRuntime(new EventBus(), variables);
      const context = makeMacroContext();
      variables.setContextVariable('chat', 'mood', 'calm', context.variableContext);
      const result: MacroExpansionResult = runtime.expand(
        '{{char}} greets {{user}} with {{getvar::mood}} {{if::{{getvar::mood}}::ok::bad}} {{random::spark}}',
        context,
      );

      expect(result.text).assertEqual('Alice greets Pilot with calm ok spark');
      expect(result.diagnostics.length).assertEqual(0);
    });

    it('registers plugin and command macros with events and autocomplete', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new MacroRuntime(bus, new VariableRuntime(new EventBus()));
      const expandedEvents = new Array<string>();
      bus.subscribe<MacroExpandedPayload>('macro.expanded', (event: RuntimeEvent<MacroExpandedPayload>) => {
        expandedEvents.push(`${event.payload.input}:${event.payload.output}`);
      });
      runtime.registerMacro(makeMacro('pluginBadge', 'plugin', 'plugin-a', new StaticMacroAction('badge')));
      runtime.registerMacro(makeMacro('cmdEcho', 'command', '', new EchoMacroAction()));
      const result = runtime.expand('Use {{pluginBadge}} then {{cmdEcho::now}}', makeMacroContext());
      const options = runtime.autocomplete('pluginB');

      expect(result.text).assertEqual('Use badge then cmd:now');
      expect(options.length).assertEqual(1);
      expect(options[0].name).assertEqual('pluginBadge');
      expect(expandedEvents.length).assertEqual(1);
    });

    it('does not expose internal macro records or diagnostics', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new MacroRuntime(bus, new VariableRuntime(new EventBus()));
      bus.subscribe<MacroExpandedPayload>('macro.expanded', (event: RuntimeEvent<MacroExpandedPayload>) => {
        event.payload.diagnostics.push({
          macroName: 'event-mutated',
          message: 'event-mutated',
          offset: 0,
          raw: '',
        });
      });
      const registered = runtime.registerMacro(makeMacro('copyMacro', 'plugin', 'plugin-a', new StaticMacroAction('ok')));
      registered.name = 'mutated';
      expect(runtime.autocomplete('copyMacro').length).assertEqual(1);
      const listed = runtime.listMacros();
      listed[0].name = 'list-mutated';
      expect(runtime.autocomplete('copyMacro').length).assertEqual(1);
      const options = runtime.autocomplete('copyMacro');
      options[0].name = 'option-mutated';
      expect(runtime.autocomplete('copyMacro')[0].name).assertEqual('copyMacro');
      const result = runtime.expand('A {{missingMacro}}', makeMacroContext());
      result.diagnostics.push({
        macroName: 'result-mutated',
        message: 'result-mutated',
        offset: 0,
        raw: '',
      });
      const next = runtime.expand('A {{missingMacro}}', makeMacroContext());
      expect(next.diagnostics.length).assertEqual(1);
      expect(next.diagnostics[0].macroName).assertEqual('missingMacro');
    });

    it('records diagnostics and applies unknown macro strategy', 0, () => {
      // 运行时实例。
      const runtime = new MacroRuntime(new EventBus(), new VariableRuntime(new EventBus()));
      const keep = runtime.expandWithStrategy('A {{missing}}', makeMacroContext(), 'keep');
      const remove = runtime.expandWithStrategy('A {{missing}}', makeMacroContext(), 'remove');
      const diagnostics: Array<MacroDiagnostic> = runtime.diagnose('A {{missing}} and {{char}}', makeMacroContext());

      expect(keep.text).assertEqual('A {{missing}}');
      expect(remove.text).assertEqual('A ');
      expect(keep.diagnostics.length).assertEqual(1);
      expect(diagnostics.length).assertEqual(1);
      expect(diagnostics[0].macroName).assertEqual('missing');
    });
  });
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class StaticMacroAction implements MacroAction {
  /**
   * 字段值。
   */
  private value: string;

  /**
   * 初始化当前实例。
   * @param value 字段值。
   */
  constructor(value: string) {
    this.value = value;
  }

  /**
   * 封装单元测试中的 expand 步骤，供公开方法复用。
   */
  expand(context: MacroExecutionContext): string {
    const rawLength = context.raw.length;
    if (rawLength < 0) {
      return context.raw;
    }
    return this.value;
  }
}

/**
 * 实现一个可执行动作，供运行时在对应场景中调用。
 */
class EchoMacroAction implements MacroAction {
  /**
   * 封装单元测试中的 expand 步骤，供公开方法复用。
   */
  expand(context: MacroExecutionContext): string {
    return `cmd:${context.args.join(':')}`;
  }
}

/**
 * 封装单元测试中的 makeMacro 步骤，供公开方法复用。
 * @param name 显示名称或注册名称。

 * @param pluginId 插件标识。
 */
function makeMacro(name: string, category: string, pluginId: string, action: MacroAction): MacroRegistrationParams {
  return {
    name: name,
    category: category,
    description: name,
    source: 'test',
    pluginId: pluginId,
    action: action,
  };
}

/**
 * 封装单元测试中的 makeMacroContext 步骤，供公开方法复用。
 */
function makeMacroContext(): MacroEvaluationContext {
  return {
    userName: 'Pilot',
    characterName: 'Alice',
    personaName: 'Captain',
    chatName: 'Bridge',
    messageText: 'Ready',
    worldInfoName: 'Atlas',
    variableContext: makeVariableContext(),
  };
}

/**
 * 封装单元测试中的 makeVariableContext 步骤，供公开方法复用。
 */
function makeVariableContext(): VariableResolveContext {
  return {
    userId: 'user-1',
    characterId: 'char-1',
    personaId: 'persona-1',
    chatId: 'chat-1',
    groupId: 'group-1',
    messageId: 'msg-1',
    pluginId: 'plugin-a',
  };
}
