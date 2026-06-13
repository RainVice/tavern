import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  VariableRuntime,
  type RuntimeEvent,
  type VariableChangedPayload,
  type VariableEntry,
  type VariableExportData,
  type VariableResolveContext,
  type VariableResolveResult,
} from '../../Index';

export default function variableUnitTest() {
  describe('variable runtime', () => {
    it('resolves variables across chat scopes with local precedence', 0, () => {
      // 运行时实例。
      const runtime = new VariableRuntime(new EventBus());
      const context = makeContext();
      runtime.setVariable('global', '', 'tone', 'neutral');
      runtime.setContextVariable('user', 'tone', 'warm', context);
      runtime.setContextVariable('chat', 'tone', 'focused', context);
      runtime.setContextVariable('message', 'tone', 'urgent', context);
      const resolved: VariableResolveResult = runtime.resolveVariable('tone', context);
      runtime.deleteContextVariable('message', 'tone', context);
      const afterDelete: VariableResolveResult = runtime.resolveVariable('tone', context);

      expect(resolved.value).assertEqual('urgent');
      expect(resolved.scope).assertEqual('message');
      expect(afterDelete.value).assertEqual('focused');
      expect(afterDelete.scope).assertEqual('chat');
    });

    it('keeps plugin variables isolated and emits changed events', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new VariableRuntime(bus);
      const changed = new Array<string>();
      bus.subscribe<VariableChangedPayload>('variable.changed', (event: RuntimeEvent<VariableChangedPayload>) => {
        changed.push(`${event.payload.scope}:${event.payload.key}:${event.payload.oldValue}:${event.payload.newValue}`);
      });
      const context = makeContext();
      runtime.setContextVariable('plugin', 'apiBase', 'plugin-a-url', context);
      const otherPlugin = makeContextWithPlugin('plugin-b');

      expect(runtime.getContextVariable('plugin', 'apiBase', context)).assertEqual('plugin-a-url');
      expect(runtime.getContextVariable('plugin', 'apiBase', otherPlugin)).assertEqual('');
      expect(runtime.resolveVariable('apiBase', otherPlugin).value).assertEqual('');
      expect(changed.length).assertEqual(1);
      expect(changed[0]).assertEqual('plugin:apiBase::plugin-a-url');
    });

    it('exports persistent variables and restores them without temporary pipe state', 0, () => {
      // 运行时实例。
      const runtime = new VariableRuntime(new EventBus());
      const context = makeContext();
      runtime.setVariable('global', '', 'author', 'A');
      runtime.setContextVariable('temporary', 'scratch', 'temp', context);
      runtime.setPipeVariable('last', 'pipe');
      const exported: VariableExportData = runtime.exportVariables();
      const restored = new VariableRuntime(new EventBus());
      restored.importVariables(exported);

      expect(exported.entries.length).assertEqual(1);
      expect(restored.getVariable('global', '', 'author')).assertEqual('A');
      expect(restored.resolveVariable('scratch', context).value).assertEqual('');
      expect(restored.getPipeVariable('last')).assertEqual('');
    });

    it('supports macro and command reads and writes', 0, () => {
      // 运行时实例。
      const runtime = new VariableRuntime(new EventBus());
      const context = makeContext();
      runtime.writeCommandVariable('chat', 'scene', 'bridge', context);
      runtime.writeCommandVariable('global', 'mood', 'calm', context);
      const entries: Array<VariableEntry> = runtime.listVariables('chat', context.chatId);

      expect(runtime.readCommandVariable('chat', 'scene', context)).assertEqual('bridge');
      expect(runtime.expandVariableMacros('Mood {{var::mood}} at {{var::scene}}', context)).assertEqual('Mood calm at bridge');
      expect(entries.length).assertEqual(1);
      expect(entries[0].key).assertEqual('scene');
    });

    it('does not expose internal variable entries', 0, () => {
      // 运行时实例。
      const runtime = new VariableRuntime(new EventBus());
      // 条目记录。
      const entry = runtime.setVariable('global', '', 'copy', 'original');
      entry.value = 'external';
      expect(runtime.getVariable('global', '', 'copy')).assertEqual('original');
      const entries = runtime.listVariables('global', '');
      entries[0].value = 'listed';
      expect(runtime.getVariable('global', '', 'copy')).assertEqual('original');
    });
  });
}

/**
 * 封装单元测试中的 makeContext 步骤，供公开方法复用。
 */
function makeContext(): VariableResolveContext {
  return makeContextWithPlugin('plugin-a');
}

/**
 * 封装单元测试中的 makeContextWithPlugin 步骤，供公开方法复用。
 * @param pluginId 插件标识。
 */
function makeContextWithPlugin(pluginId: string): VariableResolveContext {
  return {
    userId: 'user-1',
    characterId: 'char-1',
    personaId: 'persona-1',
    chatId: 'chat-1',
    groupId: 'group-1',
    messageId: 'msg-1',
    pluginId: pluginId,
  };
}
