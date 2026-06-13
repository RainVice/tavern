import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  GroupRuntime,
  type GroupCreateParams,
  type GroupEventPayload,
  type GroupExportData,
  type GroupGenerationRequest,
  type GroupMemberAddedPayload,
  type GroupMemberCreateParams,
  type GroupMemberRecord,
  type GroupPromptData,
  type GroupSpeakerSelectedPayload,
  type RuntimeEvent,
} from '../../Index';

export default function groupUnitTest() {
  describe('group runtime', () => {
    it('creates, edits, lists, and deletes groups', 0, () => {
      // 运行时实例。
      const runtime = new GroupRuntime(new EventBus());
      const created = runtime.createGroup(makeGroup('group-1', 'Crew'));
      const updated = runtime.updateGroup(created.id, makeGroup('group-1', 'Bridge Crew'));
      runtime.createGroup(makeGroup('group-2', 'Away Team'));

      expect(updated.name).assertEqual('Bridge Crew');
      expect(runtime.getGroup('group-1').description).assertEqual('Group group-1');
      expect(runtime.listGroups().length).assertEqual(2);
      runtime.deleteGroup('group-2');
      expect(runtime.listGroups().length).assertEqual(1);
    });

    it('adds members, preserves order, binds persona, and emits events', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new GroupRuntime(bus);
      const added = new Array<string>();
      bus.subscribe<GroupMemberAddedPayload>('group.member.added', (event: RuntimeEvent<GroupMemberAddedPayload>) => {
        added.push(`${event.payload.groupId}:${event.payload.characterId}`);
      });
      runtime.createGroup(makeGroup('group-3', 'Speakers'));

      runtime.addMember('group-3', makeMember('char-a', 'Alice', 0.2, 'world-a'));
      runtime.addMember('group-3', makeMember('char-b', 'Bob', 0.9, 'world-b'));
      runtime.reorderMembers('group-3', ['char-b', 'char-a']);
      const binding = runtime.bindPersona('group-3', 'persona-1');
      const members: Array<GroupMemberRecord> = runtime.listMembers('group-3');

      expect(members[0].characterId).assertEqual('char-b');
      expect(members[1].order).assertEqual(1);
      expect(binding.personaId).assertEqual('persona-1');
      expect(runtime.getGroup('group-3').personaId).assertEqual('persona-1');
      expect(added.length).assertEqual(2);
      expect(added[0]).assertEqual('group-3:char-a');
    });

    it('rejects creating a group over an existing id', 0, () => {
      // 运行时实例。
      const runtime = new GroupRuntime(new EventBus());
      runtime.createGroup(makeGroup('group-create-existing', 'Original Crew'));
      let thrown = false;

      try {
        runtime.createGroup(makeGroup('group-create-existing', 'Replacement Crew'));
      } catch (error) {
        thrown = true;
      }

      expect(thrown).assertTrue();
      expect(runtime.getGroup('group-create-existing').name).assertEqual('Original Crew');
    });

    it('selects speakers and builds merged group prompt data', 0, () => {
      // 运行时实例。
      const runtime = new GroupRuntime(new EventBus());
      runtime.createGroup(makeGroup('group-4', 'Prompt Crew'));
      runtime.addMember('group-4', makeMember('char-a', 'Alice', 0.2, 'world-a'));
      runtime.addMember('group-4', makeMember('char-b', 'Bob', 0.9, 'world-b'));
      runtime.bindPersona('group-4', 'persona-2');
      const manual = runtime.selectSpeaker('group-4', 'char-a');
      const automatic = runtime.selectSpeaker('group-4', '');
      const prompt: GroupPromptData = runtime.buildPromptData('group-4', 'shared world');

      expect(manual.characterId).assertEqual('char-a');
      expect(automatic.characterId).assertEqual('char-b');
      expect(prompt.groupId).assertEqual('group-4');
      expect(prompt.personaId).assertEqual('persona-2');
      expect(prompt.memberNames).assertEqual('Alice, Bob');
      expect(prompt.worldInfoText).assertEqual('shared world\nworld-a\nworld-b');
      expect(prompt.promptText).assertContain('Prompt Crew');
      expect(prompt.promptText).assertContain('Alice, Bob');
    });

    it('skips disabled members when auto-selecting a group speaker', 0, () => {
      // 运行时实例。
      const runtime = new GroupRuntime(new EventBus());
      runtime.createGroup(makeGroup('group-disabled', 'Disabled Crew'));
      const disabled = makeMember('char-disabled', 'Disabled', 1.0, '');
      disabled.enabled = false;
      runtime.addMember('group-disabled', disabled);
      runtime.addMember('group-disabled', makeMember('char-enabled', 'Enabled', 0.1, ''));
      const selected = runtime.selectSpeaker('group-disabled', '');

      expect(selected.characterId).assertEqual('char-enabled');
    });

    it('rejects incomplete or duplicate group member reorder lists', 0, () => {
      // 运行时实例。
      const runtime = new GroupRuntime(new EventBus());
      runtime.createGroup(makeGroup('group-reorder', 'Reorder Crew'));
      runtime.addMember('group-reorder', makeMember('char-a', 'Alice', 0.2, 'world-a'));
      runtime.addMember('group-reorder', makeMember('char-b', 'Bob', 0.9, 'world-b'));
      let missingThrown = false;
      try {
        runtime.reorderMembers('group-reorder', ['char-b']);
      } catch (error) {
        missingThrown = true;
      }
      let duplicateThrown = false;
      try {
        runtime.reorderMembers('group-reorder', ['char-b', 'char-b']);
      } catch (error) {
        duplicateThrown = true;
      }

      expect(missingThrown).assertTrue();
      expect(duplicateThrown).assertTrue();
      expect(runtime.listMembers('group-reorder').length).assertEqual(2);
      expect(runtime.listMembers('group-reorder')[0].characterId).assertEqual('char-a');
    });

    it('tracks generation requests and imports exported groups', 0, () => {
      // 运行时实例。
      const runtime = new GroupRuntime(new EventBus());
      runtime.createGroup(makeGroup('group-5', 'Generation Crew'));
      runtime.addMember('group-5', makeMember('char-a', 'Alice', 0.2, 'world-a'));
      const regenerate: GroupGenerationRequest = runtime.queueRegenerate('group-5', 'chat-1', 'msg-1');
      const continued: GroupGenerationRequest = runtime.queueContinue('group-5', 'chat-1');
      const toolCall: GroupGenerationRequest = runtime.queueToolCall('group-5', 'chat-1', 'lookup');
      const exported: GroupExportData = runtime.exportGroup('group-5');
      const imported = new GroupRuntime(new EventBus());
      imported.importGroup(exported, 'group-6');
      const importedContinue = imported.queueContinue('group-6', 'chat-2');

      expect(regenerate.requestType).assertEqual('regenerate');
      expect(continued.requestType).assertEqual('continue');
      expect(toolCall.toolName).assertEqual('lookup');
      expect(runtime.listGenerationRequests('group-5').length).assertEqual(3);
      expect(imported.getGroup('group-6').name).assertEqual('Generation Crew');
      expect(imported.listMembers('group-6').length).assertEqual(1);
      expect(importedContinue.id).assertEqual('group-request-4');
    });

    it('rejects importing a group over an existing id', 0, () => {
      // 运行时实例。
      const runtime = new GroupRuntime(new EventBus());
      runtime.createGroup(makeGroup('group-existing', 'Existing Crew'));
      const exported: GroupExportData = runtime.exportGroup('group-existing');
      let thrown = false;
      try {
        runtime.importGroup(exported, 'group-existing');
      } catch (error) {
        thrown = true;
      }

      expect(thrown).assertTrue();
      expect(runtime.getGroup('group-existing').name).assertEqual('Existing Crew');
    });

    it('does not expose internal group, member, or request records', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new GroupRuntime(bus);
      bus.subscribe<GroupEventPayload>('group.created', (event: RuntimeEvent<GroupEventPayload>) => {
        event.payload.group.name = 'event-mutated';
      });
      bus.subscribe<GroupSpeakerSelectedPayload>('group.speaker.selected', (event: RuntimeEvent<GroupSpeakerSelectedPayload>) => {
        event.payload.member.characterName = 'event-speaker';
      });
      const group = runtime.createGroup(makeGroup('group-copy', 'Copy Crew'));
      group.name = 'external-group';
      expect(runtime.getGroup('group-copy').name).assertEqual('Copy Crew');
      const member = runtime.addMember('group-copy', makeMember('char-copy', 'Copy', 0.7, 'world-copy'));
      member.characterName = 'external-member';
      expect(runtime.listMembers('group-copy')[0].characterName).assertEqual('Copy');
      const listedGroups = runtime.listGroups();
      listedGroups[0].name = 'listed-group';
      const listedMembers = runtime.listMembers('group-copy');
      listedMembers[0].characterName = 'listed-member';
      expect(runtime.getGroup('group-copy').name).assertEqual('Copy Crew');
      expect(runtime.listMembers('group-copy')[0].characterName).assertEqual('Copy');
      const selected = runtime.selectSpeaker('group-copy', 'char-copy');
      selected.characterName = 'selected-member';
      expect(runtime.listMembers('group-copy')[0].characterName).assertEqual('Copy');
      const request = runtime.queueContinue('group-copy', 'chat-copy');
      request.chatId = 'external-chat';
      const requests = runtime.listGenerationRequests('group-copy');
      requests[0].chatId = 'listed-chat';
      expect(runtime.listGenerationRequests('group-copy')[0].chatId).assertEqual('chat-copy');

      { let thrown=false; try { runtime.removeMember('group-copy', 'missing-member'); } catch(e) { thrown=true; } expect(thrown).assertTrue(); };
    });
  });
}

/**
 * 封装单元测试中的 makeGroup 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param name 显示名称或注册名称。
 */
function makeGroup(id: string, name: string): GroupCreateParams {
  return {
    id: id,
    name: name,
    description: `Group ${id}`,
    chatId: `chat-${id}`,
    enabled: true,
    activationStrategy: 'auto',
  };
}

/**
 * 封装单元测试中的 makeMember 步骤，供公开方法复用。
 * @param characterId 目标角色标识。
 * @param name 显示名称或注册名称。
 */
function makeMember(characterId: string, name: string, talkativeness: number, worldInfoText: string): GroupMemberCreateParams {
  return {
    characterId: characterId,
    characterName: name,
    role: 'speaker',
    talkativeness: talkativeness,
    enabled: true,
    worldInfoText: worldInfoText,
  };
}
