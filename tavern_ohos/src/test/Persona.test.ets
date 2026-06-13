import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  PersonaRuntime,
  type PersonaBindingRecord,
  type PersonaChangedPayload,
  type PersonaCreateParams,
  type PersonaExportData,
  type PersonaPromptData,
  type PersonaRecord,
  type PersonaUpdatedPayload,
  type RuntimeEvent,
} from '../../Index';

export default function personaUnitTest() {
  describe('persona runtime', () => {
    it('creates, updates, lists, and deletes personas', 0, () => {
      // 运行时实例。
      const runtime = new PersonaRuntime(new EventBus());
      const created = runtime.createPersona(makePersona('persona-1', 'User', 'A careful user.'));
      const updated = runtime.updatePersona(created.id, makePersona('persona-1', 'User Updated', 'Updated description.'));
      runtime.createPersona(makePersona('persona-2', 'Writer', 'Writes concise prompts.'));
      const personas: Array<PersonaRecord> = runtime.listPersonas();

      expect(updated.name).assertEqual('User Updated');
      expect(runtime.getPersona('persona-1').description).assertEqual('Updated description.');
      expect(personas.length).assertEqual(2);
      runtime.deletePersona('persona-1');
      expect(runtime.listPersonas().length).assertEqual(1);
    });

    it('selects and binds personas to chat and character scopes', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new PersonaRuntime(bus);
      const changed = new Array<string>();
      bus.subscribe<PersonaChangedPayload>('persona.changed', (event: RuntimeEvent<PersonaChangedPayload>) => {
        changed.push(event.payload.persona.id);
      });
      runtime.createPersona(makePersona('persona-3', 'Speaker', 'Speaks as {{user}}.'));
      const selected = runtime.selectPersona('persona-3');
      const chatBinding: PersonaBindingRecord = runtime.bindPersona('chat', 'chat-1', 'persona-3');
      const characterBinding: PersonaBindingRecord = runtime.bindPersona('character', 'char-1', 'persona-3');

      expect(selected.id).assertEqual('persona-3');
      expect(chatBinding.scopeId).assertEqual('chat-1');
      expect(characterBinding.scope).assertEqual('character');
      expect(runtime.getBoundPersona('chat', 'chat-1').id).assertEqual('persona-3');
      expect(changed.length).assertEqual(1);
      expect(changed[0]).assertEqual('persona-3');
    });

    it('builds prompt data and imports exported personas', 0, () => {
      // 运行时实例。
      const runtime = new PersonaRuntime(new EventBus());
      runtime.createPersona(makePersona('persona-4', 'Pilot', 'Keeps context short.'));
      const promptData: PersonaPromptData = runtime.buildPromptData('persona-4');
      const exported: PersonaExportData = runtime.exportPersona('persona-4');
      const imported = runtime.importPersona(exported, 'persona-5');

      expect(promptData.userMacroValue).assertEqual('Pilot');
      expect(promptData.description).assertEqual('Keeps context short.');
      expect(promptData.lorebookId).assertEqual('lore-persona-4');
      expect(imported.id).assertEqual('persona-5');
      expect(runtime.getPersona('persona-5').tags[0]).assertEqual('default');
    });

    it('builds prompt data from scoped bindings with selected fallback', 0, () => {
      // 运行时实例。
      const runtime = new PersonaRuntime(new EventBus());
      runtime.createPersona(makePersona('persona-selected', 'Selected', 'Selected persona.'));
      runtime.createPersona(makePersona('persona-chat', 'ChatUser', 'Chat persona.'));
      runtime.selectPersona('persona-selected');
      runtime.bindPersona('chat', 'chat-1', 'persona-chat');
      const bound = runtime.buildPromptDataForScope('chat', 'chat-1');
      const fallback = runtime.buildPromptDataForScope('character', 'char-1');

      expect(bound.personaId).assertEqual('persona-chat');
      expect(bound.userMacroValue).assertEqual('ChatUser');
      expect(bound.lorebookId).assertEqual('lore-persona-chat');
      expect(fallback.personaId).assertEqual('persona-selected');
    });

    it('rejects import when target persona id already exists', 0, () => {
      // 运行时实例。
      const runtime = new PersonaRuntime(new EventBus());
      runtime.createPersona(makePersona('persona-existing', 'Existing', 'Existing persona.'));
      const exported: PersonaExportData = runtime.exportPersona('persona-existing');
      let thrown = false;
      try {
        runtime.importPersona(exported, 'persona-existing');
      } catch (error) {
        thrown = true;
      }

      expect(thrown).assertTrue();
      expect(runtime.getPersona('persona-existing').name).assertEqual('Existing');
    });

    it('does not expose internal persona records or bindings', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new PersonaRuntime(bus);
      bus.subscribe<PersonaUpdatedPayload>('persona.created', (event: RuntimeEvent<PersonaUpdatedPayload>) => {
        event.payload.persona.tags.push('event-tag');
      });
      const created = runtime.createPersona(makePersona('persona-copy', 'Copy', 'Copy persona.'));
      created.tags.push('external-tag');
      expect(runtime.getPersona('persona-copy').tags.length).assertEqual(1);
      const listed = runtime.listPersonas();
      listed[0].name = 'list-mutated';
      expect(runtime.getPersona('persona-copy').name).assertEqual('Copy');
      const selected = runtime.selectPersona('persona-copy');
      selected.name = 'selected-mutated';
      expect(runtime.getSelectedPersona().name).assertEqual('Copy');
      const binding = runtime.bindPersona('chat', 'chat-copy', 'persona-copy');
      binding.personaId = 'external-persona';
      expect(runtime.getBoundPersona('chat', 'chat-copy').id).assertEqual('persona-copy');

      { let thrown=false; try { runtime.deletePersona('missing-persona'); } catch(e) { thrown=true; } expect(thrown).assertTrue(); };
    });
  });
}

/**
 * 封装单元测试中的 makePersona 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param name 显示名称或注册名称。
 */
function makePersona(id: string, name: string, description: string): PersonaCreateParams {
  return {
    id: id,
    name: name,
    description: description,
    avatarRef: `personas/${id}/avatar.png`,
    tags: ['default'],
    lorebookId: `lore-${id}`,
    promptInjectionStrategy: 'persona_section',
    userMacroValue: name,
    enabled: true,
  };
}
