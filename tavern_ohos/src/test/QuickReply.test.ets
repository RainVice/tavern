import { describe, it, expect } from '@ohos/hypium';
import {
  CommandRuntime,
  EventBus,
  QuickReplyRuntime,
  type CommandAction,
  type CommandExecuteOptions,
  type CommandExecutionResult,
  type CommandInvocation,
  type CommandRegistrationParams,
  type QuickReplyButtonData,
  type QuickReplyExecutedPayload,
  type QuickReplyExportData,
  type QuickReplyItemCreateParams,
  type QuickReplySetCreateParams,
  type QuickReplySetUpdatedPayload,
  type RuntimeEvent,
} from '../../Index';

export default function quickReplyUnitTest() {
  describe('quick reply runtime', () => {
    it('creates scoped quick reply sets, exposes button data, and executes commands', 0, async () => {
      const bus = new EventBus();
      const commands = new CommandRuntime(bus);
      commands.registerCommand(makeEchoCommand());
      const quickReplies = new QuickReplyRuntime(bus, commands);
      const executed = new Array<string>();
      bus.subscribe<QuickReplyExecutedPayload>('quickReply.executed', (event: RuntimeEvent<QuickReplyExecutedPayload>) => {
        executed.push(event.payload.item.id);
      });
      const set = quickReplies.createSet(makeSet('set-1', 'Main', 'global', ''));
      const item = quickReplies.addItem(set.id, makeItem('qr-1', 'Say', '/echo hello', false, ''));

      const buttons: Array<QuickReplyButtonData> = quickReplies.listButtons('global', '');
      const result = await quickReplies.executeItem(set.id, item.id, makeOptions());

      expect(buttons.length).assertEqual(1);
      expect(buttons[0].label).assertEqual('Say');
      expect(result.commandResult.output).assertEqual('hello');
      expect(result.executed).assertTrue();
      expect(executed.length).assertEqual(1);
      expect(executed[0]).assertEqual('qr-1');
    });

    it('executes matching auto triggers and skips hidden or scoped-out replies', 0, async () => {
      const bus = new EventBus();
      const commands = new CommandRuntime(bus);
      commands.registerCommand(makeEchoCommand());
      const quickReplies = new QuickReplyRuntime(bus, commands);
      const globalSet = quickReplies.createSet(makeSet('set-2', 'Global', 'global', ''));
      const chatSet = quickReplies.createSet(makeSet('set-3', 'Chat', 'chat', 'chat-1'));
      quickReplies.addItem(globalSet.id, makeItem('qr-2', 'Startup', '/echo start', true, 'startup'));
      quickReplies.addItem(globalSet.id, makeItem('qr-3', 'Hidden', '/echo hidden', false, ''));
      quickReplies.setItemVisible(globalSet.id, 'qr-3', false);
      quickReplies.addItem(chatSet.id, makeItem('qr-4', 'ChatOnly', '/echo chat', true, 'user'));

      const startup = await quickReplies.executeAutoTrigger('startup', 'global', '', makeOptions());
      const chatUser = await quickReplies.executeAutoTrigger('user', 'chat', 'chat-1', makeOptions());
      const wrongChat = await quickReplies.executeAutoTrigger('user', 'chat', 'chat-2', makeOptions());

      expect(startup.length).assertEqual(1);
      expect(startup[0].commandResult.output).assertEqual('start');
      expect(chatUser.length).assertEqual(1);
      expect(chatUser[0].commandResult.output).assertEqual('chat');
      expect(wrongChat.length).assertEqual(0);
    });

    it('exports and imports quick reply sets', 0, () => {
      const bus = new EventBus();
      const commands = new CommandRuntime(bus);
      const quickReplies = new QuickReplyRuntime(bus, commands);
      const set = quickReplies.createSet(makeSet('set-4', 'Exported', 'character', 'char-1'));
      quickReplies.addItem(set.id, makeItem('qr-5', 'Export item', '/echo exported', false, ''));

      const exported: QuickReplyExportData = quickReplies.exportSet(set.id);
      const imported = quickReplies.importSet(exported, 'set-5');

      expect(imported.id).assertEqual('set-5');
      expect(quickReplies.getSet('set-5').items.length).assertEqual(1);
      expect(quickReplies.getSet('set-5').items[0].label).assertEqual('Export item');
    });

    it('rejects creating a quick reply set over an existing id', 0, () => {
      const bus = new EventBus();
      const commands = new CommandRuntime(bus);
      const quickReplies = new QuickReplyRuntime(bus, commands);
      quickReplies.createSet(makeSet('set-create-existing', 'Original', 'global', ''));
      let thrown = false;

      try {
        quickReplies.createSet(makeSet('set-create-existing', 'Replacement', 'global', ''));
      } catch (error) {
        thrown = true;
      }

      expect(thrown).assertTrue();
      expect(quickReplies.getSet('set-create-existing').name).assertEqual('Original');
    });

    it('rejects importing a quick reply set over an existing id', 0, () => {
      const bus = new EventBus();
      const commands = new CommandRuntime(bus);
      const quickReplies = new QuickReplyRuntime(bus, commands);
      const set = quickReplies.createSet(makeSet('set-existing', 'Existing', 'global', ''));
      const exported: QuickReplyExportData = quickReplies.exportSet(set.id);

      let thrown = false;
      try {
        quickReplies.importSet(exported, 'set-existing');
      } catch (error) {
        thrown = true;
      }

      expect(thrown).assertTrue();
      expect(quickReplies.getSet('set-existing').name).assertEqual('Existing');
    });

    it('does not expose internal quick reply sets, items, or execution payloads', 0, async () => {
      const bus = new EventBus();
      const commands = new CommandRuntime(bus);
      commands.registerCommand(makeEchoCommand());
      const quickReplies = new QuickReplyRuntime(bus, commands);
      bus.subscribe<QuickReplySetUpdatedPayload>('quickReply.setUpdated', (event: RuntimeEvent<QuickReplySetUpdatedPayload>) => {
        event.payload.set.name = 'event-mutated';
      });
      bus.subscribe<QuickReplyExecutedPayload>('quickReply.executed', (event: RuntimeEvent<QuickReplyExecutedPayload>) => {
        event.payload.item.label = 'event-item';
        event.payload.commandResult.output = 'event-output';
      });

      const set = quickReplies.createSet(makeSet('set-copy', 'Copy', 'global', ''));
      set.name = 'external-set';
      expect(quickReplies.getSet('set-copy').name).assertEqual('Copy');

      const item = quickReplies.addItem('set-copy', makeItem('qr-copy', 'Copy item', '/echo copied', false, ''));
      item.label = 'external-item';
      expect(quickReplies.getSet('set-copy').items[0].label).assertEqual('Copy item');

      const listed = quickReplies.listSets();
      listed[0].items[0].label = 'listed-item';
      expect(quickReplies.getSet('set-copy').items[0].label).assertEqual('Copy item');

      const result = await quickReplies.executeItem('set-copy', 'qr-copy', makeOptions());
      result.item.label = 'result-item';
      result.commandResult.output = 'result-output';
      const saved = quickReplies.getSet('set-copy');
      expect(saved.items[0].label).assertEqual('Copy item');

      { let thrown=false; try { quickReplies.deleteSet('missing-set'); } catch(e) { thrown=true; } expect(thrown).assertTrue(); };
      { let thrown=false; try { quickReplies.removeItem('set-copy', 'missing-item'); } catch(e) { thrown=true; } expect(thrown).assertTrue(); };
    });
  });
}

class EchoAction implements CommandAction {
  execute(invocation: CommandInvocation): Promise<CommandExecutionResult> {
    const result: CommandExecutionResult = {
      ok: true,
      commandName: invocation.commandName,
      output: invocation.unnamedArgument,
      error: '',
      cancelled: false,
    };
    return Promise.resolve(result);
  }
}

function makeEchoCommand(): CommandRegistrationParams {
  return {
    name: 'echo',
    aliases: new Array<string>(),
    helpText: 'Echoes text.',
    permission: 'public',
    returns: 'string',
    enabled: true,
    action: new EchoAction(),
  };
}

function makeSet(id: string, name: string, scope: string, scopeId: string): QuickReplySetCreateParams {
  return {
    id: id,
    name: name,
    scope: scope,
    scopeId: scopeId,
    enabled: true,
  };
}

function makeItem(id: string, label: string, command: string, auto: boolean, trigger: string): QuickReplyItemCreateParams {
  return {
    id: id,
    label: label,
    title: label,
    command: command,
    enabled: true,
    visible: true,
    autoExecute: auto,
    trigger: trigger,
    pluginId: '',
  };
}

function makeOptions(): CommandExecuteOptions {
  return {
    allowedPermissions: ['public'],
    cancelled: false,
  };
}
